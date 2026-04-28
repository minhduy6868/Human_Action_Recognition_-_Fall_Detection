from app.models.schemas import ActionSummaryRequest, ActionSummaryResponse
from app.pipelines.action_summary import run_action_summary


class InferenceService:
    def summarize_actions(self, payload: ActionSummaryRequest) -> ActionSummaryResponse:
        return run_action_summary(payload)
