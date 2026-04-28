import asyncio

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.core.config import get_settings
import time

from app.models.schemas import (
    ActionSummaryRequest,
    ActionSummaryResponse,
    ActionTimelineResponse,
    HistoryResponse,
    RealtimeStatus,
)
from app.services.inference_service import InferenceService
from app.services.stream_service import state

router = APIRouter()
service = InferenceService()
settings = get_settings()


@router.get("/health")
def api_health() -> dict:
    return {"status": "ok"}


@router.post("/action-summary", response_model=ActionSummaryResponse)
def action_summary(payload: ActionSummaryRequest) -> ActionSummaryResponse:
    return service.summarize_actions(payload)


@router.get("/status", response_model=RealtimeStatus)
def status() -> RealtimeStatus:
    return state.get_latest()


@router.get("/history", response_model=HistoryResponse)
def history(limit: int = 100) -> HistoryResponse:
    return HistoryResponse(items=state.get_history(limit))


@router.get("/summary", response_model=ActionTimelineResponse)
def summary(window_ms: int = 5000) -> ActionTimelineResponse:
    now_ms = int(time.time() * 1000)
    segments = state.summarize_actions(window_ms, now_ms)
    return ActionTimelineResponse(window_ms=window_ms, segments=segments)


@router.websocket("/ws")
async def stream_ws(websocket: WebSocket) -> None:
    await websocket.accept()
    try:
        while True:
            latest = state.get_latest()
            await websocket.send_json(latest.model_dump())
            await asyncio.sleep(settings.ws_interval_ms / 1000)
    except WebSocketDisconnect:
        return
