import threading
import time
from collections import deque
from typing import Optional

import cv2

from app.core.config import get_settings
from app.core.state import RealtimeState
from app.models.schemas import RealtimeStatus
from app.pipelines.action_summary import classify_action
from app.pipelines.fall_detection import FallDetector
from app.pipelines.pose_estimation import estimate_pose

settings = get_settings()
state = RealtimeState(history_size=settings.history_size)


class StreamService:
    def __init__(self) -> None:
        self._thread: Optional[threading.Thread] = None
        self._running = False
        self._fall_detector = FallDetector()
        self._action_buffer: deque[tuple[int, str]] = deque(maxlen=60)
        self._prev_center: Optional[tuple[float, float]] = None

    def start(self) -> None:
        if self._running:
            return
        if not settings.enable_stream:
            return

        self._running = True
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._running = False
        if self._thread:
            self._thread.join(timeout=2)

    def _open_capture(self) -> Optional[cv2.VideoCapture]:
        if settings.camera_source.lower() == "webcam":
            return cv2.VideoCapture(settings.webcam_index)
        if settings.rtsp_url:
            return cv2.VideoCapture(settings.rtsp_url)
        return None

    def _run(self) -> None:
        try:
            import mediapipe as mp
        except ImportError:
            self._running = False
            return

        cap = self._open_capture()
        if cap is None or not cap.isOpened():
            self._running = False
            return

        pose_model = mp.solutions.pose.Pose(
            model_complexity=1,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5,
        )

        frame_index = 0
        while self._running:
            ret, frame = cap.read()
            if not ret:
                time.sleep(0.05)
                continue

            frame_index += 1
            if settings.frame_skip > 0 and frame_index % (settings.frame_skip + 1) != 0:
                continue

            pose = estimate_pose(frame, pose_model)
            ts_ms = int(time.time() * 1000)
            action, confidence = classify_action(pose, self._prev_center)

            if pose and "center" in pose:
                self._prev_center = pose["center"]

            fall, fall_conf = self._fall_detector.update(pose, action, ts_ms)

            status = RealtimeStatus(
                action=action,
                confidence=confidence,
                fall=fall,
                timestamp_ms=ts_ms,
                track_id="0",
            )

            state.update(status)
            self._action_buffer.append((ts_ms, action))

        cap.release()
        pose_model.close()
        self._running = False


stream_service = StreamService()
