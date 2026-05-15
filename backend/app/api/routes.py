import asyncio
import time
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect
from fastapi.responses import StreamingResponse

from app.core.config import get_settings
from app.db.database import get_db
from app.api.deps import get_optional_user

from app.models.schemas import (
    ActivityInsightResponse,
    ActionSummaryRequest,
    ActionSummaryResponse,
    ActionTimelineResponse,
    AlertEvent,
    CameraListResponse,
    ChatQueryRequest,
    ChatQueryResponse,
    DetectedObject,
    DeviceTokenRemoveRequest,
    DeviceTokenRequest,
    DeviceTokenResponse,
    FallEvent,
    HistoryResponse,
    OtpRequestPayload,
    OtpResponse,
    OtpVerifyPayload,
    PersonAction,
    RealtimeStatus,
    ReportRequest,
    SummaryReportResponse,
    StreamSessionResponse,
    StreamStartRequest,
    StreamStopRequest,
)
from app.services.inference_service import InferenceService
from app.services.chat_service import ChatService
from app.services.notification_service import NotificationService
from app.services.stream_manager import stream_manager
from app.services.stream_service import alert_engine, state, stream_service
from app.utils.video import list_webcams

router = APIRouter()
service = InferenceService()
chat_service = ChatService()
settings = get_settings()
notification_service = NotificationService()


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


@router.get("/objects", response_model=list[DetectedObject])
def get_objects() -> list[DetectedObject]:
    """✅ NEW: Trả về danh sách tất cả đối tượng (người + vật khác)"""
    latest = state.get_latest()
    return latest.objects


@router.get("/history", response_model=HistoryResponse)
def history(limit: int = 100) -> HistoryResponse:
    return HistoryResponse(items=state.get_history(limit))


@router.get("/alerts", response_model=list[AlertEvent])
def alerts(limit: int = 100) -> list[AlertEvent]:
    return state.get_alerts(limit)


@router.get("/alerts/after", response_model=list[AlertEvent])
def alerts_after(after_id: int = 0) -> list[AlertEvent]:
    return state.get_alerts_after(after_id)


@router.get("/fall-events", response_model=list[FallEvent])
def fall_events(limit: int = 100) -> list[FallEvent]:
    return state.get_fall_events(limit)


@router.get("/fall-events/after", response_model=list[FallEvent])
def fall_events_after(after_id: int = 0) -> list[FallEvent]:
    return state.get_fall_events_after(after_id)


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


@router.post("/devices/register", response_model=DeviceTokenResponse)
def register_device_token(
    payload: DeviceTokenRequest,
    user=Depends(get_optional_user),
    db=Depends(get_db),
) -> DeviceTokenResponse:
    from app.db.models import DeviceToken

    existing = db.query(DeviceToken).filter(DeviceToken.token == payload.token).first()
    if existing:
        existing.is_active = True
        existing.platform = payload.platform
        existing.source_id = payload.source_id
        existing.last_seen_at = datetime.now(timezone.utc)
    else:
        db.add(
            DeviceToken(
                user_id=user.id if user else None,
                token=payload.token,
                platform=payload.platform,
                source_id=payload.source_id,
                is_active=True,
                last_seen_at=datetime.now(timezone.utc),
            )
        )
    db.commit()
    return DeviceTokenResponse(registered=True)


@router.post("/devices/unregister", response_model=DeviceTokenResponse)
def unregister_device_token(
    payload: DeviceTokenRemoveRequest,
    db=Depends(get_db),
) -> DeviceTokenResponse:
    from app.db.models import DeviceToken

    record = db.query(DeviceToken).filter(DeviceToken.token == payload.token).first()
    if record:
        record.is_active = False
        db.commit()
    return DeviceTokenResponse(registered=False)


@router.post("/otp/request", response_model=OtpResponse)
def request_otp(payload: OtpRequestPayload) -> OtpResponse:
    result = notification_service.request_otp(payload.email, payload.purpose)
    return OtpResponse(ok=True, expires_in=result["expires_in"])


@router.post("/otp/verify", response_model=OtpResponse)
def verify_otp(payload: OtpVerifyPayload) -> OtpResponse:
    ok = notification_service.verify_otp(payload.email, payload.otp, payload.purpose)
    return OtpResponse(ok=ok)


@router.post("/streams/start", response_model=StreamSessionResponse)
def start_stream(payload: StreamStartRequest, user=Depends(get_optional_user)) -> StreamSessionResponse:
    session = stream_manager.start(
        source_id=payload.source_id,
        user_id=user.id if user else None,
        source_type=payload.source_type,
        source_url=payload.source_url,
    )
    return StreamSessionResponse(
        source_id=session.source_id,
        user_id=session.user_id,
        source_type=session.source_type,
        source_url=session.source_url,
        active=True,
    )


@router.post("/streams/stop", response_model=StreamSessionResponse)
def stop_stream(payload: StreamStopRequest) -> StreamSessionResponse:
    stopped = stream_manager.stop(payload.source_id)
    return StreamSessionResponse(
        source_id=payload.source_id,
        user_id=None,
        source_type="",
        source_url="",
        active=not stopped,
    )


@router.get("/streams", response_model=list[StreamSessionResponse])
def list_streams() -> list[StreamSessionResponse]:
    return [
        StreamSessionResponse(
            source_id=session.source_id,
            user_id=session.user_id,
            source_type=session.source_type,
            source_url=session.source_url,
            active=True,
        )
        for session in stream_manager.list()
    ]


@router.get("/streams/{source_id}/status", response_model=RealtimeStatus)
def stream_status(source_id: str) -> RealtimeStatus:
    session = stream_manager.get(source_id)
    if session is None:
        return RealtimeStatus()
    return session.state.get_latest()


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


@router.get("/streams/{source_id}/mjpeg")
def mjpeg_stream_by_source(source_id: str) -> StreamingResponse:
    boundary = "frame"

    def generate():
        session = stream_manager.get(source_id)
        if session is None:
            return
        while True:
            frame = session.service.get_latest_frame()
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
