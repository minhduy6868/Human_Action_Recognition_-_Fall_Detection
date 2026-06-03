from typing import Optional

import platform

import cv2

from app.models.schemas import DetectedObject


def open_rtsp_stream(rtsp_url: str) -> Optional[cv2.VideoCapture]:
    if not rtsp_url:
        return None

    return cv2.VideoCapture(rtsp_url)


def list_webcams(max_devices: int) -> list[dict[str, int]]:
    cameras: list[dict[str, int]] = []
    for index in range(max(0, max_devices)):
        if platform.system() == "Windows":
            cap = cv2.VideoCapture(index, cv2.CAP_DSHOW)
        else:
            cap = cv2.VideoCapture(index)

        if cap.isOpened():
            cameras.append({"index": index})
        cap.release()

    return cameras


def _draw_label_box(
    frame,
    text: str,
    x: int,
    y: int,
    *,
    font_scale: float = 0.52,
) -> None:
    """Draw label with white text on a dark background for readability."""
    font = cv2.FONT_HERSHEY_SIMPLEX
    thickness = 1
    (text_w, text_h), baseline = cv2.getTextSize(text, font, font_scale, thickness)
    pad_x, pad_y = 4, 3
    top = max(0, y - text_h - baseline - pad_y * 2)
    left = max(0, x)
    cv2.rectangle(
        frame,
        (left, top),
        (left + text_w + pad_x * 2, top + text_h + baseline + pad_y * 2),
        (0, 0, 0),
        -1,
    )
    cv2.putText(
        frame,
        text,
        (left + pad_x, top + text_h + pad_y),
        font,
        font_scale,
        (255, 255, 255),
        thickness,
        cv2.LINE_AA,
    )


def draw_detections(
    frame,
    objects: list[DetectedObject],
    action: str,
    fall: bool,
) -> object:
    annotated = frame.copy()
    for det in objects:
        x1, y1, x2, y2 = int(det.x1), int(det.y1), int(det.x2), int(det.y2)
        color = (0, 200, 0) if det.label == "person" else (0, 128, 255)
        cv2.rectangle(annotated, (x1, y1), (x2, y2), color, 2)
        label = f"{det.label} {det.confidence:.2f}"
        _draw_label_box(annotated, label, x1, max(12, y1 - 4))

    status_text = f"action={action} fall={fall}"
    _draw_label_box(annotated, status_text, 8, 28, font_scale=0.58)
    return annotated
