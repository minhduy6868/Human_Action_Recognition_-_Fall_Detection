import logging
import time
from collections.abc import Iterable

from app.core.config import get_settings
from app.core.state import RealtimeState
from app.models.schemas import (
    ActivityInsightResponse,
    AlertEvent,
    RealtimeStatus,
    SummaryReportResponse,
)
from app.services.postgres_store import PostgresStore

logger = logging.getLogger(__name__)
settings = get_settings()


class AlertEngine:
    def __init__(self, state: RealtimeState) -> None:
        self._state = state
        self._store = PostgresStore()
        self._last_anomaly_check_ms = 0
        self._last_abnormal_signature = ""
        self._last_abnormal_alert_ms = 0

    def observe(self, status: RealtimeStatus) -> list[AlertEvent]:
        if status.timestamp_ms - self._last_anomaly_check_ms < settings.alert_check_interval_ms:
            return []

        self._last_anomaly_check_ms = status.timestamp_ms
        insight = self._state.activity_insight(
            window_ms=settings.abnormal_window_ms,
            now_ms=status.timestamp_ms,
        )

        if insight["total_samples"] < settings.abnormal_min_samples:
            return []

        durations = insight["action_durations_ms"]
        segments = insight["segments"]
        dominant_action = insight["dominant_action"]
        dominant_ratio = float(insight["dominant_action_ratio"])
        transitions = max(len(segments) - 1, 0)
        lying_ms = durations.get("lying", 0)

        reasons: list[str] = []
        score = 0.0

        if lying_ms >= settings.abnormal_lying_ms:
            score += 0.45
            reasons.append(f"lying for {lying_ms} ms")
        if transitions >= settings.abnormal_transition_threshold:
            score += 0.25
            reasons.append(f"frequent transitions: {transitions}")
        if dominant_ratio <= settings.abnormal_dominant_action_ratio:
            score += 0.2
            reasons.append(f"dominant action ratio low: {dominant_ratio:.2f}")
        if dominant_action not in {"standing", "walking", "sitting", "idle"}:
            score += 0.1
            reasons.append(f"dominant action is unusual: {dominant_action}")

        if score < settings.abnormal_min_score:
            return []

        signature = f"{dominant_action}:{transitions}:{lying_ms}:{round(dominant_ratio, 2)}"
        if (
            signature == self._last_abnormal_signature
            and status.timestamp_ms - self._last_abnormal_alert_ms < settings.abnormal_suppression_ms
        ):
            return []

        alert = AlertEvent(
            alert_type="abnormal_behavior",
            severity="warning",
            title="Abnormal behavior detected",
            message="; ".join(reasons) if reasons else "Behavior differs from recent baseline",
            timestamp_ms=status.timestamp_ms,
            track_id=status.track_id,
            action=status.action,
            confidence=min(1.0, round(score, 4)),
            metadata={
                "window_ms": settings.abnormal_window_ms,
                "total_samples": insight["total_samples"],
                "dominant_action": dominant_action,
                "dominant_action_ratio": dominant_ratio,
                "transitions": transitions,
                "lying_ms": lying_ms,
                "reasons": reasons,
            },
        )
        recorded = self._state.record_alert(alert)
        self._publish_alerts([recorded])
        self._last_abnormal_signature = signature
        self._last_abnormal_alert_ms = status.timestamp_ms
        return [recorded]

    def generate_summary_report(self, window_ms: int, persist: bool = True) -> SummaryReportResponse:
        now_ms = int(time.time() * 1000)
        insight = self._state.activity_insight(window_ms=window_ms, now_ms=now_ms)
        alert_counts = self._count_alerts(window_ms=window_ms, now_ms=now_ms)
        report = SummaryReportResponse(
            title="Activity Summary",
            window_ms=window_ms,
            generated_at_ms=now_ms,
            insight=ActivityInsightResponse(**insight),
            alert_counts=alert_counts,
        )

        if persist:
            report = self._state.record_report(report)
            self._store.insert_report(report.model_dump())

        return report

    def publish_alerts(self, alerts: Iterable[AlertEvent]) -> None:
        self._publish_alerts(alerts)

    def _publish_alerts(self, alerts: Iterable[AlertEvent]) -> None:
        for alert in alerts:
            self._store.insert_alert(alert.model_dump())

    def _count_alerts(self, window_ms: int, now_ms: int) -> dict[str, int]:
        counts: dict[str, int] = {}
        alerts = self._state.get_alerts(limit=settings.history_size)
        for alert in alerts:
            if alert.timestamp_ms < now_ms - window_ms:
                continue
            counts[alert.alert_type] = counts.get(alert.alert_type, 0) + 1
        return counts
