from __future__ import annotations

import logging
from typing import Optional

import cv2

from app.core.config import get_settings
from app.pipelines.pose_estimation import extract_pose_from_results

logger = logging.getLogger(__name__)
settings = get_settings()


def _clamp(value: int, low: int, high: int) -> int:
    return max(low, min(value, high))


def extract_keypoints_from_bbox(
    frame,
    pose_model,
    bbox: tuple[float, float, float, float],
    visibility_threshold: float | None = None,
) -> Optional[dict]:
    height, width = frame.shape[:2]
    x1, y1, x2, y2 = bbox

    x1_i = _clamp(int(x1), 0, width - 1)
    x2_i = _clamp(int(x2), 0, width - 1)
    y1_i = _clamp(int(y1), 0, height - 1)
    y2_i = _clamp(int(y2), 0, height - 1)

    if x2_i <= x1_i or y2_i <= y1_i:
        return None

    roi = frame[y1_i:y2_i, x1_i:x2_i]
    rgb = cv2.cvtColor(roi, cv2.COLOR_BGR2RGB)
    results = pose_model.predict(
        source=rgb,
        conf=settings.yolo_pose_confidence,
        iou=settings.yolo_pose_iou,
        verbose=False,
    )

    vis_threshold = (
        visibility_threshold
        if visibility_threshold is not None
        else settings.keypoint_visibility_threshold
    )

    pose = extract_pose_from_results(results, vis_threshold)
    if not pose:
        return None

    pose["roi_bbox"] = (x1_i, y1_i, x2_i, y2_i)
    return pose


def flatten_landmarks(landmarks: list[tuple[float, float, float]]) -> list[float]:
    flat: list[float] = []
    for x_val, y_val, vis_val in landmarks:
        flat.extend([x_val, y_val, vis_val])
    return flat
