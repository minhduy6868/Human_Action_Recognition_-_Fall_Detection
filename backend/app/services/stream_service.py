import logging
import platform
import threading
import time
from collections import deque
from typing import Optional

import cv2

from app.core.config import get_settings
from app.core.state import RealtimeState
from app.models.schemas import PersonAction, PersonClothing, RealtimeStatus
from app.services.alert_engine import AlertEngine
from app.services.detection_log_store import DetectionLogStore
from app.services.event_reasoner import EventReasoner
from app.services.notification_service import NotificationService
from app.pipelines.action_summary import classify_action
from app.pipelines.action_smoothing import smooth_action
from app.pipelines.action_model import ActionModel
from app.pipelines.fall_detection import FallDetector
from app.pipelines.fall_model import FallModel, extract_fall_features
from app.pipelines.clothing_color import get_clothing_detector
from app.pipelines.object_detection import track_objects
from app.pipelines.person_identification import get_person_identifier
from app.pipelines.keypoints import extract_keypoints_from_bbox, flatten_landmarks
from app.pipelines.pose_estimation import (
    estimate_pose,
    estimate_poses_matched_to_boxes,
    load_yolo_pose_model,
)
from app.utils.video import draw_detections

logger = logging.getLogger(__name__)

class StreamService:
    def __init__(
        self,
        settings,
        state: RealtimeState,
        alert_engine: AlertEngine,
        notification_service: NotificationService,
        source_id: str | None = None,
        user_id: str | None = None,
    ) -> None:
        self._settings = settings
        self._state = state
        self._alert_engine = alert_engine
        self._notification_service = notification_service
        self._source_id = source_id
        self._user_id = user_id
        self._thread: Optional[threading.Thread] = None
        self._running = False
        self._fall_detectors: dict[str, FallDetector] = {}
        self._prev_center_by_track: dict[str, tuple[float, float]] = {}
        self._track_last_seen: dict[str, int] = {}
        self._sequence_buffers: dict[str, deque[list[float]]] = {}
        self._action_history: dict[str, deque[tuple[str, float]]] = {}
        self._action_model: Optional[ActionModel] = None
        self._fall_model: Optional[FallModel] = None
        self._event_reasoner = EventReasoner(state)
        self._log_store = DetectionLogStore()
        self._action_input_size = settings.action_model_input_size
        self._clothing_cache: dict[str, tuple[int, dict]] = {}
        self._clothing_detector = get_clothing_detector()
        self._person_identifier = get_person_identifier()
        self._frame_lock = threading.Lock()
        self._latest_frame: Optional[bytes] = None
        self._latest_frame_ts_ms = 0
        self._dynamic_skip = max(0, settings.frame_skip)

    def start(self) -> None:
        if self._running:
            return
        if not self._settings.enable_stream:
            logger.info("Stream disabled, skipping start")
            return

        logger.info(
            "Starting stream service: camera_source=%s source_id=%s",
            self._settings.camera_source,
            self._source_id,
        )
        self._running = True
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._running = False
        if self._thread:
            self._thread.join(timeout=2)

    def _open_capture(self) -> Optional[cv2.VideoCapture]:
        source = self._settings.camera_source.lower()
        if source == "webcam":
            logger.info(f"Opening webcam at index {self._settings.webcam_index}")
            if platform.system() == "Windows":
                cap = cv2.VideoCapture(self._settings.webcam_index, cv2.CAP_DSHOW)
                if cap.isOpened():
                    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
                    return cap
                logger.warning("DirectShow backend failed, falling back to default webcam backend")

            cap = cv2.VideoCapture(self._settings.webcam_index)
            if cap.isOpened():
                cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
            return cap
        if source == "file":
            if not self._settings.video_file_path:
                logger.error("video_file_path is empty")
                return None
            logger.info(f"Opening video file: {self._settings.video_file_path}")
            cap = cv2.VideoCapture(self._settings.video_file_path)
            if not cap.isOpened():
                logger.error(f"Failed to open video file: {self._settings.video_file_path}")
            return cap
        if source in {"rtsp", "http", "http_mjpeg", "mjpeg"} and self._settings.rtsp_url:
            logger.info(f"Opening camera stream: {self._settings.rtsp_url}")
            if platform.system() == "Windows":
                cap = cv2.VideoCapture(self._settings.rtsp_url, cv2.CAP_FFMPEG)
            else:
                cap = cv2.VideoCapture(self._settings.rtsp_url)
            if cap.isOpened():
                cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
            return cap
        logger.warning(f"Unknown camera source: {source}")
        return None

    def _run(self) -> None:
        if self._settings.demo_mode:
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
                    self._settings.camera_source.lower() == "file"
                    and self._settings.loop_video_file
                ):
                    cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                    continue
                break

            frame_index += 1
            skip = (
                self._dynamic_skip
                if self._settings.adaptive_frame_skip
                else self._settings.frame_skip
            )
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
            primary_action = "unknown"
            primary_confidence = 0.0
            primary_fall = False
            primary_fall_conf = 0.0
            primary_set = False
            people: list[PersonAction] = []

            poses_by_track: dict[str, dict] = {}
            if self._settings.pose_full_frame_match and person_detections:
                boxes = [(det.x1, det.y1, det.x2, det.y2) for det in person_detections]
                track_ids = [det.track_id or "0" for det in person_detections]
                poses_by_track = estimate_poses_matched_to_boxes(
                    frame,
                    pose_model,
                    boxes,
                    track_ids,
                    self._settings.keypoint_visibility_threshold,
                    min_iou=self._settings.pose_match_min_iou,
                )

            ts_ms = int(time.time() * 1000)

            for det in person_detections:
                track_id = det.track_id or "0"
                self._track_last_seen[track_id] = frame_index
                pose = poses_by_track.get(track_id)
                if pose is None:
                    pose = extract_keypoints_from_bbox(
                        frame,
                        pose_model,
                        (det.x1, det.y1, det.x2, det.y2),
                    )
                action, confidence = "unknown", 0.0
                fall, fall_conf = False, 0.0

                sequence: list[list[float]] = []
                if pose:
                    buffer = self._sequence_buffers.setdefault(
                        track_id, deque(maxlen=self._settings.action_window_frames)
                    )
                    buffer.append(self._fit_landmarks(flatten_landmarks(pose["landmarks"])))
                    sequence = list(buffer)
                    action, confidence = self._infer_action(track_id, pose, sequence, frame_index)
                    fall, fall_conf = self._infer_fall(track_id, pose, action, sequence, ts_ms)
                    if "center" in pose:
                        self._prev_center_by_track[track_id] = pose["center"]
                else:
                    self._prev_center_by_track.pop(track_id, None)
                    detector = self._fall_detectors.get(track_id)
                    if detector is not None:
                        detector.update(None, "unknown", ts_ms)

                clothing = self._get_clothing(track_id, frame, (det.x1, det.y1, det.x2, det.y2), frame_index)
                if clothing:
                    det.clothing = PersonClothing(**clothing)

                person_id = track_id
                if self._settings.person_gallery_enabled:
                    self._person_identifier.extract_person_features(
                        frame, (det.x1, det.y1, det.x2, det.y2), track_id
                    )

                people.append(
                    PersonAction(
                        track_id=track_id,
                        action=action,
                        confidence=confidence,
                        fall=fall,
                        fall_confidence=fall_conf,
                        bbox_x1=det.x1,
                        bbox_y1=det.y1,
                        bbox_x2=det.x2,
                        bbox_y2=det.y2,
                        clothing=det.clothing,
                        person_id=person_id,
                    )
                )

                if not primary_set:
                    primary_set = True
                    primary_track_id = track_id
                    primary_pose = pose
                    primary_action = action
                    primary_confidence = confidence
                    primary_fall = fall
                    primary_fall_conf = fall_conf

            if not person_detections:
                primary_pose = estimate_pose(frame, pose_model)
                primary_track_id = "0"
                if primary_pose is not None:
                    buffer = self._sequence_buffers.setdefault(
                        primary_track_id,
                        deque(maxlen=self._settings.action_window_frames),
                    )
                    buffer.append(
                        self._fit_landmarks(flatten_landmarks(primary_pose["landmarks"]))
                    )
                    sequence = list(buffer)
                    self._track_last_seen[primary_track_id] = frame_index
                    primary_action, primary_confidence = self._infer_action(
                        primary_track_id,
                        primary_pose,
                        sequence,
                        frame_index,
                    )
                    primary_fall, primary_fall_conf = self._infer_fall(
                        primary_track_id,
                        primary_pose,
                        primary_action,
                        sequence,
                        ts_ms,
                    )
                    if "center" in primary_pose:
                        self._prev_center_by_track[primary_track_id] = primary_pose["center"]

            self._cleanup_tracks(frame_index)

            status = RealtimeStatus(
                action=primary_action,
                confidence=primary_confidence,
                fall=primary_fall,
                fall_confidence=primary_fall_conf,
                timestamp_ms=ts_ms,
                track_id=primary_track_id,
                objects=objects,
                people=people,
            )

            self._update_latest_frame(frame, objects, primary_action, primary_fall, ts_ms)

            created_alerts = self._state.update(status)
            self._log_store.log_status(
                status,
                frame_index,
                source_id=self._source_id,
                user_id=self._user_id,
            )
            if created_alerts:
                self._notification_service.handle_alerts(
                    created_alerts,
                    self.get_latest_frame(),
                    user_id=self._user_id,
                    source_id=self._source_id,
                )
                self._alert_engine.publish_alerts(created_alerts)
            self._alert_engine.observe(status)

            event_alerts = self._event_reasoner.observe(status)
            if event_alerts:
                self._alert_engine.publish_alerts(event_alerts)

            if self._settings.adaptive_frame_skip and self._settings.target_fps > 0:
                elapsed_ms = (time.perf_counter() - loop_started) * 1000.0
                target_ms = 1000.0 / float(self._settings.target_fps)
                if elapsed_ms > target_ms and self._dynamic_skip < self._settings.max_frame_skip:
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

    def _get_fall_detector(self, track_id: str) -> FallDetector:
        detector = self._fall_detectors.get(track_id)
        if detector is None:
            detector = FallDetector(
                drop_threshold=self._settings.fall_drop_threshold,
                aspect_threshold=self._settings.fall_aspect_threshold,
                velocity_threshold=self._settings.fall_velocity_threshold,
                confirm_ms=self._settings.fall_confirm_ms,
                candidate_window_ms=self._settings.fall_candidate_window_ms,
            )
            self._fall_detectors[track_id] = detector
        return detector

    def _infer_action(
        self,
        track_id: str,
        pose: dict,
        sequence: list[list[float]],
        frame_index: int,
    ) -> tuple[str, float]:
        action, confidence = "unknown", 0.0
        if (
            self._settings.use_ml_action
            and sequence
            and len(sequence) >= self._settings.action_window_frames
            and frame_index % self._settings.action_stride_frames == 0
        ):
            if self._action_model is None:
                self._action_model = ActionModel.load(
                    self._settings.action_model_path,
                    device=self._settings.model_device,
                )
                self._action_input_size = self._action_model.input_size
            action, confidence = self._action_model.predict(sequence)
        else:
            prev_center = self._prev_center_by_track.get(track_id)
            action, confidence = classify_action(pose, prev_center)

        if self._settings.action_smooth_window > 0:
            history = self._action_history.setdefault(
                track_id,
                deque(maxlen=self._settings.action_smooth_window),
            )
            history.append((action, confidence))
            action, confidence = smooth_action(history, self._settings.action_min_confidence)

        return action, confidence

    def _infer_fall(
        self,
        track_id: str,
        pose: Optional[dict],
        action: str,
        sequence: list[list[float]],
        ts_ms: int,
    ) -> tuple[bool, float]:
        if (
            self._settings.use_ml_fall
            and sequence
            and len(sequence) >= self._settings.action_window_frames
        ):
            if self._fall_model is None:
                self._fall_model = FallModel.load(self._settings.fall_model_path)
            features = extract_fall_features(sequence)
            fall_conf = self._fall_model.predict(features)
            return fall_conf >= self._settings.fall_ml_min_confidence, fall_conf

        detector = self._get_fall_detector(track_id)
        return detector.update(pose, action, ts_ms)

    def _get_clothing(
        self,
        track_id: str,
        frame,
        bbox: tuple[float, float, float, float],
        frame_index: int,
    ) -> dict:
        if self._settings.clothing_cache_frames <= 0:
            return self._clothing_detector.detect_colors(frame, bbox)

        cached = self._clothing_cache.get(track_id)
        if cached is not None:
            last_frame, colors = cached
            if frame_index - last_frame < self._settings.clothing_cache_frames:
                return colors

        colors = self._clothing_detector.detect_colors(frame, bbox)
        self._clothing_cache[track_id] = (frame_index, colors)
        return colors

    def _cleanup_tracks(self, frame_index: int) -> None:
        max_age = max(60, self._settings.action_window_frames * 2)
        stale_ids = [
            track_id
            for track_id, last_seen in self._track_last_seen.items()
            if frame_index - last_seen > max_age
        ]
        for track_id in stale_ids:
            self._track_last_seen.pop(track_id, None)
            self._sequence_buffers.pop(track_id, None)
            self._action_history.pop(track_id, None)
            self._prev_center_by_track.pop(track_id, None)
            self._fall_detectors.pop(track_id, None)
            self._clothing_cache.pop(track_id, None)

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
            time.sleep(self._settings.demo_interval_ms / 1000)

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
        if self._settings.mjpeg_fps <= 0:
            return

        min_interval_ms = int(1000 / self._settings.mjpeg_fps)
        if ts_ms - self._latest_frame_ts_ms < min_interval_ms:
            return

        annotated = draw_detections(frame, objects, action, fall)
        encode_params = [int(cv2.IMWRITE_JPEG_QUALITY), self._settings.mjpeg_quality]
        ok, buffer = cv2.imencode(".jpg", annotated, encode_params)
        if not ok:
            return

        with self._frame_lock:
            self._latest_frame = buffer.tobytes()
            self._latest_frame_ts_ms = ts_ms


default_settings = get_settings()
state = RealtimeState(history_size=default_settings.history_size)
alert_engine = AlertEngine(state)
notification_service = NotificationService()
stream_service = StreamService(
    default_settings,
    state,
    alert_engine,
    notification_service,
)
