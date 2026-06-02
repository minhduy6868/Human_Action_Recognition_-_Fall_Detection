from __future__ import annotations

import logging
from dataclasses import dataclass

from app.core.config import get_settings
from app.core.state import RealtimeState
from app.services.alert_engine import AlertEngine
from app.services.notification_service import NotificationService
from app.services.stream_service import StreamService

logger = logging.getLogger(__name__)


def _build_settings_for_source(source_type: str, source_url: str, source_id: str) -> object:
    base = get_settings()
    source_type = (source_type or "").lower().strip()

    overrides: dict[str, object] = {
        "camera_source": source_type or base.camera_source,
        "log_source_id": source_id,
    }

    if source_type == "file":
        overrides["video_file_path"] = source_url
    elif source_type in {"rtsp", "http", "http_mjpeg", "mjpeg"}:
        overrides["rtsp_url"] = source_url
    elif source_type == "webcam":
        try:
            overrides["webcam_index"] = int(source_url)
        except (TypeError, ValueError):
            overrides["webcam_index"] = base.webcam_index

    return base.model_copy(update=overrides)


@dataclass
class StreamSession:
    source_id: str
    user_id: str | None
    source_type: str
    source_url: str
    service: StreamService
    state: RealtimeState


class StreamManager:
    def __init__(self) -> None:
        self._sessions: dict[str, StreamSession] = {}

    def start(self, source_id: str, user_id: str | None, source_type: str, source_url: str) -> StreamSession:
        if source_id in self._sessions:
            return self._sessions[source_id]

        settings = _build_settings_for_source(source_type, source_url, source_id)
        state = RealtimeState(history_size=settings.history_size)
        alert_engine = AlertEngine(state)
        notification_service = NotificationService()
        service = StreamService(
            settings,
            state,
            alert_engine,
            notification_service,
            source_id=source_id,
            user_id=user_id,
        )
        service.start()

        session = StreamSession(
            source_id=source_id,
            user_id=user_id,
            source_type=source_type,
            source_url=source_url,
            service=service,
            state=state,
        )
        self._sessions[source_id] = session
        logger.info("Started stream session: %s", source_id)
        return session

    def stop(self, source_id: str) -> bool:
        session = self._sessions.pop(source_id, None)
        if not session:
            return False
        session.service.stop()
        logger.info("Stopped stream session: %s", source_id)
        return True

    def get(self, source_id: str) -> StreamSession | None:
        return self._sessions.get(source_id)

    def list(self) -> list[StreamSession]:
        return list(self._sessions.values())

    def get_state_for_user(self, user_id: str, source_id: str | None = None) -> RealtimeState | None:
        if source_id:
            session = self.get(source_id)
            if session and session.user_id == user_id:
                return session.state

        for session in self._sessions.values():
            if session.user_id == user_id:
                return session.state
        return None


stream_manager = StreamManager()
