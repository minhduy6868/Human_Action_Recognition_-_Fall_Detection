from threading import Lock

from app.models.schemas import RealtimeStatus


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
