from __future__ import annotations

import logging
import time
from datetime import datetime, timedelta, timezone

from app.core.config import get_settings
from app.db.database import SessionLocal
from app.db.models import DetectionLog
from app.models.schemas import RealtimeStatus

logger = logging.getLogger(__name__)
settings = get_settings()


class DetectionLogStore:
    def __init__(self) -> None:
        self._enabled = settings.log_enabled
        self._last_cleanup_ms = 0

    def enabled(self) -> bool:
        return self._enabled

    def log_status(
        self,
        status: RealtimeStatus,
        frame_index: int,
        source_id: str | None = None,
        user_id: str | None = None,
        model_version_id: int | None = None,
    ) -> None:
        if not self._enabled:
            return
        if settings.log_every_n_frames > 1 and frame_index % settings.log_every_n_frames != 0:
            return

        try:
            with SessionLocal() as db:
                people_payload = [person.model_dump() for person in status.people]
                objects_payload = [obj.model_dump() for obj in status.objects]

                log = DetectionLog(
                    timestamp_ms=status.timestamp_ms,
                    track_id=status.track_id,
                    action=status.action,
                    confidence=status.confidence,
                    fall=status.fall,
                    fall_confidence=status.fall_confidence,
                    people_count=len(people_payload),
                    objects_count=len(objects_payload),
                    people_json=people_payload,
                    objects_json=objects_payload,
                    source_id=source_id or settings.log_source_id,
                    user_id=user_id,
                    model_version_id=model_version_id,
                )
                db.add(log)
                db.commit()
        except Exception as exc:  # pragma: no cover - defensive logging
            logger.exception("Detection log insert failed: %s", exc)

        self._cleanup_if_needed()

    def _cleanup_if_needed(self) -> None:
        if settings.log_retention_days <= 0:
            return

        now_ms = int(time.time() * 1000)
        if now_ms - self._last_cleanup_ms < settings.log_cleanup_interval_ms:
            return

        cutoff = datetime.now(timezone.utc) - timedelta(days=settings.log_retention_days)
        try:
            with SessionLocal() as db:
                db.query(DetectionLog).filter(DetectionLog.created_at < cutoff).delete()
                db.commit()
            self._last_cleanup_ms = now_ms
        except Exception as exc:  # pragma: no cover - defensive logging
            logger.exception("Detection log cleanup failed: %s", exc)
