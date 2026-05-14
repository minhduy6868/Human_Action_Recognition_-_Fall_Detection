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
        cv2.putText(
            annotated,
            label,
            (x1, max(10, y1 - 6)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.5,
            color,
            1,
            cv2.LINE_AA,
        )

    status_text = f"action={action} fall={fall}"
    cv2.putText(
        annotated,
        status_text,
        (10, 20),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.6,
        (255, 255, 255),
        2,
        cv2.LINE_AA,
    )
    return annotated
