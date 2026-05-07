from __future__ import annotations

from functools import lru_cache
from typing import Optional

import cv2

from app.core.config import get_settings

settings = get_settings()


@lru_cache(maxsize=1)
def load_yolo_pose_model():
    try:
        from ultralytics import YOLO
    except ImportError as exc:  # pragma: no cover - runtime dependency
        raise RuntimeError("ultralytics is not installed") from exc

    return YOLO(settings.yolo_pose_model_path)


def extract_pose_from_results(
    results,
    visibility_threshold: float,
) -> Optional[dict]:
    if not results:
        return None

    result = results[0]
    keypoints = getattr(result, "keypoints", None)
    if keypoints is None or len(keypoints) == 0:
        return None

    xyn = getattr(keypoints, "xyn", None)
    conf = getattr(keypoints, "conf", None)
    if xyn is None:
        return None

    if hasattr(xyn, "cpu"):
        xyn = xyn.cpu().numpy()
    if conf is not None and hasattr(conf, "cpu"):
        conf = conf.cpu().numpy()

    if xyn.ndim != 3:
        return None

    coords = xyn[0]
    confs = conf[0] if conf is not None else [1.0] * len(coords)

    xs: list[float] = []
    ys: list[float] = []
    landmarks: list[tuple[float, float, float]] = []

    for (x_val, y_val), vis_val in zip(coords, confs):
        x_float = float(x_val)
        y_float = float(y_val)
        vis_float = float(vis_val)
        landmarks.append((x_float, y_float, vis_float))
        if vis_float >= visibility_threshold:
            xs.append(x_float)
            ys.append(y_float)

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
    }


def estimate_pose(frame, pose_model) -> Optional[dict]:
    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    results = pose_model.predict(
        source=rgb,
        conf=settings.yolo_pose_confidence,
        iou=settings.yolo_pose_iou,
        verbose=False,
    )
    return extract_pose_from_results(results, settings.keypoint_visibility_threshold)
