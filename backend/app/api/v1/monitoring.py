from __future__ import annotations

import asyncio
import time
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, WebSocket, WebSocketDisconnect, status
from fastapi.responses import StreamingResponse
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_current_user_ws
from app.api.response import api_response
from app.core.config import get_settings
from app.db.database import get_db
from app.db.models import ChatHistory, DetectionLog, SourceConnection
from app.models.schemas import (
    ActionSegment,
    ActionSummaryRequest,
    ActivityInsightResponse,
    ActionTimelineResponse,
    ChatQueryRequest,
    ChatHistoryResponse,
    DetectionLogResponse,
    DetectionLogDetailResponse,
    FallEvent,
    RealtimeStatus,
    ReportRequest,
    StreamActivateRequest,
    StreamSessionResponse,
    SummaryQueryRequest,
    SummaryQueryResponse,
)
from app.services.chat_service import ChatService
from app.services.chat_history_store import ChatHistoryStore
from app.services.inference_service import InferenceService
from app.services.stream_manager import stream_manager
from app.services.stream_service import alert_engine, state, stream_service
from app.utils.action_analytics import durations_by_action
from app.utils.video import list_webcams

router = APIRouter()
service = InferenceService()
chat_service = ChatService()
chat_history_store = ChatHistoryStore()
settings = get_settings()


def _enforce_ai_quota(db: Session, user) -> None:
    if (user.plan or "free").lower() != "free":
        return
    if settings.daily_ai_queries_free <= 0:
        return

    now = datetime.now(timezone.utc)
    start_of_day = now.replace(hour=0, minute=0, second=0, microsecond=0)
    count = db.execute(
        select(func.count(ChatHistory.id)).where(
            ChatHistory.user_id == user.id,
            ChatHistory.created_at >= start_of_day,
        )
    ).scalar_one()
    if count >= settings.daily_ai_queries_free:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail={
                "code": "PLAN_LIMIT_REACHED",
                "message": "AI query limit reached for current plan",
                "upgrade_required": True,
            },
        )


def _resolve_source_ids(
    db: Session,
    user_id: str,
    requested: list[str],
) -> list[str]:
    query = select(SourceConnection.id).where(SourceConnection.user_id == user_id)
    if requested:
        query = query.where(SourceConnection.id.in_(requested))
    rows = db.execute(query).scalars().all()
    return [row for row in rows]


def _segments_from_items(items: list[RealtimeStatus]) -> list[ActionSegment]:
    if not items:
        return []

    segments: list[ActionSegment] = []
    current_action = items[0].action
    start_ms = items[0].timestamp_ms
    last_ms = start_ms

    for item in items[1:]:
        if item.action != current_action:
            segments.append(
                ActionSegment(action=current_action, start_ms=start_ms, end_ms=last_ms)
            )
            current_action = item.action
            start_ms = item.timestamp_ms
        last_ms = item.timestamp_ms

    segments.append(ActionSegment(action=current_action, start_ms=start_ms, end_ms=last_ms))
    return segments


def _build_insight(items: list[RealtimeStatus], from_ms: int, to_ms: int) -> ActivityInsightResponse:
    if not items:
        return ActivityInsightResponse(
            window_ms=max(to_ms - from_ms, 0),
            total_samples=0,
            dominant_action="unknown",
            dominant_action_ratio=0.0,
            action_durations_ms={},
            segments=[],
            fall_detected=False,
            fall_events=[],
        )

    durations = durations_by_action(items)
    total_duration = sum(durations.values())
    dominant_action = "unknown"
    dominant_ratio = 0.0
    if durations and total_duration > 0:
        dominant_action = max(durations, key=durations.get)
        dominant_ratio = durations[dominant_action] / total_duration

    segments = _segments_from_items(items)
    fall_events: list[FallEvent] = []
    for idx, item in enumerate([i for i in items if i.fall]):
        fall_events.append(
            FallEvent(
                detected=True,
                confidence=item.fall_confidence,
                timestamp_ms=item.timestamp_ms,
                action=item.action,
                event_id=idx + 1,
            )
        )

    return ActivityInsightResponse(
        window_ms=max(to_ms - from_ms, 0),
        total_samples=len(items),
        dominant_action=dominant_action,
        dominant_action_ratio=round(dominant_ratio, 4),
        action_durations_ms=durations,
        segments=segments,
        fall_detected=bool(fall_events),
        fall_events=fall_events,
    )


