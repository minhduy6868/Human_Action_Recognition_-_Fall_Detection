"""Helpers to keep realtime/API data isolated per authenticated user."""

from __future__ import annotations

from app.core.config import get_settings
from app.core.state import RealtimeState


def isolated_realtime_state() -> RealtimeState:
    """Empty in-memory state — never reuse the process-wide singleton."""
    settings = get_settings()
    return RealtimeState(history_size=settings.history_size)
