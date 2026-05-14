from __future__ import annotations

from math import acos, degrees, hypot
from typing import Optional

from app.models.schemas import ActionSummaryRequest, ActionSummaryResponse, RealtimeStatus
from app.utils.action_analytics import durations_by_action


def _angle_at_vertex(
    ax: float,
    ay: float,
    bx: float,
    by: float,
    cx: float,
    cy: float,
) -> Optional[float]:
    """Angle ABC (degrees) at vertex B."""
    v1x, v1y = ax - bx, ay - by
    v2x, v2y = cx - bx, cy - by
    n1 = hypot(v1x, v1y)
    n2 = hypot(v2x, v2y)
    if n1 < 1e-6 or n2 < 1e-6:
        return None
    dot = (v1x * v2x + v1y * v2y) / (n1 * n2)
    dot = max(-1.0, min(1.0, dot))
    return degrees(acos(dot))


def _knee_angles_deg(landmarks: list[tuple[float, float, float]], min_conf: float) -> list[float]:
    """YOLO COCO-17: L hip 11, knee 13, ankle 15; R hip 12, knee 14, ankle 16."""
    out: list[float] = []
    if len(landmarks) < 17:
        return out
    pairs = ((11, 13, 15), (12, 14, 16))
    for hi, ki, ai in pairs:
        h, k, a = landmarks[hi], landmarks[ki], landmarks[ai]
        if h[2] < min_conf or k[2] < min_conf or a[2] < min_conf:
            continue
        ang = _angle_at_vertex(h[0], h[1], k[0], k[1], a[0], a[1])
        if ang is not None:
            out.append(ang)
    return out


def classify_action(
    pose: Optional[dict],
    prev_center: Optional[tuple[float, float]],
    motion_threshold: float = 0.026,
) -> tuple[str, float]:
    if pose is None:
        return "unknown", 0.0

    aspect_ratio = pose.get("aspect_ratio", 0.0)
    bbox_h = pose.get("bbox_h", 0.0)
    center = pose.get("center", (0.0, 0.0))
    landmarks = pose.get("landmarks", [])

    knee_angles = _knee_angles_deg(landmarks, 0.32)
    avg_knee = sum(knee_angles) / len(knee_angles) if knee_angles else None

    # Lying — wide bbox vs height (horizontal body)
    if aspect_ratio > 1.28:
        return "lying", 0.82
    if aspect_ratio > 1.08:
        return "lying", 0.68

    # Sitting / crouching — prefer knee flex over raw bbox height (fixes far-away = false sitting)
    if avg_knee is not None:
        if avg_knee < 118.0:
            if bbox_h < 0.54:
                return "sitting", 0.74
            if bbox_h < 0.65:
                return "crouching", 0.66
        # Far subject: small bbox but legs extended → not sitting
        if avg_knee > 142.0 and bbox_h < 0.34:
            pass  # fall through to motion / standing
        elif avg_knee > 135.0 and bbox_h < 0.30:
            pass
    else:
        # No reliable knees — conservative bbox sitting only when very squat
        if bbox_h < 0.26:
            return "sitting", 0.62
        if bbox_h < 0.32:
            return "sitting", 0.52

    # Crouching — medium height + knees moderately flexed
    if 0.38 <= bbox_h < 0.58 and avg_knee is not None and 105.0 <= avg_knee < 135.0:
        return "crouching", 0.64

    # Legacy crouch hint when knees unavailable (YOLO 11=L_hip, 13=L_knee)
    if avg_knee is None and 0.4 <= bbox_h < 0.55 and len(landmarks) >= 14:
        lh, lk = landmarks[11], landmarks[13]
        if lh[2] >= 0.25 and lk[2] >= 0.25 and abs(lk[1] - lh[1]) < 0.15:
            return "crouching", 0.62

    motion_distance = 0.0
    if prev_center:
        motion_distance = hypot(center[0] - prev_center[0], center[1] - prev_center[1])

    # Scale motion threshold by subject scale in frame (reduces jitter / false running)
    scale = max(0.5, min(1.15, bbox_h + 0.35))
    mt = motion_threshold * scale

    if motion_distance > mt * 4.2:
        return "running", 0.72
    if motion_distance > mt * 1.15:
        return "walking", 0.68
    if motion_distance > mt * 0.28:
        return "standing", 0.7

    return "standing", 0.62


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

    durations = durations_by_action(filtered)
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
