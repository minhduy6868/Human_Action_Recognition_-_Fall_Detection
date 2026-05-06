import time

from app.core.config import get_settings
from app.models.schemas import ActionSummaryRequest, ActionSummaryResponse
from app.pipelines.action_summary import summarize_history
from app.services.stream_service import state

settings = get_settings()


class InferenceService:
    def summarize_actions(self, payload: ActionSummaryRequest) -> ActionSummaryResponse:
        now_ms = int(time.time() * 1000)
        items = state.get_history(settings.history_size)
        return summarize_history(items, payload.track_id, payload.window_ms, now_ms)