def _enforce_single_active_source(db: Session, user_id: str, keep_source_id: str) -> None:
    sources = db.execute(
        select(SourceConnection).where(SourceConnection.user_id == user_id)
    ).scalars().all()
    for source in sources:
        if source.id == keep_source_id:
            continue
        if source.is_active:
            source.is_active = False
            source.updated_at = datetime.now(timezone.utc)
            db.add(source)


def _stop_other_sessions(user_id: str, keep_source_id: str) -> None:
    for session in stream_manager.list():
        if session.user_id == user_id and session.source_id != keep_source_id:
            stream_manager.stop(session.source_id)


@router.get("/health", response_model=dict)
def api_health(request: Request) -> dict:
    return api_response({"status": "ok"}, request)


@router.post("/action-summary", response_model=dict)
def action_summary(
    payload: ActionSummaryRequest,
    request: Request,
    current_user=Depends(get_current_user),
) -> dict:
    result = service.summarize_actions(payload)
    return api_response(result.model_dump(), request)


@router.get("/status", response_model=dict)
def status(request: Request, current_user=Depends(get_current_user)) -> dict:
    latest = state.get_latest()
    return api_response(latest.model_dump(), request)


@router.get("/people", response_model=dict)
def get_people(request: Request, current_user=Depends(get_current_user)) -> dict:
    latest = state.get_latest()
    payload = [person.model_dump() for person in latest.people]
    return api_response(payload, request)


@router.get("/people/{track_id}", response_model=dict)
def get_person(track_id: str, request: Request, current_user=Depends(get_current_user)) -> dict:
    latest = state.get_latest()
    for person in latest.people:
        if person.track_id == track_id:
            return api_response(person.model_dump(), request)
    return api_response(None, request)


@router.get("/objects", response_model=dict)
def get_objects(request: Request, current_user=Depends(get_current_user)) -> dict:
    latest = state.get_latest()
    payload = [obj.model_dump() for obj in latest.objects]
    return api_response(payload, request)


@router.get("/history", response_model=dict)
def history(
    request: Request,
    limit: int = 100,
    current_user=Depends(get_current_user),
) -> dict:
    items = state.get_history(limit)
    return api_response({"items": [item.model_dump() for item in items]}, request)


@router.get("/alerts", response_model=dict)
def alerts(
    request: Request,
    limit: int = 100,
    current_user=Depends(get_current_user),
) -> dict:
    items = state.get_alerts(limit)
    return api_response([item.model_dump() for item in items], request)


@router.get("/alerts/after", response_model=dict)
def alerts_after(
    request: Request,
    after_id: int = 0,
    current_user=Depends(get_current_user),
) -> dict:
    items = state.get_alerts_after(after_id)
    return api_response([item.model_dump() for item in items], request)


@router.get("/fall-events", response_model=dict)
def fall_events(
    request: Request,
    limit: int = 100,
    current_user=Depends(get_current_user),
) -> dict:
    items = state.get_fall_events(limit)
    return api_response([item.model_dump() for item in items], request)


@router.get("/fall-events/after", response_model=dict)
def fall_events_after(
    request: Request,
    after_id: int = 0,
    current_user=Depends(get_current_user),
) -> dict:
    items = state.get_fall_events_after(after_id)
    return api_response([item.model_dump() for item in items], request)


@router.get("/reports", response_model=dict)
def reports(
    request: Request,
    limit: int = 20,
    current_user=Depends(get_current_user),
) -> dict:
    items = state.get_reports(limit)
    return api_response([item.model_dump() for item in items], request)


