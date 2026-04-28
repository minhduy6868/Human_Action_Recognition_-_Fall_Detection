from typing import Optional

import cv2


def estimate_pose(frame, pose_model) -> Optional[dict]:
    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    results = pose_model.process(rgb)
    if not results.pose_landmarks:
        return None

    xs: list[float] = []
    ys: list[float] = []
    landmarks: list[tuple[float, float, float]] = []

    for lm in results.pose_landmarks.landmark:
        landmarks.append((lm.x, lm.y, lm.visibility))
        if lm.visibility > 0.5:
            xs.append(lm.x)
            ys.append(lm.y)

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
