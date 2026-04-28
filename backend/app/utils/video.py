from typing import Optional

import cv2


def open_rtsp_stream(rtsp_url: str) -> Optional[cv2.VideoCapture]:
    if not rtsp_url:
        return None

    return cv2.VideoCapture(rtsp_url)
