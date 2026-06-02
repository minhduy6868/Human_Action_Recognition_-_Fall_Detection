import json
import re
from datetime import datetime
from typing import Any

import httpx

from app.models.schemas import ActivityInsightResponse, ChatQueryResponse
from app.services.stream_service import state
from app.core.config import get_settings


settings = get_settings()


DEFAULT_WINDOW_MS = 60 * 60 * 1000
DAY_WINDOW_MS = 24 * 60 * 60 * 1000


class ChatService:
    def answer(self, question: str, window_ms: int | None = None) -> ChatQueryResponse:
        normalized = question.strip().lower()
        now_ms = int(datetime.now().timestamp() * 1000)
        resolved_window_ms = self._resolve_window_ms(normalized, window_ms)
        insight = ActivityInsightResponse(
            **state.activity_insight(window_ms=resolved_window_ms, now_ms=now_ms)
        )
        intent = self._detect_intent(normalized)
        answer = self._answer_with_openrouter(question, intent, insight, now_ms)
        return ChatQueryResponse(answer=answer, intent=intent, insight=insight)

    def answer_from_insight(
        self,
        question: str,
        insight: ActivityInsightResponse,
    ) -> tuple[str, str]:
        normalized = question.strip().lower()
        intent = self._detect_intent(normalized)
        now_ms = int(datetime.now().timestamp() * 1000)
        answer = self._answer_with_openrouter(question, intent, insight, now_ms)
        return answer, intent

    def _answer_with_openrouter(
        self,
        question: str,
        intent: str,
        insight: ActivityInsightResponse,
        now_ms: int,
    ) -> str:
        lang = ChatService._detect_language(question)
        fallback = ChatService._build_answer(intent, insight, now_ms, lang)
        api_key = settings.openrouter_api_key.strip()
        if not api_key:
            return fallback

        prompt = self._build_prompt(question, intent, insight, fallback, now_ms)
        try:
            return self._call_openrouter(prompt, fallback)
        except Exception:
            return fallback

    @staticmethod
    def _has_clear_activity(insight: ActivityInsightResponse) -> bool:
        if insight.total_samples <= 0:
            return False
        if insight.fall_detected:
            return True
        if insight.dominant_action not in {"unknown", "idle", "none", ""} and insight.dominant_action_ratio >= 0.35:
            return True
        return bool(insight.max_people_count or insight.max_objects_count or insight.top_object_labels)

    @staticmethod
    def _build_scene_context(insight: ActivityInsightResponse, lang: str) -> str:
        if insight.max_people_count <= 0 and insight.max_objects_count <= 0 and not insight.top_object_labels:
            return "không thấy người hay vật thể nổi bật" if lang == "vi" else "no obvious people or objects were detected"

        parts_vi: list[str] = []
        parts_en: list[str] = []

        if insight.max_people_count > 0:
            parts_vi.append(f"tối đa {insight.max_people_count} người")
            parts_en.append(f"up to {insight.max_people_count} people")
        if insight.max_objects_count > 0:
            parts_vi.append(f"tối đa {insight.max_objects_count} vật thể")
            parts_en.append(f"up to {insight.max_objects_count} objects")
        if insight.top_object_labels:
            labels = ", ".join(
                f"{label} ({count})" for label, count in list(insight.top_object_labels.items())[:5]
            )
            parts_vi.append(f"vật thể nổi bật: {labels}")
            parts_en.append(f"top objects: {labels}")

        return "; ".join(parts_vi if lang == "vi" else parts_en)
    @staticmethod
    def _detect_language(question: str) -> str:
        q = question.lower()
        # If question contains Vietnamese-specific characters, prefer Vietnamese
        if re.search(r"[ảáàạãâấầẩẫậăắằẵặđếềềêốồộơờớỡựứựưỳỷỹụụảộ]", q):
            return "vi"

        eng_tokens = [
            "what",
            "how",
            "people",
            "objects",
            "fall",
            "when",
            "who",
            "summarize",
            "summary",
            "activity",
            "count",
            "detect",
            "is there",
        ]
        for t in eng_tokens:
            if t in q:
                return "en"

        # default to Vietnamese
        return "vi"

    @staticmethod
    def _format_ms(ts_ms: int) -> str:
        try:
            dt = datetime.fromtimestamp(ts_ms / 1000.0)
            return dt.strftime("%Y-%m-%d %H:%M:%S")
        except Exception:
            return str(ts_ms)

    @staticmethod
    def _build_prompt(
        question: str,
        intent: str,
        insight: ActivityInsightResponse,
        fallback: str,
        now_ms: int,
    ) -> str:
        lang = ChatService._detect_language(question)

        payload: dict[str, Any] = {
            "question": question,
            "intent": intent,
            "window_ms": insight.window_ms,
            "total_samples": insight.total_samples,
            "dominant_action": insight.dominant_action,
            "dominant_action_ratio": insight.dominant_action_ratio,
            "action_durations_ms": insight.action_durations_ms,
            "segments": [segment.model_dump() for segment in insight.segments[-12:]],
            "fall_detected": insight.fall_detected,
            "fall_events": [event.model_dump() for event in insight.fall_events[-8:]],
            "max_people_count": insight.max_people_count,
            "avg_people_count": insight.avg_people_count,
            "max_objects_count": insight.max_objects_count,
            "avg_objects_count": insight.avg_objects_count,
            "multi_person_frames": insight.multi_person_frames,
            "top_object_labels": insight.top_object_labels,
        }

        if lang == "vi":
            system = (
                "Bạn là trợ lý phân tích video realtime. Hãy viết như 1 con người: thân thiện, tự nhiên, có dấu tiếng Việt, không cứng nhắc. "
                "Hãy coi BACKEND_ANALYSIS là nguồn sự thật chính, rồi diễn đạt lại thật mượt. Nếu không chắc chắn, nêu rõ mức độ tin cậy."
            )
            instructions = (
                "Viết 2–4 câu tự nhiên, có thể dùng 1 đoạn văn ngắn. Không cần TL;DR trừ khi người dùng yêu cầu. "
                "Nêu ý chính trước, sau đó thêm timeline ngắn, ngữ cảnh cảnh vật/người/vật thể và sự kiện té ngã nếu có. "
                "Dùng ngôn ngữ đời thường, tránh văn phong máy móc."
            )
        else:
            system = (
                "You are a realtime video analysis assistant. Write like a human: natural, conversational English, not robotic. "
                "Treat BACKEND_ANALYSIS as the source of truth, then rewrite it fluently. State confidence when uncertain."
            )
            instructions = (
                "Write 2–4 natural sentences or one short paragraph. No TL;DR header unless requested. "
                "Lead with the main point, then add a short timeline, scene context, and fall events if any. Avoid sounding like a template."
            )

        if lang == "vi":
            backend_summary = ChatService._build_answer(intent, insight, now_ms, lang)
        else:
            backend_summary = ChatService._build_answer(intent, insight, now_ms, lang)

        prompt = (
            f"SYSTEM: {system}\n\n"
            f"INSTRUCTIONS: {instructions}\n\n"
            f"BACKEND_ANALYSIS: {backend_summary}\n\n"
            f"DATA (JSON): {json.dumps(payload, ensure_ascii=False)}\n\n"
            f"NOW_MS: {now_ms}\n\n"
            f"USER QUESTION: {question}\n\n"
            f"FALLBACK_ANSWER: {fallback}"
        )

        return prompt

    def _call_openrouter(self, prompt: str, fallback: str) -> str:
        headers = {
            "Authorization": f"Bearer {settings.openrouter_api_key.strip()}",
            "Content-Type": "application/json",
        }
        if settings.openrouter_site_url.strip():
            headers["HTTP-Referer"] = settings.openrouter_site_url.strip()
        if settings.openrouter_app_name.strip():
            headers["X-Title"] = settings.openrouter_app_name.strip()

        payload = {
            "model": settings.openrouter_model.strip(),
            "messages": [
                {"role": "system", "content": "Trợ lý phân tích video realtime"},
                {"role": "user", "content": prompt},
            ],
            "temperature": 0.2,
        }
        with httpx.Client(timeout=settings.openrouter_timeout_seconds) as client:
            response = client.post(
                "https://openrouter.ai/api/v1/chat/completions",
                headers=headers,
                json=payload,
            )
            response.raise_for_status()
            data = response.json()

        choices = data.get("choices") or []
        if not choices:
            return fallback
        message = choices[0].get("message") or {}
        content = (message.get("content") or "").strip()
        return content or fallback

    def _resolve_window_ms(self, question: str, window_ms: int | None) -> int:
        if window_ms is not None and window_ms > 0:
            return window_ms

        if any(
            token in question
            for token in ["1 ngày", "mot ngay", "hôm nay", "hom nay", "today"]
        ):
            return DAY_WINDOW_MS

        hour_match = re.search(r"(\d+)\s*(gio|hour|hours|h)", question)
        if hour_match:
            return max(int(hour_match.group(1)), 1) * 60 * 60 * 1000

        minute_match = re.search(r"(\d+)\s*(phut|minute|minutes|min|m)", question)
        if minute_match:
            return max(int(minute_match.group(1)), 1) * 60 * 1000

        return DEFAULT_WINDOW_MS

    @staticmethod
    def _detect_intent(question: str) -> str:
        if any(token in question for token in ["té ngã", "te nga", "fall"]):
            return "fall_check"
        if any(token in question for token in ["nhiều nhất", "nhieu nhat", "most", "dominant"]):
            return "most_active"
        if any(
            token in question
            for token in [
                "hành động",
                "hanh dong",
                "activity",
                "hoạt động",
                "hoat dong",
            ]
        ):
            return "activity_summary"
        return "general_summary"

    @staticmethod
    def _build_answer(intent: str, insight: ActivityInsightResponse, now_ms: int, lang: str = "vi") -> str:
        if insight.total_samples == 0:
            return (
                "Chưa phát hiện gì trong khoảng thời gian bạn hỏi."
                if lang == "vi"
                else "No activity was detected in the requested time range."
            )
        # Scene summary (language-aware)
        scene_parts_vi: list[str] = []
        scene_parts_en: list[str] = []

        if insight.max_people_count > 1:
            scene_parts_vi.append(f"tối đa {insight.max_people_count} người cùng lúc")
            scene_parts_en.append(f"max {insight.max_people_count} people at once")
        elif insight.max_people_count == 1:
            scene_parts_vi.append("1 người")
            scene_parts_en.append("1 person")

        if insight.max_objects_count > 0:
            scene_parts_vi.append(f"tối đa {insight.max_objects_count} vật thể")
            scene_parts_en.append(f"max {insight.max_objects_count} objects")

        if insight.top_object_labels:
            top_labels = ", ".join(
                f"{label} ({count})" for label, count in list(insight.top_object_labels.items())[:5]
            )
            scene_parts_vi.append(f"vật thể nổi bật: {top_labels}")
            scene_parts_en.append(f"top objects: {top_labels}")

        # Handle intents specifically (bilingual)
        if intent == "fall_check":
            if insight.fall_detected and insight.fall_events:
                events = insight.fall_events
                if lang == "vi":
                    lines = [f"Phát hiện {len(events)} lần té ngã:"]
                    for i, ev in enumerate(events[-5:], start=1):
                        t = ChatService._format_ms(getattr(ev, "timestamp_ms", 0))
                        conf = getattr(ev, "confidence", None)
                        conf_text = f" (độ tin cậy {conf:.2f})" if conf is not None else ""
                        lines.append(f"- Lần {i}: {t}{conf_text}")
                    return "\n".join(lines)
                else:
                    lines = [f"Detected {len(events)} fall events:"]
                    for i, ev in enumerate(events[-5:], start=1):
                        t = ChatService._format_ms(getattr(ev, "timestamp_ms", 0))
                        conf = getattr(ev, "confidence", None)
                        conf_text = f" (confidence {conf:.2f})" if conf is not None else ""
                        lines.append(f"- Event {i}: {t}{conf_text}")
                    return "\n".join(lines)
            return "Không phát hiện té ngã trong khoảng thời gian đã chọn." if lang == "vi" else "No falls detected in the requested time range."

        if intent == "most_active":
            if lang == "vi":
                return f"Hoạt động chủ đạo: {insight.dominant_action} — {insight.dominant_action_ratio * 100:.1f}% thời gian."
            return f"Dominant activity: {insight.dominant_action} — {insight.dominant_action_ratio * 100:.1f}% of the time."

        # General summary with timeline (last few segments)
        segs = list(insight.segments)[-6:]
        timeline_lines = []
        window_start_ms = now_ms - insight.window_ms
        for seg in segs:
            try:
                start_ts = ChatService._format_ms(window_start_ms + seg.start_ms)
                end_ts = ChatService._format_ms(window_start_ms + seg.end_ms)
                dur_s = max(0, (seg.end_ms - seg.start_ms) // 1000)
                if lang == "vi":
                    timeline_lines.append(f"- {seg.action}: {dur_s}s ({start_ts} → {end_ts})")
                else:
                    timeline_lines.append(f"- {seg.action}: {dur_s}s ({start_ts} -> {end_ts})")
            except Exception:
                timeline_lines.append(f"- {seg.action}: {seg.start_ms}→{seg.end_ms}")

        if not timeline_lines:
            timeline_lines = ["Không có phân đoạn rõ ràng" if lang == "vi" else "No clear segments"]

        scene_text = ChatService._build_scene_context(insight, lang)

        if not ChatService._has_clear_activity(insight):
            if lang == "vi":
                return (
                    f"Không phát hiện hành động rõ ràng trong khoảng thời gian này. Ngữ cảnh: {scene_text}."
                )
            return f"No clear activity was detected in this period. Context: {scene_text}."

        # Fall summary
        fall_lines = []
        if insight.fall_detected and insight.fall_events:
            for ev in insight.fall_events[-5:]:
                t = ChatService._format_ms(getattr(ev, "timestamp_ms", 0))
                if lang == "vi":
                    fall_lines.append(f"- Té ngã: {t}")
                else:
                    fall_lines.append(f"- Fall: {t}")

        # Build final human-friendly text
        parts = []

        # Assemble natural-language paragraph (Vietnamese)
        if lang == "vi":
            # First sentence: main activity
            first = f"Trong khoảng thời gian này chủ yếu là {insight.dominant_action} ({insight.dominant_action_ratio * 100:.1f}%)."

            # Timeline sentence: join short timeline bits into one sentence
            tl_items = [l.lstrip("- ") for l in timeline_lines]
            timeline_sentence = "".join(tl_items)
            if timeline_sentence:
                timeline_text = "Ví dụ: " + "; ".join(tl_items) + "."
            else:
                timeline_text = "Không có phân đoạn thời gian rõ ràng."

            # Scene/context
            context_text = f"Ngữ cảnh: {scene_text}." if scene_text else ""

            # Falls
            if fall_lines:
                # try to include count and last time/confidence
                try:
                    last_ev = insight.fall_events[-1]
                    last_t = ChatService._format_ms(getattr(last_ev, "timestamp_ms", 0))
                    last_conf = getattr(last_ev, "confidence", None)
                    conf_text = f" (độ tin cậy {last_conf:.2f})" if last_conf is not None else ""
                    fall_text = f"Phát hiện {len(insight.fall_events)} lần nghi ngờ té ngã; lần gần nhất: {last_t}{conf_text}."
                except Exception:
                    fall_text = "Phát hiện sự kiện té ngã." if lang == "vi" else "Detected fall events."
            else:
                fall_text = "Không phát hiện té ngã."

            suggestion = "Gợi ý: xem lại các đoạn thời gian đáng ngờ, kiểm tra góc máy hoặc bật cảnh báo nếu cần."

            parts = [first, timeline_text]
            if context_text:
                parts.append(context_text)
            parts.append(fall_text)
            parts.append(suggestion)
            return "\n\n".join([p for p in parts if p])

        # Assemble natural-language paragraph (English)
        first_en = f"In this period most activity was {insight.dominant_action} ({insight.dominant_action_ratio * 100:.1f}%)."
        tl_items_en = [l.lstrip("- ") for l in timeline_lines]
        timeline_text_en = ("For example: " + "; ".join(tl_items_en) + ".") if tl_items_en else "No clear time segments."
        context_text_en = f"Context: {scene_text}." if scene_text else ""
        if fall_lines:
            try:
                last_ev = insight.fall_events[-1]
                last_t = ChatService._format_ms(getattr(last_ev, "timestamp_ms", 0))
                last_conf = getattr(last_ev, "confidence", None)
                conf_text = f" (confidence {last_conf:.2f})" if last_conf is not None else ""
                fall_text_en = f"Detected {len(insight.fall_events)} suspected falls; latest: {last_t}{conf_text}."
            except Exception:
                fall_text_en = "Detected fall events."
        else:
            fall_text_en = "No falls detected."
        suggestion_en = "Suggestion: review suspicious segments, check camera angle, or enable alerts if needed."

        parts_en = [first_en, timeline_text_en]
        if context_text_en:
            parts_en.append(context_text_en)
        parts_en.append(fall_text_en)
        parts_en.append(suggestion_en)
        return "\n\n".join([p for p in parts_en if p])