@router.get("/cameras", response_model=dict)
def cameras(request: Request, current_user=Depends(get_current_user)) -> dict:
    if settings.camera_source.lower() != "webcam":
        payload = {"active_index": settings.webcam_index, "items": []}
        return api_response(payload, request)

    items = list_webcams(settings.webcam_scan_max)
    payload = {"active_index": settings.webcam_index, "items": [item.model_dump() for item in items]}
    return api_response(payload, request)


@router.get("/summary", response_model=dict)
def summary(
    request: Request,
    window_ms: int = 5000,
    current_user=Depends(get_current_user),
) -> dict:
    now_ms = int(time.time() * 1000)
    segments = state.summarize_actions(window_ms, now_ms)
    payload = ActionTimelineResponse(window_ms=window_ms, segments=segments)
    return api_response(payload.model_dump(), request)


@router.get("/insights", response_model=dict)
def insights(
    request: Request,
    window_ms: int = 24 * 60 * 60 * 1000,
    current_user=Depends(get_current_user),
) -> dict:
    now_ms = int(time.time() * 1000)
    insight = ActivityInsightResponse(**state.activity_insight(window_ms=window_ms, now_ms=now_ms))
    return api_response(insight.model_dump(), request)


@router.post("/chat/query", response_model=dict)
def chat_query(
    payload: ChatQueryRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
) -> dict:
    _enforce_ai_quota(db, current_user)
    result = chat_service.answer(payload.question, payload.window_ms)
    chat_history_store.record(
        payload.question,
        result.answer,
        result.intent,
        result.insight.window_ms,
        current_user.id,
    )
    return api_response(result.model_dump(), request)


@router.post("/report/summary", response_model=dict)
def report_summary(
    payload: ReportRequest,
    request: Request,
    current_user=Depends(get_current_user),
) -> dict:
    report = alert_engine.generate_summary_report(payload.window_ms, persist=payload.persist)
    return api_response(report.model_dump(), request)


@router.post("/summary/query", response_model=dict)
def summary_query(
    payload: SummaryQueryRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
) -> dict:
    now = datetime.now(timezone.utc)
    from_dt = payload.from_dt or (now - timedelta(hours=24))
    to_dt = payload.to_dt or now
    if from_dt > to_dt:
        from_dt, to_dt = to_dt, from_dt
    from_ms = int(from_dt.timestamp() * 1000)
    to_ms = int(to_dt.timestamp() * 1000)

    source_ids = _resolve_source_ids(db, current_user.id, payload.source_ids)
    if not source_ids:
        response = SummaryQueryResponse(
            from_ms=from_ms,
            to_ms=to_ms,
            source_ids=[],
            insight=_build_insight([], from_ms, to_ms),
        )
        return api_response(response.model_dump(), request)

    query = select(DetectionLog).where(
        DetectionLog.timestamp_ms >= from_ms,
        DetectionLog.timestamp_ms <= to_ms,
        DetectionLog.source_id.in_(source_ids),
    )
    max_rows = 20000
    rows = db.execute(query.order_by(DetectionLog.timestamp_ms.asc()).limit(max_rows)).scalars().all()

    items: list[RealtimeStatus] = []
    for row in rows:
        items.append(
            RealtimeStatus(
                action=row.action,
                confidence=row.confidence,
                fall=row.fall,
                fall_confidence=row.fall_confidence,
                timestamp_ms=row.timestamp_ms,
                track_id=row.track_id,
                objects=[],
                people=[],
            )
        )

    insight = _build_insight(items, from_ms, to_ms)
    answer = None
    intent = None
    if payload.question:
        _enforce_ai_quota(db, current_user)
        answer, intent = chat_service.answer_from_insight(payload.question, insight)
        chat_history_store.record(
            payload.question,
            answer,
            intent,
            insight.window_ms,
            current_user.id,
        )

    response = SummaryQueryResponse(
        from_ms=from_ms,
        to_ms=to_ms,
        source_ids=source_ids,
        insight=insight,
        answer=answer,
        intent=intent,
    )
    return api_response(response.model_dump(), request)

