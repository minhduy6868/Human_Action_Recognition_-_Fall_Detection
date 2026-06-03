from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from sqlalchemy import or_

from app.db.models import AlertRecord, DetectionLog
from app.models.schemas import AlertEvent, FallEvent


def list_user_alerts(db: Session, user_id: str, limit: int = 100) -> list[AlertEvent]:
    rows = db.execute(
        select(AlertRecord)
        .where(AlertRecord.user_id == user_id)
        .order_by(AlertRecord.timestamp_ms.desc())
        .limit(min(limit, 500))
    ).scalars().all()
    events: list[AlertEvent] = []
    for idx, row in enumerate(rows):
        events.append(
            AlertEvent(
                alert_id=row.id,
                alert_type=row.alert_type,
                severity=row.severity,
                title=row.title,
                message=row.message,
                timestamp_ms=row.timestamp_ms,
                track_id=row.track_id,
                action=row.action,
                confidence=row.confidence,
                metadata=row.metadata_json or {},
            )
        )
    return events


def list_user_fall_alerts_in_window(
    db: Session,
    user_id: str,
    *,
    from_ms: int,
    to_ms: int,
    source_id: str | None = None,
    limit: int = 100,
) -> list[AlertEvent]:
    query = select(AlertRecord).where(
        AlertRecord.user_id == user_id,
        AlertRecord.alert_type == "fall",
        AlertRecord.timestamp_ms >= from_ms,
        AlertRecord.timestamp_ms <= to_ms,
    )
    if source_id:
        query = query.where(
            or_(AlertRecord.source_id == source_id, AlertRecord.source_id.is_(None))
        )
    rows = db.execute(
        query.order_by(AlertRecord.timestamp_ms.asc()).limit(min(limit, 500))
    ).scalars().all()
    return [
        AlertEvent(
            alert_id=row.id,
            alert_type=row.alert_type,
            severity=row.severity,
            title=row.title,
            message=row.message,
            timestamp_ms=row.timestamp_ms,
            track_id=row.track_id,
            action=row.action,
            confidence=row.confidence,
            metadata=row.metadata_json or {},
        )
        for row in rows
    ]


def list_user_fall_events_from_logs(
    db: Session,
    user_id: str,
    limit: int = 100,
    *,
    from_ms: int | None = None,
    to_ms: int | None = None,
    source_id: str | None = None,
) -> list[FallEvent]:
    query = select(DetectionLog).where(
        DetectionLog.user_id == user_id,
        DetectionLog.fall.is_(True),
    )
    if from_ms is not None:
        query = query.where(DetectionLog.timestamp_ms >= from_ms)
    if to_ms is not None:
        query = query.where(DetectionLog.timestamp_ms <= to_ms)
    if source_id:
        query = query.where(
            or_(DetectionLog.source_id == source_id, DetectionLog.source_id.is_(None))
        )
    rows = db.execute(
        query.order_by(DetectionLog.timestamp_ms.desc()).limit(min(limit, 500))
    ).scalars().all()
    return [
        FallEvent(
            detected=True,
            confidence=row.fall_confidence,
            timestamp_ms=row.timestamp_ms,
            action=row.action,
            event_id=row.id,
        )
        for row in rows
    ]
