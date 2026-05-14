from __future__ import annotations

import logging
import time
from functools import lru_cache
from typing import Optional

import cv2
import numpy as np

from app.core.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


@lru_cache(maxsize=1)
def load_yolo_pose_model():
    # Import ultralytics before any log in older code hid 10-30s here (torch stack).
    logger.info("Importing ultralytics for pose (first time only; can take 10-30s)...")
    t_imp = time.perf_counter()
    try:
        from ultralytics import YOLO
    except ImportError as exc:  # pragma: no cover - runtime dependency
        raise RuntimeError("ultralytics is not installed") from exc
    logger.info("ultralytics import done in %.1fs", time.perf_counter() - t_imp)

    path = settings.yolo_pose_model_path
    logger.info("Loading YOLO pose weights: %s", path)
    t0 = time.perf_counter()
    model = YOLO(path)
    model.to(settings.ultralytics_device())
    logger.info(
        "YOLO pose weights ready in %.1fs (device=%s)",
        time.perf_counter() - t0,
        settings.model_device,
    )
    return model


def _iou_xyxy_pixel(
    a: tuple[float, float, float, float],
    b: tuple[float, float, float, float],
) -> float:
    ax1, ay1, ax2, ay2 = a
    bx1, by1, bx2, by2 = b
    ix1 = max(ax1, bx1)
    iy1 = max(ay1, by1)
    ix2 = min(ax2, bx2)
    iy2 = min(ay2, by2)
    iw = max(0.0, ix2 - ix1)
    ih = max(0.0, iy2 - iy1)
    inter = iw * ih
    if inter <= 0:
        return 0.0
    aa = max(0.0, ax2 - ax1) * max(0.0, ay2 - ay1)
    bb = max(0.0, bx2 - bx1) * max(0.0, by2 - by1)
    union = aa + bb - inter + 1e-6
    return float(inter / union)


def _pose_dict_from_norm_coords(
    coords: np.ndarray,
    confs: np.ndarray,
    visibility_threshold: float,
) -> Optional[dict]:
    """One person: coords (K,2) normalized xy, confs (K,) keypoint confidence."""
    landmarks: list[tuple[float, float, float]] = []
    xs: list[float] = []
    ys: list[float] = []

    for i in range(len(coords)):
        x_float = float(coords[i][0])
        y_float = float(coords[i][1])
        vis_float = float(confs[i]) if i < len(confs) else 1.0
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

    if xyn.ndim == 2:
        xyn = xyn[np.newaxis, ...]
    if xyn.ndim != 3:
        return None

    coords = xyn[0]
    if conf is None:
        confs = np.ones(len(coords), dtype=np.float32)
    else:
        c = np.asarray(conf)
        confs = c[0].astype(np.float32) if c.ndim > 1 else c.astype(np.float32)

    return _pose_dict_from_norm_coords(coords, confs, visibility_threshold)


def estimate_poses_matched_to_boxes(
    frame,
    pose_model,
    boxes_xyxy: list[tuple[float, float, float, float]],
    track_ids: list[str],
    visibility_threshold: float,
    min_iou: float = 0.15,
) -> dict[str, dict]:
    """
    Single full-frame pose inference, then match each pose skeleton bbox to a
    detection box by IoU (greedy, highest confidence order = caller order).
    """
    out: dict[str, dict] = {}
    if not boxes_xyxy or not track_ids or len(boxes_xyxy) != len(track_ids):
        return out

    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    results = pose_model.predict(
        source=rgb,
        conf=settings.yolo_pose_confidence,
        iou=settings.yolo_pose_iou,
        verbose=False,
    )
    if not results:
        return out

    result = results[0]
    keypoints = getattr(result, "keypoints", None)
    if keypoints is None or len(keypoints) == 0:
        return out

    xyn = getattr(keypoints, "xyn", None)
    conf = getattr(keypoints, "conf", None)
    if xyn is None:
        return out

    if hasattr(xyn, "cpu"):
        xyn = xyn.cpu().numpy()
    if conf is not None and hasattr(conf, "cpu"):
        conf = conf.cpu().numpy()

    if xyn.ndim == 2:
        xyn = xyn[np.newaxis, ...]
    if xyn.ndim != 3:
        return out

    height, width = frame.shape[:2]

    pose_entries: list[tuple[int, dict, tuple[float, float, float, float]]] = []
    n_pose = xyn.shape[0]
    for pi in range(n_pose):
        coords = xyn[pi]
        if conf is None:
            confs = np.ones(len(coords), dtype=np.float32)
        else:
            c = np.asarray(conf)
            if c.ndim > 1:
                confs = c[pi].astype(np.float32)
            elif n_pose == 1:
                confs = c.astype(np.float32)
            else:
                confs = np.ones(len(coords), dtype=np.float32)
        pose_d = _pose_dict_from_norm_coords(coords, confs, visibility_threshold)
        if not pose_d:
            continue
        x_min, y_min, x_max, y_max = pose_d["bbox"]
        pb = (
            x_min * width,
            y_min * height,
            x_max * width,
            y_max * height,
        )
        pose_entries.append((pi, pose_d, pb))

    used_pose: set[int] = set()
    for det_idx, tid in enumerate(track_ids):
        det_box = boxes_xyxy[det_idx]
        best_pi = -1
        best_iou = min_iou
        for pi, _pose_d, pb in pose_entries:
            if pi in used_pose:
                continue
            iou = _iou_xyxy_pixel(det_box, pb)
            if iou > best_iou:
                best_iou = iou
                best_pi = pi
        if best_pi >= 0:
            used_pose.add(best_pi)
            for pi, pose_d, _pb in pose_entries:
                if pi == best_pi:
                    out[tid] = pose_d
                    break

    return out


def estimate_pose(frame, pose_model) -> Optional[dict]:
    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    results = pose_model.predict(
        source=rgb,
        conf=settings.yolo_pose_confidence,
        iou=settings.yolo_pose_iou,
        verbose=False,
    )
    return extract_pose_from_results(results, settings.keypoint_visibility_threshold)
