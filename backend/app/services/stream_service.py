import logging
import platform
import threading
import time
from collections import deque
from typing import Optional

import cv2

from app.core.config import get_settings
from app.core.state import RealtimeState
from app.models.schemas import RealtimeStatus
from app.services.alert_engine import AlertEngine
from app.services.event_reasoner import EventReasoner
from app.pipelines.action_summary import classify_action
from app.pipelines.action_smoothing import smooth_action
from app.pipelines.action_model import ActionModel
from app.pipelines.fall_detection import FallDetector
from app.pipelines.fall_model import FallModel, extract_fall_features
from app.pipelines.object_detection import track_objects
from app.pipelines.keypoints import extract_keypoints_from_bbox, flatten_landmarks
from app.pipelines.pose_estimation import estimate_pose, load_yolo_pose_model
from app.utils.video import draw_detections

logger = logging.getLogger(__name__)
settings = get_settings()
state = RealtimeState(history_size=settings.history_size)
alert_engine = AlertEngine(state)


class StreamService:
    def __init__(self) -> None:
        self._thread: Optional[threading.Thread] = None
        self._running = False
        self._fall_detector = FallDetector(
            drop_threshold=settings.fall_drop_threshold,
            aspect_threshold=settings.fall_aspect_threshold,
            velocity_threshold=settings.fall_velocity_threshold,
            confirm_ms=settings.fall_confirm_ms,
            candidate_window_ms=settings.fall_candidate_window_ms,
        )
        self._prev_center: Optional[tuple[float, float]] = None
        self._sequence_buffers: dict[str, deque[list[float]]] = {}
        self._action_history: dict[str, deque[tuple[str, float]]] = {}
        self._action_model: Optional[ActionModel] = None
        self._fall_model: Optional[FallModel] = None
        self._event_reasoner = EventReasoner(state)
        self._action_input_size = settings.action_model_input_size
        self._frame_lock = threading.Lock()
        self._latest_frame: Optional[bytes] = None
        self._latest_frame_ts_ms = 0
        self._dynamic_skip = max(0, settings.frame_skip)

    def start(self) -> None:
        if self._running:
            return
        if not settings.enable_stream:
            logger.info("Stream disabled, skipping start")
            return

        logger.info(f"Starting stream service: camera_source={settings.camera_source}")
        self._running = True
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._running = False
        if self._thread:
            self._thread.join(timeout=2)

    def _open_capture(self) -> Optional[cv2.VideoCapture]:
        source = settings.camera_source.lower()
        if source == "webcam":
            logger.info(f"Opening webcam at index {settings.webcam_index}")
            if platform.system() == "Windows":
                cap = cv2.VideoCapture(settings.webcam_index, cv2.CAP_DSHOW)
                if cap.isOpened():
                    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
                    return cap
                logger.warning("DirectShow backend failed, falling back to default webcam backend")

            cap = cv2.VideoCapture(settings.webcam_index)
            if cap.isOpened():
                cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
            return cap
        if source == "file":
            if not settings.video_file_path:
                logger.error("video_file_path is empty")
                return None
            logger.info(f"Opening video file: {settings.video_file_path}")
            cap = cv2.VideoCapture(settings.video_file_path)
            if not cap.isOpened():
                logger.error(f"Failed to open video file: {settings.video_file_path}")
            return cap
        if source == "rtsp" and settings.rtsp_url:
            logger.info(f"Opening RTSP stream: {settings.rtsp_url}")
            cap = cv2.VideoCapture(settings.rtsp_url)
            if cap.isOpened():
                cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
            return cap
        logger.warning(f"Unknown camera source: {source}")
        return None

    def _run(self) -> None:
        if settings.demo_mode:
            logger.info("Running in DEMO mode")
            self._run_demo()
            return

        cap = self._open_capture()
        if cap is None or not cap.isOpened():
            logger.error("Failed to open video capture")
            self._running = False
            return

        logger.info("Video capture opened successfully, starting pose estimation")

        try:
            pose_model = load_yolo_pose_model()
        except RuntimeError:
            logger.exception("YOLO Pose model failed to load")
            self._running = False
            return

        frame_index = 0
        while self._running:
            loop_started = time.perf_counter()
            ret, frame = cap.read()
            if not ret:
                if (
                    settings.camera_source.lower() == "file"
                    and settings.loop_video_file
                ):
                    cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                    continue
                break

            frame_index += 1
            skip = self._dynamic_skip if settings.adaptive_frame_skip else settings.frame_skip
            if skip > 0 and frame_index % (skip + 1) != 0:
                continue

            try:
                objects = track_objects(frame)
            except Exception:
                logger.exception("YOLOv11 tracking failed for current frame")
                objects = []

            person_detections = [
                det for det in objects if det.class_id == 0 or det.label == "person"
            ]
            person_detections.sort(key=lambda det: det.confidence, reverse=True)

            primary_pose = None
            primary_track_id = "0"
            primary_sequence: list[list[float]] = []

            for det in person_detections:
                pose = extract_keypoints_from_bbox(
                    frame,
                    pose_model,
                    (det.x1, det.y1, det.x2, det.y2),
                )
                if not pose:
                    continue

                track_id = det.track_id or "0"
                sequence = self._sequence_buffers.setdefault(
                    track_id, deque(maxlen=settings.action_window_frames)
                )
                sequence.append(self._fit_landmarks(flatten_landmarks(pose["landmarks"])))

                if primary_pose is None:
                    primary_pose = pose
                    primary_track_id = track_id
                    primary_sequence = list(sequence)

            if primary_pose is None:
                primary_pose = estimate_pose(frame, pose_model)
                primary_track_id = "0"
                if primary_pose is not None:
                    sequence = self._sequence_buffers.setdefault(
                        primary_track_id,
                        deque(maxlen=settings.action_window_frames),
                    )
                    sequence.append(
                        self._fit_landmarks(flatten_landmarks(primary_pose["landmarks"]))
                    )
                    primary_sequence = list(sequence)

            ts_ms = int(time.time() * 1000)

            action, confidence = "unknown", 0.0
            if (
                settings.use_ml_action
                and primary_sequence
                and len(primary_sequence) >= settings.action_window_frames
                and frame_index % settings.action_stride_frames == 0
            ):
                if self._action_model is None:
                    self._action_model = ActionModel.load(
                        settings.action_model_path,
                        device=settings.model_device,
                    )
                    self._action_input_size = self._action_model.input_size
                action, confidence = self._action_model.predict(primary_sequence)
            elif primary_pose is not None:
                action, confidence = classify_action(primary_pose, self._prev_center)

            if settings.action_smooth_window > 0:
                history = self._action_history.setdefault(
                    primary_track_id,
                    deque(maxlen=settings.action_smooth_window),
                )
                history.append((action, confidence))
                action, confidence = smooth_action(history, settings.action_min_confidence)

            if primary_pose and "center" in primary_pose:
                self._prev_center = primary_pose["center"]

            fall, fall_conf = False, 0.0
            if (
                settings.use_ml_fall
                and primary_sequence
                and len(primary_sequence) >= settings.action_window_frames
            ):
                if self._fall_model is None:
                    self._fall_model = FallModel.load(settings.fall_model_path)
                features = extract_fall_features(primary_sequence)
                fall_conf = self._fall_model.predict(features)
                fall = fall_conf >= 0.5
            else:
                fall, fall_conf = self._fall_detector.update(primary_pose, action, ts_ms)

            status = RealtimeStatus(
                action=action,
                confidence=confidence,
                fall=fall,
                fall_confidence=fall_conf,
                timestamp_ms=ts_ms,
                track_id=primary_track_id,
                objects=objects,
            )

            self._update_latest_frame(frame, objects, action, fall, ts_ms)

            created_alerts = state.update(status)
            if created_alerts:
                alert_engine.publish_alerts(created_alerts)
            alert_engine.observe(status)

            event_alerts = self._event_reasoner.observe(status)
            if event_alerts:
                alert_engine.publish_alerts(event_alerts)

            if settings.adaptive_frame_skip and settings.target_fps > 0:
                elapsed_ms = (time.perf_counter() - loop_started) * 1000.0
                target_ms = 1000.0 / float(settings.target_fps)
                if elapsed_ms > target_ms and self._dynamic_skip < settings.max_frame_skip:
                    self._dynamic_skip += 1
                elif elapsed_ms < target_ms * 0.7 and self._dynamic_skip > 0:
                    self._dynamic_skip -= 1

        cap.release()
        self._running = False

    def _fit_landmarks(self, flat: list[float]) -> list[float]:
        target = self._action_input_size
        if target <= 0:
            return flat
        if len(flat) > target:
            return flat[:target]
        if len(flat) < target:
            return flat + [0.0] * (target - len(flat))
        return flat

    def _run_demo(self) -> None:
        actions = ["standing", "walking", "sitting", "lying"]
        index = 0
        while self._running:
            ts_ms = int(time.time() * 1000)
            action = actions[index % len(actions)]
            fall = action == "lying" and index % 5 == 0
            status = RealtimeStatus(
                action=action,
                confidence=0.75,
                fall=fall,
                fall_confidence=0.95 if fall else 0.0,
                timestamp_ms=ts_ms,
                track_id="demo",
                objects=[],
            )
            created_alerts = state.update(status)
            if created_alerts:
                alert_engine.publish_alerts(created_alerts)
            alert_engine.observe(status)
            index += 1
            time.sleep(settings.demo_interval_ms / 1000)

    def get_latest_frame(self) -> Optional[bytes]:
        with self._frame_lock:
            return self._latest_frame

    def _update_latest_frame(
        self,
        frame,
        objects,
        action: str,
        fall: bool,
        ts_ms: int,
    ) -> None:
        if settings.mjpeg_fps <= 0:
            return

        min_interval_ms = int(1000 / settings.mjpeg_fps)
        if ts_ms - self._latest_frame_ts_ms < min_interval_ms:
            return

        annotated = draw_detections(frame, objects, action, fall)
        encode_params = [int(cv2.IMWRITE_JPEG_QUALITY), settings.mjpeg_quality]
        ok, buffer = cv2.imencode(".jpg", annotated, encode_params)
        if not ok:
            return

        with self._frame_lock:
            self._latest_frame = buffer.tobytes()
            self._latest_frame_ts_ms = ts_ms


stream_service = StreamService()
