import json
import re
from datetime import datetime
from typing import Any

import httpx

from app.models.schemas import ActivityInsightResponse, ChatQueryResponse
from app.core.user_scope import isolated_realtime_state
from app.core.config import get_settings
from app.utils.detection_insight import format_time_vi


settings = get_settings()


DEFAULT_WINDOW_MS = 60 * 60 * 1000
DAY_WINDOW_MS = 24 * 60 * 60 * 1000


class ChatService:
    def answer(
        self,
        question: str,
        window_ms: int | None = None,
        insight_state=None,
    ) -> ChatQueryResponse:
        normalized = question.strip().lower()
        now_ms = int(datetime.now().timestamp() * 1000)
        resolved_window_ms = self._resolve_window_ms(normalized, window_ms)
        src = insight_state or isolated_realtime_state()
        insight = ActivityInsightResponse(
            **src.activity_insight(window_ms=resolved_window_ms, now_ms=now_ms)
        )
        intent = self._detect_intent(normalized)
        answer = self._answer_with_openrouter(question, intent, insight, now_ms)
        return ChatQueryResponse(answer=answer, intent=intent, insight=insight)

    def resolve_window_ms(self, question: str, window_ms: int | None = None) -> int:
        return self._resolve_window_ms(question.strip().lower(), window_ms)

    def answer_from_insight(
        self,
        question: str,
        insight: ActivityInsightResponse,
    ) -> tuple[str, str]:
        normalized = question.strip().lower()
        intent = self._detect_intent(normalized)
        now_ms = int(datetime.now().timestamp() * 1000)
        lang = ChatService._detect_language(question)
        window_label = (
            ChatService._window_phrase_vi(insight.window_ms)
            if lang == "vi"
            else f"the last {insight.window_ms // 3600000} hours"
        )
        color_filter = ChatService._extract_color_filter(normalized)
        log_answer = ChatService._build_answer_from_log_narrative(
            insight,
            lang,
            window_label,
            color_filter=color_filter,
        )
        if log_answer and intent not in {"greeting", "fall_check"}:
            return log_answer, intent

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
        fallback = ChatService._build_answer(intent, insight, now_ms, lang, question)
        api_key = settings.openrouter_api_key.strip()
        if not api_key:
            return fallback

        try:
            return self._call_openrouter(
                question, intent, insight, fallback, now_ms, fallback
            )
        except Exception:
            return fallback

    @staticmethod
    def _has_clear_activity(insight: ActivityInsightResponse) -> bool:
        if insight.log_narrative_lines:
            return True
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
    def _format_hm(ts_ms: int) -> str:
        try:
            return datetime.fromtimestamp(ts_ms / 1000.0).strftime("%H:%M")
        except Exception:
            return "??:??"

    @staticmethod
    def _color_vi(color: str) -> str:
        mapping = {
            "white": "trắng",
            "black": "đen",
            "red": "đỏ",
            "blue": "xanh",
            "green": "xanh lá",
            "yellow": "vàng",
            "orange": "cam",
            "gray": "xám",
            "grey": "xám",
            "brown": "nâu",
            "purple": "tím",
            "pink": "hồng",
            "green": "xanh lá",
        }
        key = (color or "unknown").strip().lower()
        if key == "blue":
            return "xanh"
        return mapping.get(key, key if key != "unknown" else "")

    @staticmethod
    def _action_phrase_vi(action: str) -> str:
        mapping = {
            "walking": "đi ngang qua",
            "standing": "đứng yên",
            "sitting": "ngồi",
            "lying": "nằm",
            "running": "chạy",
            "crouching": "cúi",
            "fall": "té ngã",
        }
        return mapping.get((action or "").strip().lower(), f"thực hiện hành động {action}")

    @staticmethod
    def _moment_sentence_vi(moment, *, prefix: str = "") -> str:
        time_label = getattr(moment, "time_label", None) or ChatService._format_hm(
            getattr(moment, "timestamp_ms", 0)
        )
        action = getattr(moment, "action", "unknown")
        upper = getattr(moment, "upper_color", "unknown")
        color_vi = ChatService._color_vi(upper)
        action_phrase = ChatService._action_phrase_vi(action)

        if color_vi:
            subject = f"người mặc áo {color_vi}"
        else:
            subject = "có người"

        lead = f"{prefix}Vào {time_label}, {subject} {action_phrase}".strip()
        if not lead.endswith("."):
            lead += "."
        return lead[0].upper() + lead[1:] if lead else lead

    @staticmethod
    def _window_phrase_vi(window_ms: int) -> str:
        hours = window_ms / (60 * 60 * 1000)
        if hours >= 23:
            return "gần một ngày qua"
        if hours >= 5:
            return f"{int(round(hours))} giờ qua"
        if hours >= 1:
            return f"khoảng {int(round(hours))} giờ vừa rồi"
        minutes = max(1, int(window_ms / (60 * 1000)))
        return f"{minutes} phút vừa qua"

    @staticmethod
    def _join_moments_vi(sentences: list[str]) -> str:
        if not sentences:
            return ""
        if len(sentences) == 1:
            return sentences[0]
        connectors = ["Trước đó, ", "Tiếp theo, ", "Sau đó, ", "Rồi "]
        parts = [sentences[0]]
        for idx, sentence in enumerate(sentences[1:], start=0):
            prefix = connectors[idx % len(connectors)]
            lowered = sentence[0].lower() + sentence[1:] if sentence else sentence
            parts.append(f"{prefix}{lowered}")
        return " ".join(parts)

    @staticmethod
    def _filter_log_narrative_lines(
        lines: list[str],
        color_filter: str | None,
    ) -> list[str]:
        if not color_filter:
            return lines
        color_word = ChatService._color_vi(color_filter)
        filtered: list[str] = []
        for line in lines:
            lower = line.lower()
            if color_filter in lower or (color_word and color_word in lower):
                filtered.append(line)
        return filtered

    @staticmethod
    def _build_answer_from_log_narrative(
        insight: ActivityInsightResponse,
        lang: str,
        window_label: str,
        *,
        color_filter: str | None = None,
    ) -> str | None:
        lines = list(insight.log_narrative_lines or [])
        lines = ChatService._filter_log_narrative_lines(lines, color_filter)
        if not lines:
            return None
        body = " ".join(lines)
        if insight.fall_detected and "té" not in body.lower() and "ngã" not in body.lower():
            if lang == "vi":
                body += " Ngoài ra log có ghi nhận cảnh báo té ngã trong khung giờ này."
            else:
                body += " The logs also include a fall alert in this window."
        if lang == "vi":
            return f"Theo log camera ({window_label}): {body}"
        return f"From camera logs ({window_label}): {body}"

    @staticmethod
    def _build_narrative_from_moments(
        insight: ActivityInsightResponse,
        lang: str,
        *,
        color_filter: str | None = None,
    ) -> str | None:
        log_lines = ChatService._filter_log_narrative_lines(
            list(insight.log_narrative_lines or []),
            color_filter,
        )
        if log_lines:
            return " ".join(log_lines)

        moments = list(insight.notable_moments or [])
        if color_filter:
            key = color_filter.strip().lower()
            moments = [
                m
                for m in moments
                if key in (getattr(m, "upper_color", "") or "").lower()
                or key in ChatService._color_vi(getattr(m, "upper_color", "")).lower()
            ]
        if not moments:
            return None
        if lang == "vi":
            sentences = [
                ChatService._moment_sentence_vi(m, prefix="" if i == 0 else "")
                for i, m in enumerate(moments[-8:])
            ]
            text = ChatService._join_moments_vi(sentences)
            if insight.fall_detected:
                text += " Lưu ý là có lúc hệ thống báo té ngã, bạn nên xem lại clip cho chắc."
            return text.strip()
        lines = []
        for moment in moments[-8:]:
            t = getattr(moment, "time_label", "") or ChatService._format_hm(moment.timestamp_ms)
            lines.append(f"Around {t}, someone was {moment.action}.")
        return " ".join(lines)

    @staticmethod
    def _extract_color_filter(question: str) -> str | None:
        q = question.lower()
        pairs = [
            ("áo trắng", "white"),
            ("ao trang", "white"),
            ("mặc trắng", "white"),
            ("áo đen", "black"),
            ("áo đỏ", "red"),
            ("áo xanh", "blue"),
            ("ao xanh", "blue"),
            ("áo xanh lá", "green"),
            ("áo vàng", "yellow"),
            ("white shirt", "white"),
            ("black shirt", "black"),
            ("blue shirt", "blue"),
            ("red shirt", "red"),
        ]
        for phrase, color in pairs:
            if phrase in q:
                return color
        return None

    @staticmethod
    def _is_greeting(question: str) -> bool:
        q = question.strip().lower()
        return any(
            token in q
            for token in [
                "xin chào",
                "chào bạn",
                "chào ",
                "hello",
                "hi ",
                "hey",
                "bạn là ai",
                "ban la ai",
            ]
        ) and len(q.split()) <= 8

    @staticmethod
    def _greeting_answer(lang: str, insight: ActivityInsightResponse) -> str:
        if lang == "vi":
            if insight.total_samples <= 0 and not insight.fall_detected:
                return (
                    "Chào bạn! Mình là trợ lý camera — cứ hỏi tự nhiên như đang chat, "
                    "ví dụ «6 giờ qua có gì?» hoặc «có người áo trắng không?». "
                    "Hiện tại mình chưa thấy dữ liệu trong khung giờ bạn chọn; thử bật stream hoặc đổi camera nhé."
                )
            if insight.total_samples <= 0 and insight.fall_detected:
                return (
                    "Chào bạn! Mình là trợ lý camera. Trong khung giờ bạn chọn có báo té ngã — "
                    "hỏi «có ai té ngã không?» để mình nêu giờ cụ thể nhé."
                )
            return (
                "Chào bạn! Mình đang theo dõi camera giúp bạn — hỏi thoải mái, "
                "ví dụ «có ai té ngã không?» hay «lúc nào có người đi ngang?». "
                "Mình sẽ trả lời theo đúng những gì camera đã ghi nhận."
            )
        return (
            "Hi! I'm your camera assistant — ask naturally, like "
            "'anything unusual in the last 6 hours?' or 'was there a fall?'"
        )

    @staticmethod
    def _compact_camera_data(
        insight: ActivityInsightResponse,
        intent: str,
        now_ms: int,
        lang: str,
    ) -> dict[str, Any]:
        window_start = ChatService._format_hm(now_ms - insight.window_ms)
        window_end = ChatService._format_hm(now_ms)
        moments = []
        for moment in (insight.notable_moments or [])[-12:]:
            color = ChatService._color_vi(getattr(moment, "upper_color", ""))
            moments.append(
                {
                    "time": getattr(moment, "time_label", None)
                    or format_time_vi(getattr(moment, "timestamp_ms", 0)),
                    "action": getattr(moment, "action", ""),
                    "shirt_color": color or getattr(moment, "upper_color", ""),
                }
            )
        return {
            "intent": intent,
            "time_range": f"{window_start} → {window_end}",
            "log_timeline": list(insight.log_narrative_lines or [])[-16:],
            "samples": insight.total_samples,
            "main_activity": insight.dominant_action,
            "main_activity_share": round(insight.dominant_action_ratio * 100, 1),
            "people_peak": insight.max_people_count,
            "fall_detected": insight.fall_detected,
            "fall_times": [
                ChatService._format_hm(getattr(ev, "timestamp_ms", 0))
                for ev in (insight.fall_events or [])[-5:]
            ],
            "notable_events": moments,
            "scene": ChatService._build_scene_context(insight, lang),
        }

    @staticmethod
    def _system_message(lang: str) -> str:
        if lang == "vi":
            return (
                "Bạn là người bạn đang trò chuyện với chủ nhà qua app giám sát camera. "
                "Giọng điệu: thân thiện, gần gũi, tiếng Việt đời thường — như nhắn tin, không như báo cáo máy.\n\n"
                "Quy tắc bắt buộc:\n"
                "- Chỉ dựa vào CAMERA_DATA, ưu tiên trường log_timeline (đọc từ detection log).\n"
                "- Không bịa thêm người, giờ hay sự kiện; giữ đúng màu áo và chuỗi hành động trong log.\n"
                "- Trả lời 3–6 câu, tự nhiên; nêu giờ dạng 22h22, mô tả từng người (áo đen, xanh, đỏ…) và hành động (ngồi → nằm…).\n"
                "- Nếu log_timeline có «song song», phải nói nhiều người cùng lúc.\n"
                "- Không dùng gạch đầu dòng, số thứ tự, hay thuật ngữ kỹ thuật (dominant_action, samples…).\n"
                "- Không mở đầu bằng «Dựa trên dữ liệu» hay «Theo phân tích».\n"
                "- Có thể dùng «ừ», «à», «nhìn chung» nếu tự nhiên, nhưng đừng lạm dụng."
            )
        return (
            "You are a friendly home-monitoring assistant chatting with the homeowner. "
            "Sound human and warm — like texting, not a formal report.\n\n"
            "Rules: only use CAMERA_DATA; 2–4 short sentences; mention times (HH:mm); "
            "no bullet lists or technical jargon unless asked."
        )

    @staticmethod
    def _user_message(
        question: str,
        intent: str,
        insight: ActivityInsightResponse,
        draft: str,
        now_ms: int,
        lang: str,
    ) -> str:
        window_label = (
            ChatService._window_phrase_vi(insight.window_ms)
            if lang == "vi"
            else f"last {insight.window_ms // 3600000}h"
        )
        data = ChatService._compact_camera_data(insight, intent, now_ms, lang)
        if lang == "vi":
            return (
                f"Khung thời gian: {window_label}\n\n"
                f"CAMERA_DATA:\n{json.dumps(data, ensure_ascii=False, indent=2)}\n\n"
                f"Gợi ý cách diễn đạt (có thể viết lại cho tự nhiên hơn, không copy nguyên văn):\n{draft}\n\n"
                f"Câu hỏi của chủ nhà: {question}"
            )
        return (
            f"Time window: {window_label}\n\n"
            f"CAMERA_DATA:\n{json.dumps(data, ensure_ascii=False, indent=2)}\n\n"
            f"Draft (rewrite more naturally):\n{draft}\n\n"
            f"Homeowner asks: {question}"
        )

    @staticmethod
    def _polish_answer(text: str) -> str:
        cleaned = (text or "").strip()
        if not cleaned:
            return cleaned
        for prefix in (
            "Trả lời:",
            "Answer:",
            "Dựa trên dữ liệu,",
            "Theo phân tích,",
            "According to the data,",
        ):
            if cleaned.startswith(prefix):
                cleaned = cleaned[len(prefix) :].strip()
        cleaned = re.sub(r"^[-*•]\s+", "", cleaned, flags=re.MULTILINE)
        cleaned = re.sub(r"\n{3,}", "\n\n", cleaned)
        return cleaned.strip()

    def _call_openrouter(
        self,
        question: str,
        intent: str,
        insight: ActivityInsightResponse,
        draft: str,
        now_ms: int,
        fallback: str,
    ) -> str:
        lang = ChatService._detect_language(question)
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
                {"role": "system", "content": ChatService._system_message(lang)},
                {
                    "role": "user",
                    "content": ChatService._user_message(
                        question, intent, insight, draft, now_ms, lang
                    ),
                },
            ],
            "temperature": 0.72,
            "max_tokens": 480,
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
        content = ChatService._polish_answer((message.get("content") or "").strip())
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
        if ChatService._is_greeting(question):
            return "greeting"
        if any(
            token in question
            for token in [
                "áo trắng",
                "ao trang",
                "áo đen",
                "áo đỏ",
                "áo xanh",
                "mặc trắng",
                "white shirt",
                "black shirt",
                "who was",
                "người nào",
            ]
        ):
            return "clothing_check"
        if any(token in question for token in ["té ngã", "te nga", "fall", "ngã", "nga"]):
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
                "có gì",
                "co gi",
                "chuyện gì",
            ]
        ):
            return "activity_summary"
        return "general_summary"

    @staticmethod
    def _build_answer(
        intent: str,
        insight: ActivityInsightResponse,
        now_ms: int,
        lang: str = "vi",
        question: str = "",
    ) -> str:
        if intent == "greeting":
            return ChatService._greeting_answer(lang, insight)

        window_label = (
            ChatService._window_phrase_vi(insight.window_ms)
            if lang == "vi"
            else f"the last {insight.window_ms // 3600000} hours"
        )

        if insight.total_samples == 0 and not insight.fall_detected:
            return (
                f"Mình xem {window_label} thì camera chưa ghi nhận gì đặc biệt. "
                "Bạn thử bật stream, chọn đúng camera, hoặc kéo dài khung giờ xem sao nhé."
                if lang == "vi"
                else f"I checked {window_label} and the camera didn't log anything notable yet. "
                "Try starting the stream or widening the time range."
            )

        if intent == "fall_check":
            if insight.fall_detected and insight.fall_events:
                events = insight.fall_events
                last = events[-1]
                last_t = ChatService._format_hm(getattr(last, "timestamp_ms", 0))
                if lang == "vi":
                    if len(events) == 1:
                        return (
                            f"Có đấy — {window_label} hệ thống báo té ngã một lần, "
                            f"khoảng {last_t}. Bạn xem lại đoạn video lúc đó cho chắc nhé."
                        )
                    return (
                        f"Ừ, có dấu hiệu té ngã — {len(events)} lần trong {window_label}, "
                        f"lần gần nhất khoảng {last_t}. Nên mở clip đúng thời điểm đó xem lại."
                    )
                return (
                    f"Yes — {len(events)} suspected fall(s) in that window; "
                    f"the latest around {last_t}."
                )
            if lang == "vi":
                return f"May là không thấy ai té ngã trong {window_label}. Yên tâm nhé!"
            return "Good news — no falls detected in that time range."

        color_filter = ChatService._extract_color_filter(question)
        log_answer = ChatService._build_answer_from_log_narrative(
            insight,
            lang,
            window_label,
            color_filter=color_filter,
        )
        if log_answer and intent in {
            "general_summary",
            "activity_summary",
            "most_active",
            "general",
            "clothing_check",
        }:
            return log_answer

        if intent == "clothing_check" or color_filter:
            narrative = ChatService._build_narrative_from_moments(
                insight, lang, color_filter=color_filter
            )
            if narrative:
                if lang == "vi":
                    return f"Ừ, {window_label} mình thấy: {narrative}"
                return f"Yes — {narrative}"
            if lang == "vi":
                color_word = ChatService._color_vi(color_filter or "white") or "đó"
                return (
                    f"Trong {window_label} mình không thấy ai mặc áo {color_word} rõ ràng. "
                    "Có thể họ đi nhanh hoặc ngoài góc máy — bạn muốn mình soi khung giờ khác không?"
                )
            return f"I didn't spot anyone in a {color_filter or 'white'} shirt in that period."

        narrative = ChatService._build_narrative_from_moments(insight, lang)
        if narrative and intent in {"general_summary", "activity_summary", "most_active"}:
            if lang == "vi":
                opener = "Nhìn chung " if insight.fall_detected else "Ừ, "
                body = narrative[0].lower() + narrative[1:] if narrative else ""
                return f"{opener}{window_label} thì {body}".strip()
            return narrative
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

        if intent == "most_active":
            action_vi = ChatService._action_phrase_vi(insight.dominant_action)
            if lang == "vi":
                return (
                    f"Chủ yếu là người {action_vi} — chiếm khoảng "
                    f"{insight.dominant_action_ratio * 100:.0f}% thời gian bạn hỏi."
                )
            return (
                f"Mostly {insight.dominant_action} — about "
                f"{insight.dominant_action_ratio * 100:.0f}% of the window."
            )

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

        action_phrase = ChatService._action_phrase_vi(insight.dominant_action)
        if lang == "vi":
            parts = [
                f"{window_label.capitalize()} camera chủ yếu thấy người {action_phrase} "
                f"(khoảng {insight.dominant_action_ratio * 100:.0f}% thời gian).",
            ]
            if scene_text and scene_text != "không thấy người hay vật thể nổi bật":
                parts.append(f"Trong khung hình: {scene_text}.")
            moment_tail = ChatService._build_narrative_from_moments(insight, lang)
            if moment_tail:
                parts.append(moment_tail)
            elif timeline_lines and timeline_lines[0] not in {
                "Không có phân đoạn rõ ràng",
            }:
                short = "; ".join(l.lstrip("- ").split("(")[0].strip() for l in timeline_lines[:3])
                parts.append(f"Chi tiết hơn: {short}.")
            if fall_lines:
                last_ev = insight.fall_events[-1]
                last_t = ChatService._format_hm(getattr(last_ev, "timestamp_ms", 0))
                parts.append(
                    f"Có báo té ngã — lần gần nhất khoảng {last_t}, bạn nên xem lại clip nhé."
                )
            else:
                parts.append("Không thấy té ngã.")
            return " ".join(parts)

        parts_en = [
            f"Over {window_label}, mostly {insight.dominant_action} "
            f"({insight.dominant_action_ratio * 100:.0f}% of the time).",
        ]
        if scene_text:
            parts_en.append(f"Scene: {scene_text}.")
        moment_en = ChatService._build_narrative_from_moments(insight, lang)
        if moment_en:
            parts_en.append(moment_en)
        parts_en.append(
            "Fall detected — check the clip."
            if fall_lines
            else "No falls spotted."
        )
        return " ".join(parts_en)
