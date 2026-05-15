import re
from datetime import datetime

from app.models.schemas import ActivityInsightResponse, ChatQueryResponse
from app.services.stream_service import state


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
        answer = self._build_answer(intent, insight)
        return ChatQueryResponse(answer=answer, intent=intent, insight=insight)

    def answer_from_insight(
        self,
        question: str,
        insight: ActivityInsightResponse,
    ) -> tuple[str, str]:
        normalized = question.strip().lower()
        intent = self._detect_intent(normalized)
        answer = self._build_answer(intent, insight)
        return answer, intent

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
    def _build_answer(intent: str, insight: ActivityInsightResponse) -> str:
        if insight.total_samples == 0:
            return "Chưa có dữ liệu trong khoảng thời gian bạn hỏi."

        if intent == "fall_check":
            if insight.fall_detected:
                latest = insight.fall_events[-1]
                return (
                    f"Có phát hiện té ngã. Số lần: {len(insight.fall_events)}; "
                    f"lần gần nhất tại {latest.timestamp_ms}."
                )
            return "Không phát hiện té ngã trong khoảng thời gian đã chọn."

        if intent == "most_active":
            return (
                "Hoạt động nhiều nhất là "
                f"{insight.dominant_action} "
                f"({insight.dominant_action_ratio * 100:.1f}%)."
            )

        top_segments = insight.segments[-3:]
        timeline_text = ", ".join(
            f"{seg.action} ({seg.start_ms}->{seg.end_ms})" for seg in top_segments
        )
        fall_text = "có" if insight.fall_detected else "không"
        return (
            f"Tóm tắt hoạt động: {timeline_text}. "
            f"Hoạt động chủ đạo: {insight.dominant_action}. "
            f"Té ngã: {fall_text}."
        )