@router.get("/logs", response_model=dict)
def logs(
    request: Request,
    from_ms: int | None = None,
    to_ms: int | None = None,
    limit: int = 500,
    track_id: str | None = None,
    source_id: str | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
) -> dict:
    query = select(DetectionLog)
    if from_ms is not None:
        query = query.where(DetectionLog.timestamp_ms >= from_ms)
    if to_ms is not None:
        query = query.where(DetectionLog.timestamp_ms <= to_ms)
    if track_id:
        query = query.where(DetectionLog.track_id == track_id)
    if source_id:
        query = query.where(DetectionLog.source_id == source_id)

    items = db.execute(
        query.order_by(DetectionLog.timestamp_ms.desc()).limit(min(limit, 5000))
    ).scalars().all()
    payload = [
        DetectionLogResponse(
            id=item.id,
            timestamp_ms=item.timestamp_ms,
            track_id=item.track_id,
            action=item.action,
            confidence=item.confidence,
            fall=item.fall,
            fall_confidence=item.fall_confidence,
            people_count=item.people_count,
            objects_count=item.objects_count,
            source_id=item.source_id,
        ).model_dump()
        for item in items
    ]
    return api_response(payload, request)

@router.get("/logs/{log_id}", response_model=dict)
def log_detail(
    log_id: int,
    request: Request,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
) -> dict:
    item = db.execute(
        select(DetectionLog).where(DetectionLog.id == log_id)
    ).scalar_one_or_none()
    if item is None:
        return api_response({}, request)

    payload = DetectionLogDetailResponse(
        id=item.id,
        timestamp_ms=item.timestamp_ms,
        track_id=item.track_id,
        action=item.action,
        confidence=item.confidence,
        fall=item.fall,
        fall_confidence=item.fall_confidence,
        people_count=item.people_count,
        objects_count=item.objects_count,
        source_id=item.source_id,
        people=item.people_json or [],
        objects=item.objects_json or [],
    ).model_dump()
    return api_response(payload, request)


@router.get("/chat/history", response_model=dict)
def chat_history(
    request: Request,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
) -> dict:
    items = db.execute(
        select(ChatHistory)
        .where(ChatHistory.user_id == current_user.id)
        .order_by(ChatHistory.created_at.desc())
        .limit(min(limit, 500))
    ).scalars().all()
    payload = [
        ChatHistoryResponse(
            id=item.id,
            question=item.question,
            answer=item.answer,
            intent=item.intent,
            window_ms=item.window_ms,
            source_id=item.source_id,
            created_at=item.created_at,
        ).model_dump()
        for item in items
    ]
    return api_response(payload, request)


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


@router.post("/streams/start", response_model=dict)
def start_stream(
    payload: StreamActivateRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
) -> dict:
    source = db.execute(
        select(SourceConnection).where(
            SourceConnection.id == payload.source_id,
            SourceConnection.user_id == current_user.id,
        )
    ).scalar_one_or_none()
    if source is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "NOT_FOUND", "message": "Source not found"},
        )

    if (current_user.plan or "free").lower() == "free":
        _enforce_single_active_source(db, current_user.id, keep_source_id=source.id)
        _stop_other_sessions(current_user.id, keep_source_id=source.id)

    source.is_active = True
    source.updated_at = datetime.now(timezone.utc)
    db.add(source)
    db.commit()

    session = stream_manager.start(
        source_id=source.id,
        user_id=current_user.id,
        source_type=source.source_type,
        source_url=source.source_url,
    )
    response = StreamSessionResponse(
        source_id=session.source_id,
        user_id=session.user_id,
        source_type=session.source_type,
        source_url=session.source_url,
        active=True,
    )
    return api_response(response.model_dump(), request)


