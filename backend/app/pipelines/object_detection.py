from __future__ import annotations

import logging
import time
from functools import lru_cache

from app.core.config import get_settings
from app.models.schemas import DetectedObject

logger = logging.getLogger(__name__)
settings = get_settings()


def _parse_class_filter(raw_value: str) -> list[int] | None:
    if not raw_value.strip():
        return None

    class_ids: list[int] = []
    for chunk in raw_value.split(","):
        chunk = chunk.strip()
        if not chunk:
            continue
        try:
            class_ids.append(int(chunk))
        except ValueError:
            logger.warning("Skipping invalid YOLO class id: %s", chunk)

    return class_ids or None


@lru_cache(maxsize=1)
def load_yolo_model():
    logger.info("Importing ultralytics for detection (skipped if already imported)...")
    t_imp = time.perf_counter()
    try:
        from ultralytics import YOLO
    except ImportError as exc:  # pragma: no cover - import guard
        raise RuntimeError("ultralytics is not installed") from exc
    logger.info("ultralytics import done in %.1fs", time.perf_counter() - t_imp)

    path = settings.yolo_model_path
    logger.info("Loading YOLO detection/tracking weights: %s", path)
    t0 = time.perf_counter()
    model = YOLO(path)
    model.to(settings.ultralytics_device())
    logger.info(
        "YOLO detection/tracking weights ready in %.1fs (device=%s)",
        time.perf_counter() - t0,
        settings.model_device,
    )
    return model


def track_objects(frame) -> list[DetectedObject]:
    model = load_yolo_model()
    class_filter = _parse_class_filter(settings.yolo_classes)

    results = model.track(
        source=frame,
        conf=settings.yolo_confidence,
        iou=settings.yolo_iou,
        imgsz=settings.yolo_imgsz,
        max_det=settings.yolo_max_det,
        classes=class_filter,
        tracker=settings.yolo_tracker,
        persist=True,
        verbose=False,
    )

    if not results:
        return []

    result = results[0]
    boxes = getattr(result, "boxes", None)
    if boxes is None:
        return []

    names = getattr(result, "names", {})
    detections: list[DetectedObject] = []

    for box in boxes:
        cls_id = int(box.cls.item()) if hasattr(box.cls, "item") else int(box.cls)
        label = names.get(cls_id, str(cls_id))
        confidence = float(box.conf.item()) if hasattr(box.conf, "item") else float(box.conf)
        x1, y1, x2, y2 = [float(value) for value in box.xyxy[0].tolist()]
        track_id = ""
        if getattr(box, "id", None) is not None:
            track_value = box.id.item() if hasattr(box.id, "item") else box.id
            track_id = str(int(track_value))

        is_person = cls_id == 0 or label.lower() == "person"

        detections.append(
            DetectedObject(
                class_id=cls_id,
                label=label,
                confidence=confidence,
                x1=x1,
                y1=y1,
                x2=x2,
                y2=y2,
                track_id=track_id,
                is_person=is_person,
            )
        )

    return detections