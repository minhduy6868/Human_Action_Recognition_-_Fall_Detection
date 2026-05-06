from __future__ import annotations

import logging
from typing import Optional

import cv2

from app.core.config import get_settings

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
    results = pose_model.process(rgb)
    if not results.pose_landmarks:
        return None

    vis_threshold = (
        visibility_threshold
        if visibility_threshold is not None
        else settings.keypoint_visibility_threshold
    )

    landmarks: list[tuple[float, float, float]] = []
    xs: list[float] = []
    ys: list[float] = []

    for lm in results.pose_landmarks.landmark:
        x_val = float(lm.x)
        y_val = float(lm.y)
        vis_val = float(lm.visibility)
        landmarks.append((x_val, y_val, vis_val))
        if vis_val >= vis_threshold:
            xs.append(x_val)
            ys.append(y_val)

    if not xs or not ys:
        return None

    x_min, x_max = min(xs), max(xs)
    y_min, y_max = min(ys), max(ys)
    bbox_w = x_max - x_min
    bbox_h = y_max - y_min
    center_x = x_min + bbox_w / 2.0
    center_y = y_min + bbox_h / 2.0
    aspect_ratio = bbox_w / (bbox_h + 1e-6)

    return {
        "landmarks": landmarks,
        "bbox": (x_min, y_min, x_max, y_max),
        "bbox_w": bbox_w,
        "bbox_h": bbox_h,
        "center": (center_x, center_y),
        "aspect_ratio": aspect_ratio,
        "roi_bbox": (x1_i, y1_i, x2_i, y2_i),
    }


def flatten_landmarks(landmarks: list[tuple[float, float, float]]) -> list[float]:
    flat: list[float] = []
    for x_val, y_val, vis_val in landmarks:
        flat.extend([x_val, y_val, vis_val])
    return flat
