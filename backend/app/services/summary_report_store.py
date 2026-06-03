from __future__ import annotations

import logging
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import SummaryReportRecord
from app.models.schemas import ActivityInsightResponse, SummaryReportResponse

logger = logging.getLogger(__name__)


def _insight_from_row(insight_raw: dict[str, Any]) -> ActivityInsightResponse:
    try:
        return ActivityInsightResponse(**insight_raw)
    except Exception:
        return ActivityInsightResponse(
            window_ms=0,
            total_samples=0,
            dominant_action="unknown",
            dominant_action_ratio=0.0,
            action_durations_ms={},
            segments=[],
            fall_detected=False,
            fall_events=[],
        )


def row_to_report(row: SummaryReportRecord) -> SummaryReportResponse:
    return SummaryReportResponse(
        report_id=row.id,
        source_id=row.source_id,
        title=row.title,
        window_ms=row.window_ms,
        generated_at_ms=row.generated_at_ms,
        insight=_insight_from_row(row.insight or {}),
        alert_counts=row.alert_counts or {},
    )


def list_user_reports(
    db: Session,
    user_id: str,
    *,
    source_id: str | None = None,
    limit: int = 20,
) -> list[SummaryReportResponse]:
    query = select(SummaryReportRecord).where(SummaryReportRecord.user_id == user_id)
    if source_id:
        query = query.where(SummaryReportRecord.source_id == source_id)
    rows = db.execute(
        query.order_by(SummaryReportRecord.generated_at_ms.desc()).limit(min(limit, 100))
    ).scalars().all()
    return [row_to_report(row) for row in rows]


def upsert_user_reports(
    db: Session,
    user_id: str,
    reports: list[SummaryReportResponse],
) -> None:
    if not reports:
        return

    for report in reports:
        sid = report.source_id
        if sid is None and "—" in report.title:
            sid = report.title.split("—")[-1].strip()

        existing = db.execute(
            select(SummaryReportRecord).where(
                SummaryReportRecord.user_id == user_id,
                SummaryReportRecord.source_id == sid,
                SummaryReportRecord.window_ms == report.window_ms,
            )
        ).scalar_one_or_none()

        insight_payload = report.insight.model_dump()
        if existing is not None:
            existing.title = report.title
            existing.generated_at_ms = report.generated_at_ms
            existing.insight = insight_payload
            existing.alert_counts = report.alert_counts
            db.add(existing)
            continue

        db.add(
            SummaryReportRecord(
                user_id=user_id,
                source_id=sid,
                title=report.title,
                window_ms=report.window_ms,
                generated_at_ms=report.generated_at_ms,
                insight=insight_payload,
                alert_counts=report.alert_counts,
            )
        )

    try:
        db.commit()
    except Exception as exc:
        db.rollback()
        logger.exception("Failed to upsert summary reports: %s", exc)
