from __future__ import annotations

import logging
import time
from datetime import datetime, timedelta, timezone

from app.core.config import get_settings
from app.db.database import SessionLocal
from app.db.models import ChatHistory

logger = logging.getLogger(__name__)
settings = get_settings()


class ChatHistoryStore:
    def __init__(self) -> None:
        self._enabled = settings.chat_history_enabled
        self._last_cleanup_ms = 0

    def record(
        self,
        question: str,
        answer: str,
        intent: str,
        window_ms: int,
        user_id: str | None,
        source_id: str | None = None,
    ) -> None:
        if not self._enabled:
            return
        try:
            with SessionLocal() as db:
                db.add(
                    ChatHistory(
                        user_id=user_id,
                        source_id=source_id or settings.log_source_id,
                        question=question,
                        answer=answer,
                        intent=intent,
                        window_ms=window_ms,
                    )
                )
                db.commit()
        except Exception as exc:  # pragma: no cover - defensive logging
            logger.exception("Chat history insert failed: %s", exc)

        self._cleanup_if_needed()

    def _cleanup_if_needed(self) -> None:
        if settings.chat_history_retention_days <= 0:
            return

        now_ms = int(time.time() * 1000)
        if now_ms - self._last_cleanup_ms < settings.chat_history_cleanup_interval_ms:
            return

        cutoff = datetime.now(timezone.utc) - timedelta(days=settings.chat_history_retention_days)
        try:
            with SessionLocal() as db:
                db.query(ChatHistory).filter(ChatHistory.created_at < cutoff).delete()
                db.commit()
            self._last_cleanup_ms = now_ms
        except Exception as exc:  # pragma: no cover - defensive logging
            logger.exception("Chat history cleanup failed: %s", exc)
