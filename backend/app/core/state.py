from datetime import datetime
from threading import Lock

from app.models.schemas import (
    ActionSegment,
    AlertEvent,
    FallEvent,
    RealtimeStatus,
    SummaryReportResponse,
)
from app.utils.action_analytics import durations_by_action


class RealtimeState:
    def __init__(self, history_size: int = 200) -> None:
        self._lock = Lock()
        self._history_size = history_size
        self._latest = RealtimeStatus()
        self._history: list[RealtimeStatus] = []
        self._fall_events: list[FallEvent] = []
        self._alerts: list[AlertEvent] = []
        self._reports: list[SummaryReportResponse] = []
        self._next_fall_event_id = 1
        self._next_alert_id = 1
        self._next_report_id = 1
        self._prev_fall = False

    def update(self, status: RealtimeStatus) -> list[AlertEvent]:
        created_alerts: list[AlertEvent] = []
        with self._lock:
            self._latest = status
            self._history.append(status)
            if len(self._history) > self._history_size:
                self._history = self._history[-self._history_size :]

            if status.fall and not self._prev_fall:
                self._fall_events.append(
                    FallEvent(
                        detected=True,
                        confidence=status.fall_confidence,
                        timestamp_ms=status.timestamp_ms,
                        action=status.action,
                        event_id=self._next_fall_event_id,
                    )
                )
                self._next_fall_event_id += 1

                created_alert = AlertEvent(
                    alert_id=self._next_alert_id,
                    alert_type="fall",
                    severity="critical",
                    title="Fall detected",
                    message="Immediate fall alert from realtime pipeline",
                    timestamp_ms=status.timestamp_ms,
                    track_id=status.track_id,
                    action=status.action,
                    confidence=status.fall_confidence,
                    metadata={"detected": True},
                )
                self._alerts.append(created_alert)
                created_alerts.append(created_alert)
                self._next_alert_id += 1

            self._prev_fall = status.fall

            if len(self._fall_events) > self._history_size:
                self._fall_events = self._fall_events[-self._history_size :]

            if len(self._alerts) > self._history_size:
                self._alerts = self._alerts[-self._history_size :]

        return created_alerts

    def record_alert(self, alert: AlertEvent) -> AlertEvent:
        with self._lock:
            if alert.alert_id <= 0:
                alert = alert.model_copy(update={"alert_id": self._next_alert_id})
                self._next_alert_id += 1
            self._alerts.append(alert)
            if len(self._alerts) > self._history_size:
                self._alerts = self._alerts[-self._history_size :]
            return alert

    def record_report(self, report: SummaryReportResponse) -> SummaryReportResponse:
        with self._lock:
            if report.report_id <= 0:
                report = report.model_copy(update={"report_id": self._next_report_id})
                self._next_report_id += 1
            self._reports.append(report)
            if len(self._reports) > self._history_size:
                self._reports = self._reports[-self._history_size :]
            return report

    def get_latest(self) -> RealtimeStatus:
        with self._lock:
            return self._latest

    def get_history(self, limit: int) -> list[RealtimeStatus]:
        with self._lock:
            return list(self._history[-limit:])

    def get_fall_events(self, limit: int = 100) -> list[FallEvent]:
        with self._lock:
            return list(self._fall_events[-limit:])

    def get_fall_events_after(self, event_id: int) -> list[FallEvent]:
        with self._lock:
            return [event for event in self._fall_events if event.event_id > event_id]

    def get_alerts(self, limit: int = 100) -> list[AlertEvent]:
        with self._lock:
            return list(self._alerts[-limit:])

    def get_alerts_after(self, alert_id: int) -> list[AlertEvent]:
        with self._lock:
            return [alert for alert in self._alerts if alert.alert_id > alert_id]

    def get_reports(self, limit: int = 100) -> list[SummaryReportResponse]:
        with self._lock:
            return list(self._reports[-limit:])

    def summarize_actions(self, window_ms: int, now_ms: int) -> list[ActionSegment]:
        with self._lock:
            items = [
                item for item in self._history if item.timestamp_ms >= now_ms - window_ms
            ]

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

    def activity_insight(self, window_ms: int, now_ms: int) -> dict:
        with self._lock:
            items = [
                item for item in self._history if item.timestamp_ms >= now_ms - window_ms
            ]
            falls = [
                event
                for event in self._fall_events
                if event.timestamp_ms >= now_ms - window_ms
            ]

        segments = self.summarize_actions(window_ms=window_ms, now_ms=now_ms)
        durations = durations_by_action(items)
        total_duration = sum(durations.values())
        people_counts = [len(item.people) for item in items]
        object_counts = [len(item.objects) for item in items]
        top_object_labels: dict[str, int] = {}
        for item in items:
            for detected_object in item.objects:
                label = (detected_object.label or "unknown").strip() or "unknown"
                top_object_labels[label] = top_object_labels.get(label, 0) + 1

        dominant_action = "unknown"
        dominant_ratio = 0.0
        if durations and total_duration > 0:
            dominant_action = max(durations, key=durations.get)
            dominant_ratio = durations[dominant_action] / total_duration

        from app.models.schemas import NotableMoment

        notable_moments: list[NotableMoment] = []
        for item in items[-40:]:
            people = item.people or []
            if people:
                for person in people:
                    action = (person.action or "unknown").strip().lower()
                    if action in {"unknown", "idle", "none", ""}:
                        continue
                    upper = (person.clothing.upper or "unknown").strip().lower()
                    dt = datetime.fromtimestamp(item.timestamp_ms / 1000.0)
                    notable_moments.append(
                        NotableMoment(
                            timestamp_ms=item.timestamp_ms,
                            time_label=dt.strftime("%H:%M"),
                            action=action,
                            upper_color=upper,
                            track_id=person.track_id or item.track_id,
                        )
                    )
            else:
                action = (item.action or "unknown").strip().lower()
                if action not in {"unknown", "idle", "none", ""}:
                    dt = datetime.fromtimestamp(item.timestamp_ms / 1000.0)
                    notable_moments.append(
                        NotableMoment(
                            timestamp_ms=item.timestamp_ms,
                            time_label=dt.strftime("%H:%M"),
                            action=action,
                            upper_color="unknown",
                            track_id=item.track_id,
                        )
                    )

        return {
            "window_ms": window_ms,
            "total_samples": len(items),
            "dominant_action": dominant_action,
            "dominant_action_ratio": round(dominant_ratio, 4),
            "action_durations_ms": durations,
            "segments": segments,
            "fall_detected": len(falls) > 0,
            "fall_events": falls,
            "max_people_count": max(people_counts, default=0),
            "avg_people_count": round(sum(people_counts) / len(people_counts), 2) if people_counts else 0.0,
            "max_objects_count": max(object_counts, default=0),
            "avg_objects_count": round(sum(object_counts) / len(object_counts), 2) if object_counts else 0.0,
            "multi_person_frames": sum(1 for count in people_counts if count > 1),
            "top_object_labels": dict(sorted(top_object_labels.items(), key=lambda item: item[1], reverse=True)[:8]),
            "notable_moments": notable_moments[-12:],
        }
