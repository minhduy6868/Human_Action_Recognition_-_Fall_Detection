from math import hypot
from typing import Optional

from app.models.schemas import ActionSummaryRequest, ActionSummaryResponse, RealtimeStatus


def classify_action(
    pose: Optional[dict],
    prev_center: Optional[tuple[float, float]],
    motion_threshold: float = 0.02,
) -> tuple[str, float]:
    if pose is None:
        return "unknown", 0.0

    aspect_ratio = pose.get("aspect_ratio", 0.0)
    bbox_h = pose.get("bbox_h", 0.0)
    center = pose.get("center", (0.0, 0.0))

    if aspect_ratio > 1.2:
        return "lying", 0.7

    if bbox_h < 0.35:
        return "sitting", 0.6

    if prev_center:
        distance = hypot(center[0] - prev_center[0], center[1] - prev_center[1])
        if distance > motion_threshold:
            return "walking", 0.6

    return "standing", 0.6


def run_action_summary(payload: ActionSummaryRequest) -> ActionSummaryResponse:
    return ActionSummaryResponse(
        track_id=payload.track_id,
        window_ms=payload.window_ms,
        labels=["idle"],
        confidence=0.0,
    )


def summarize_history(
    items: list[RealtimeStatus],
    track_id: str,
    window_ms: int,
    now_ms: int,
) -> ActionSummaryResponse:
    filtered = [
        item
        for item in items
        if item.track_id == track_id and item.timestamp_ms >= now_ms - window_ms
    ]
    if not filtered:
        return ActionSummaryResponse(
            track_id=track_id,
            window_ms=window_ms,
            labels=["idle"],
            confidence=0.0,
        )

    durations = _durations_by_action(filtered)
    total = sum(durations.values())
    ordered = sorted(durations.items(), key=lambda pair: pair[1], reverse=True)
    labels = [label for label, _ in ordered]
    confidence = (ordered[0][1] / total) if total > 0 else 0.0

    return ActionSummaryResponse(
        track_id=track_id,
        window_ms=window_ms,
        labels=labels,
        confidence=round(confidence, 4),
    )


def _durations_by_action(items: list[RealtimeStatus]) -> dict[str, int]:
    if not items:
        return {}

    durations: dict[str, int] = {}
    if len(items) == 1:
        durations[items[0].action] = 1
        return durations

    diffs = [
        max(items[i + 1].timestamp_ms - items[i].timestamp_ms, 1)
        for i in range(len(items) - 1)
    ]
    median_diff = sorted(diffs)[len(diffs) // 2]

    for idx, item in enumerate(items):
        if idx < len(items) - 1:
            delta = max(items[idx + 1].timestamp_ms - item.timestamp_ms, 1)
        else:
            delta = max(median_diff, 1)
        durations[item.action] = durations.get(item.action, 0) + delta

    return durations