@router.post("/streams/stop", response_model=dict)
def stop_stream(
    payload: StreamActivateRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
) -> dict:
    source = db.execute(
        select(SourceConnection).where(
            SourceConnection.id == payload.source_id,
            SourceConnection.user_id == current_user.id,
        )
    ).scalar_one_or_none()
    if source is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "NOT_FOUND", "message": "Source not found"},
        )

    source.is_active = False
    source.updated_at = datetime.now(timezone.utc)
    db.add(source)
    db.commit()
    stream_manager.stop(source.id)

    response = StreamSessionResponse(
        source_id=source.id,
        user_id=current_user.id,
        source_type=source.source_type,
        source_url=source.source_url,
        active=False,
    )
    return api_response(response.model_dump(), request)


@router.get("/streams", response_model=dict)
def list_streams(
    request: Request,
    current_user=Depends(get_current_user),
) -> dict:
    sessions = [
        StreamSessionResponse(
            source_id=session.source_id,
            user_id=session.user_id,
            source_type=session.source_type,
            source_url=session.source_url,
            active=True,
        ).model_dump()
        for session in stream_manager.list()
        if session.user_id == current_user.id
    ]
    return api_response(sessions, request)


@router.get("/streams/{source_id}/status", response_model=dict)
def stream_status(
    source_id: str,
    request: Request,
    current_user=Depends(get_current_user),
) -> dict:
    session = stream_manager.get(source_id)
    if session is None or session.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "NOT_FOUND", "message": "Stream not found"},
        )
    return api_response(session.state.get_latest().model_dump(), request)


@router.get("/streams/{source_id}/mjpeg")
def mjpeg_stream_by_source(source_id: str, request: Request, current_user=Depends(get_current_user)) -> StreamingResponse:
    session = stream_manager.get(source_id)
    if session is None or session.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "NOT_FOUND", "message": "Stream not found"},
        )

    boundary = "frame"

    def generate():
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
async def stream_ws(websocket: WebSocket, current_user=Depends(get_current_user_ws), db: Session = Depends(get_db)) -> None:
    await websocket.accept()
    # Start all active sources for this user (presence-driven)
    try:
        sources = db.execute(
            select(SourceConnection).where(SourceConnection.user_id == current_user.id, SourceConnection.is_active == True)
        ).scalars().all()
        for src in sources:
            stream_manager.start(source_id=src.id, user_id=current_user.id, source_type=src.source_type, source_url=src.source_url)

        while True:
            latest = state.get_latest()
            await websocket.send_json(latest.model_dump())
            await asyncio.sleep(settings.ws_interval_ms / 1000)
    except WebSocketDisconnect:
        # Stop all sessions belonging to this user when websocket disconnects
        for session in stream_manager.list():
            if session.user_id == current_user.id:
                stream_manager.stop(session.source_id)
        return


@router.websocket("/ws/fall-alerts")
async def fall_alert_ws(websocket: WebSocket, current_user=Depends(get_current_user_ws), db: Session = Depends(get_db)) -> None:
    await websocket.accept()
    # Ensure user's active sources are running while connected
    try:
        sources = db.execute(
            select(SourceConnection).where(SourceConnection.user_id == current_user.id, SourceConnection.is_active == True)
        ).scalars().all()
        for src in sources:
            stream_manager.start(source_id=src.id, user_id=current_user.id, source_type=src.source_type, source_url=src.source_url)

        last_event_id = 0
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
        for session in stream_manager.list():
            if session.user_id == current_user.id:
                stream_manager.stop(session.source_id)
        return


@router.websocket("/ws/alerts")
async def alert_ws(websocket: WebSocket, current_user=Depends(get_current_user_ws), db: Session = Depends(get_db)) -> None:
    await websocket.accept()
    try:
        sources = db.execute(
            select(SourceConnection).where(SourceConnection.user_id == current_user.id, SourceConnection.is_active == True)
        ).scalars().all()
        for src in sources:
            stream_manager.start(source_id=src.id, user_id=current_user.id, source_type=src.source_type, source_url=src.source_url)

        last_alert_id = 0
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
        for session in stream_manager.list():
            if session.user_id == current_user.id:
                stream_manager.stop(session.source_id)
        return
