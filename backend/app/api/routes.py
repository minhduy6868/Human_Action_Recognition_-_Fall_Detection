import asyncio
import time

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from fastapi.responses import StreamingResponse

from app.core.config import get_settings

from app.models.schemas import (
    ActivityInsightResponse,
    ActionSummaryRequest,
    ActionSummaryResponse,
    ActionTimelineResponse,
    AlertEvent,
    CameraListResponse,
    ChatQueryRequest,
    ChatQueryResponse,
    HistoryResponse,
    PersonAction,
    RealtimeStatus,
    ReportRequest,
    SummaryReportResponse,
)
from app.services.inference_service import InferenceService
from app.services.chat_service import ChatService
from app.services.stream_service import alert_engine, state, stream_service
from app.utils.video import list_webcams

router = APIRouter()
service = InferenceService()
chat_service = ChatService()
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


@router.get("/people", response_model=list[PersonAction])
def get_people() -> list[PersonAction]:
    """✅ NEW: Trả về danh sách tất cả người được phát hiện hiện tại"""
    latest = state.get_latest()
    return latest.people


@router.get("/people/{track_id}", response_model=PersonAction | None)
def get_person(track_id: str) -> PersonAction | None:
    """✅ NEW: Trả về thông tin chi tiết 1 người cụ thể"""
    latest = state.get_latest()
    for person in latest.people:
        if person.track_id == track_id:
            return person
    return None


@router.get("/objects", response_model=list)
def get_objects():
    """✅ NEW: Trả về danh sách tất cả đối tượng (người + vật khác)"""
    latest = state.get_latest()
    return [
        {
            "class_id": obj.class_id,
            "label": obj.label,
            "confidence": obj.confidence,
            "bbox": {"x1": obj.x1, "y1": obj.y1, "x2": obj.x2, "y2": obj.y2},
            "track_id": obj.track_id,
        }
        for obj in latest.objects
    ]


@router.get("/history", response_model=HistoryResponse)
def history(limit: int = 100) -> HistoryResponse:
    return HistoryResponse(items=state.get_history(limit))


@router.get("/alerts", response_model=list[AlertEvent])
def alerts(limit: int = 100) -> list[AlertEvent]:
    return state.get_alerts(limit)


@router.get("/reports", response_model=list[SummaryReportResponse])
def reports(limit: int = 20) -> list[SummaryReportResponse]:
    return state.get_reports(limit)


@router.get("/cameras", response_model=CameraListResponse)
def cameras() -> CameraListResponse:
    if settings.camera_source.lower() != "webcam":
        return CameraListResponse(active_index=settings.webcam_index, items=[])

    items = list_webcams(settings.webcam_scan_max)
    return CameraListResponse(active_index=settings.webcam_index, items=items)


@router.get("/summary", response_model=ActionTimelineResponse)
def summary(window_ms: int = 5000) -> ActionTimelineResponse:
    now_ms = int(time.time() * 1000)
    segments = state.summarize_actions(window_ms, now_ms)
    return ActionTimelineResponse(window_ms=window_ms, segments=segments)


@router.get("/insights", response_model=ActivityInsightResponse)
def insights(window_ms: int = 24 * 60 * 60 * 1000) -> ActivityInsightResponse:
    now_ms = int(time.time() * 1000)
    return ActivityInsightResponse(**state.activity_insight(window_ms=window_ms, now_ms=now_ms))


@router.post("/chat/query", response_model=ChatQueryResponse)
def chat_query(payload: ChatQueryRequest) -> ChatQueryResponse:
    return chat_service.answer(payload.question, payload.window_ms)


@router.post("/report/summary", response_model=SummaryReportResponse)
def report_summary(payload: ReportRequest) -> SummaryReportResponse:
    return alert_engine.generate_summary_report(payload.window_ms, persist=payload.persist)


@router.get("/stream/mjpeg")
def mjpeg_stream() -> StreamingResponse:
    boundary = "frame"

    def generate():
        while True:
            frame = stream_service.get_latest_frame()
            if frame:
                yield (
                    f"--{boundary}\r\n"
                    "Content-Type: image/jpeg\r\n\r\n"
                ).encode("utf-8") + frame + b"\r\n"
            time.sleep(max(1.0 / max(settings.mjpeg_fps, 1), 0.05))

    return StreamingResponse(
        generate(),
        media_type=f"multipart/x-mixed-replace; boundary={boundary}",
    )


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


@router.websocket("/ws/fall-alerts")
async def fall_alert_ws(websocket: WebSocket) -> None:
    await websocket.accept()
    last_event_id = 0
    try:
        while True:
            events = state.get_fall_events_after(last_event_id)
            for event in events:
                await websocket.send_json(
                    {
                        "type": "fall_alert",
                        "event": event.model_dump(),
                    }
                )
                last_event_id = event.event_id
            await asyncio.sleep(0.1)
    except WebSocketDisconnect:
        return


@router.websocket("/ws/alerts")
async def alert_ws(websocket: WebSocket) -> None:
    await websocket.accept()
    last_alert_id = 0
    try:
        while True:
            alerts = state.get_alerts_after(last_alert_id)
            for alert in alerts:
                await websocket.send_json(
                    {
                        "type": alert.alert_type,
                        "alert": alert.model_dump(),
                    }
                )
                last_alert_id = alert.alert_id
            await asyncio.sleep(0.1)
    except WebSocketDisconnect:
        return
