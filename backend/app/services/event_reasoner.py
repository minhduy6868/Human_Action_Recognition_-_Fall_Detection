from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

from app.core.config import get_settings
from app.core.state import RealtimeState
from app.models.schemas import AlertEvent, DetectedObject, RealtimeStatus
from app.utils.action_analytics import durations_by_action_with_total

settings = get_settings()


@dataclass
class ObjectTrack:
    track_id: str
    label: str
    first_seen_ms: int
    last_seen_ms: int
    last_center: tuple[float, float]
    last_bbox: tuple[float, float, float, float]
    stationary_ms: int = 0


class EventReasoner:
    def __init__(self, state: RealtimeState) -> None:
        self._state = state
        self._last_check_ms = 0
        self._object_tracks: dict[str, ObjectTrack] = {}
        self._last_alert_ms: dict[tuple[str, str], int] = {}
        self._crowd_since_ms: Optional[int] = None

    def observe(self, status: RealtimeStatus) -> list[AlertEvent]:
        if not settings.enable_event_reasoning:
            return []

        now_ms = status.timestamp_ms
        if now_ms - self._last_check_ms < settings.event_check_interval_ms:
            return []
        self._last_check_ms = now_ms

        alerts: list[AlertEvent] = []
        alerts.extend(self._detect_crowding(status))
        alerts.extend(self._detect_loitering(status))
        alerts.extend(self._detect_suspicious(status))
        alerts.extend(self._detect_abandoned(status))
        return alerts

    def _detect_crowding(self, status: RealtimeStatus) -> list[AlertEvent]:
        people = [
            obj
            for obj in status.objects
            if obj.class_id == 0 or obj.label == "person"
        ]
        if len(people) >= settings.crowd_min_people:
            if self._crowd_since_ms is None:
                self._crowd_since_ms = status.timestamp_ms
        else:
            self._crowd_since_ms = None

        if self._crowd_since_ms is None:
            return []

        if status.timestamp_ms - self._crowd_since_ms < settings.crowd_min_duration_ms:
            return []

        if not self._should_alert("crowding", "global", status.timestamp_ms, settings.crowd_suppression_ms):
            return []

        alert = AlertEvent(
            alert_type="crowding",
            severity="warning",
            title="Crowding detected",
            message=f"Detected {len(people)} people in view",
            timestamp_ms=status.timestamp_ms,
            track_id=status.track_id,
            action=status.action,
            confidence=1.0,
            metadata={"people": len(people), "threshold": settings.crowd_min_people},
        )
        return [self._state.record_alert(alert)]

    def _detect_loitering(self, status: RealtimeStatus) -> list[AlertEvent]:
        track_id = status.track_id
        if not track_id:
            return []

        items = self._history_for_track(track_id, settings.loitering_window_ms, status.timestamp_ms)
        total_ms, durations = durations_by_action_with_total(items)
        if total_ms < settings.loitering_window_ms:
            return []

        idle_ms = sum(
            durations.get(label, 0)
            for label in ("idle", "standing", "sitting")
        )
        idle_ratio = idle_ms / max(total_ms, 1)

        if idle_ratio < settings.loitering_min_idle_ratio:
            return []

        if not self._should_alert(
            "loitering",
            track_id,
            status.timestamp_ms,
            settings.loitering_suppression_ms,
        ):
            return []

        alert = AlertEvent(
            alert_type="loitering",
            severity="warning",
            title="Loitering detected",
            message=f"Track {track_id} idle ratio {idle_ratio:.2f}",
            timestamp_ms=status.timestamp_ms,
            track_id=track_id,
            action=status.action,
            confidence=min(1.0, round(idle_ratio, 3)),
            metadata={
                "window_ms": settings.loitering_window_ms,
                "idle_ratio": round(idle_ratio, 3),
                "durations_ms": durations,
            },
        )
        return [self._state.record_alert(alert)]

    def _detect_suspicious(self, status: RealtimeStatus) -> list[AlertEvent]:
        track_id = status.track_id
        if not track_id:
            return []

        items = self._history_for_track(track_id, settings.suspicious_window_ms, status.timestamp_ms)
        total_ms, _ = durations_by_action_with_total(items)
        if total_ms < settings.suspicious_window_ms:
            return []

        transitions = self._count_transitions(items)
        if transitions < settings.suspicious_transition_threshold:
            return []

        if not self._should_alert(
            "suspicious_movement",
            track_id,
            status.timestamp_ms,
            settings.suspicious_suppression_ms,
        ):
            return []

        alert = AlertEvent(
            alert_type="suspicious_movement",
            severity="warning",
            title="Suspicious movement",
            message=f"Track {track_id} transitions {transitions}",
            timestamp_ms=status.timestamp_ms,
            track_id=track_id,
            action=status.action,
            confidence=min(1.0, transitions / max(settings.suspicious_transition_threshold, 1)),
            metadata={
                "window_ms": settings.suspicious_window_ms,
                "transitions": transitions,
            },
        )
        return [self._state.record_alert(alert)]

    def _detect_abandoned(self, status: RealtimeStatus) -> list[AlertEvent]:
        now_ms = status.timestamp_ms
        people = [
            obj
            for obj in status.objects
            if obj.class_id == 0 or obj.label == "person"
        ]
        alerts: list[AlertEvent] = []

        for obj in status.objects:
            if obj.class_id == 0 or obj.label == "person":
                continue
            if not obj.track_id:
                continue

            center = self._center(obj)
            track = self._object_tracks.get(obj.track_id)
            if track is None:
                track = ObjectTrack(
                    track_id=obj.track_id,
                    label=obj.label,
                    first_seen_ms=now_ms,
                    last_seen_ms=now_ms,
                    last_center=center,
                    last_bbox=(obj.x1, obj.y1, obj.x2, obj.y2),
                    stationary_ms=0,
                )
                self._object_tracks[obj.track_id] = track
                continue

            delta_ms = max(now_ms - track.last_seen_ms, 1)
            move_threshold = settings.abandoned_object_move_ratio * max(
                obj.x2 - obj.x1,
                obj.y2 - obj.y1,
                1.0,
            )
            distance = self._distance(center, track.last_center)

            if distance <= move_threshold:
                track.stationary_ms += delta_ms
            else:
                track.stationary_ms = 0

            track.last_seen_ms = now_ms
            track.last_center = center
            track.last_bbox = (obj.x1, obj.y1, obj.x2, obj.y2)

        self._cleanup_tracks(now_ms)

        for track_id, track in self._object_tracks.items():
            if track.stationary_ms < settings.abandoned_object_stationary_ms:
                continue

            if self._person_nearby(track, people):
                continue

            if not self._should_alert(
                "abandoned_object",
                track_id,
                now_ms,
                settings.abandoned_suppression_ms,
            ):
                continue

            alert = AlertEvent(
                alert_type="abandoned_object",
                severity="warning",
                title="Abandoned object",
                message=f"Object {track.label} stationary for {track.stationary_ms} ms",
                timestamp_ms=now_ms,
                track_id=track_id,
                action=status.action,
                confidence=1.0,
                metadata={
                    "label": track.label,
                    "stationary_ms": track.stationary_ms,
                    "threshold_ms": settings.abandoned_object_stationary_ms,
                },
            )
            alerts.append(self._state.record_alert(alert))

        return alerts

    def _history_for_track(
        self,
        track_id: str,
        window_ms: int,
        now_ms: int,
    ) -> list[RealtimeStatus]:
        items = self._state.get_history(limit=settings.history_size)
        return [
            item
            for item in items
            if item.track_id == track_id and item.timestamp_ms >= now_ms - window_ms
        ]

    @staticmethod
    def _count_transitions(items: list[RealtimeStatus]) -> int:
        if len(items) < 2:
            return 0

        transitions = 0
        last_action = items[0].action
        for item in items[1:]:
            if item.action != last_action:
                transitions += 1
                last_action = item.action
        return transitions

    def _cleanup_tracks(self, now_ms: int) -> None:
        forget_before = now_ms - settings.abandoned_forget_ms
        stale_keys = [
            track_id
            for track_id, track in self._object_tracks.items()
            if track.last_seen_ms < forget_before
        ]
        for track_id in stale_keys:
            self._object_tracks.pop(track_id, None)

    @staticmethod
    def _center(obj: DetectedObject) -> tuple[float, float]:
        return ((obj.x1 + obj.x2) / 2.0, (obj.y1 + obj.y2) / 2.0)

    @staticmethod
    def _distance(a: tuple[float, float], b: tuple[float, float]) -> float:
        return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2) ** 0.5

    def _person_nearby(self, track: ObjectTrack, people: list[DetectedObject]) -> bool:
        if not people:
            return False

        obj_w = max(track.last_bbox[2] - track.last_bbox[0], 1.0)
        obj_h = max(track.last_bbox[3] - track.last_bbox[1], 1.0)
        threshold = settings.abandoned_person_distance_ratio * max(obj_w, obj_h)

        for person in people:
            distance = self._distance(self._center(person), track.last_center)
            if distance <= threshold:
                return True

        return False

    def _should_alert(self, alert_type: str, key: str, now_ms: int, suppression_ms: int) -> bool:
        last_key = (alert_type, key)
        last_ms = self._last_alert_ms.get(last_key, 0)
        if now_ms - last_ms < suppression_ms:
            return False
        self._last_alert_ms[last_key] = now_ms
        return True
