from __future__ import annotations

import logging
from typing import Any

from app.core.config import get_settings
from app.db.database import SessionLocal
from app.db.models import AlertRecord, SummaryReportRecord

logger = logging.getLogger(__name__)
settings = get_settings()


class PostgresStore:
    def __init__(self) -> None:
        self._enabled = settings.database_enabled

    def enabled(self) -> bool:
        return self._enabled

    def insert_alert(self, payload: dict[str, Any]) -> bool:
        return self._insert_alert(payload)

    def insert_report(self, payload: dict[str, Any]) -> bool:
        return self._insert_report(payload)

    def _insert_alert(self, payload: dict[str, Any]) -> bool:
        if not self._enabled:
            return False

        try:
            with SessionLocal() as db:
                metadata = payload.get("metadata") or {}
                if not isinstance(metadata, dict):
                    metadata = {}
                record = AlertRecord(
                    user_id=payload.get("user_id") or metadata.get("user_id"),
                    source_id=payload.get("source_id") or metadata.get("source_id"),
                    alert_type=payload.get("alert_type", ""),
                    severity=payload.get("severity", ""),
                    title=payload.get("title", ""),
                    message=payload.get("message", ""),
                    timestamp_ms=payload.get("timestamp_ms", 0),
                    track_id=payload.get("track_id", ""),
                    action=payload.get("action", ""),
                    confidence=payload.get("confidence", 0.0),
                    source=payload.get("source", "backend"),
                    metadata_json=metadata,
                )
                db.add(record)
                db.commit()
            return True
        except Exception as exc:  # pragma: no cover - defensive logging
            logger.exception("Postgres insert alert failed: %s", exc)
            return False

    def _insert_report(self, payload: dict[str, Any]) -> bool:
        if not self._enabled:
            return False

        try:
            with SessionLocal() as db:
                insight_raw = payload.get("insight", {})
                if hasattr(insight_raw, "model_dump"):
                    insight_raw = insight_raw.model_dump()
                record = SummaryReportRecord(
                    user_id=payload.get("user_id"),
                    source_id=payload.get("source_id"),
                    title=payload.get("title", ""),
                    window_ms=payload.get("window_ms", 0),
                    generated_at_ms=payload.get("generated_at_ms", 0),
                    insight=insight_raw if isinstance(insight_raw, dict) else {},
                    alert_counts=payload.get("alert_counts", {}),
                )
                db.add(record)
                db.commit()
            return True
        except Exception as exc:  # pragma: no cover - defensive logging
            logger.exception("Postgres insert report failed: %s", exc)
            return False
