from math import hypot
from typing import Optional

from app.models.schemas import ActionSummaryRequest, ActionSummaryResponse


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
