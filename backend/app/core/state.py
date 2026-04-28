from threading import Lock

from app.models.schemas import ActionSegment, RealtimeStatus


class RealtimeState:
    def __init__(self, history_size: int = 200) -> None:
        self._lock = Lock()
        self._history_size = history_size
        self._latest = RealtimeStatus()
        self._history: list[RealtimeStatus] = []

    def update(self, status: RealtimeStatus) -> None:
        with self._lock:
            self._latest = status
            self._history.append(status)
            if len(self._history) > self._history_size:
                self._history = self._history[-self._history_size :]

    def get_latest(self) -> RealtimeStatus:
        with self._lock:
            return self._latest

    def get_history(self, limit: int) -> list[RealtimeStatus]:
        with self._lock:
            return list(self._history[-limit:])

    def summarize_actions(self, window_ms: int, now_ms: int) -> list[ActionSegment]:
        with self._lock:
            items = [
                item for item in self._history if item.timestamp_ms >= now_ms - window_ms
            ]

        if not items:
            return []

        segments: list[ActionSegment] = []
        current_action = items[0].action
        start_ms = items[0].timestamp_ms
        last_ms = start_ms

        for item in items[1:]:
            if item.action != current_action:
                segments.append(
                    ActionSegment(action=current_action, start_ms=start_ms, end_ms=last_ms)
                )
                current_action = item.action
                start_ms = item.timestamp_ms
            last_ms = item.timestamp_ms

        segments.append(ActionSegment(action=current_action, start_ms=start_ms, end_ms=last_ms))
        return segments
