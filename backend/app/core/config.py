import os
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "video-ai-detect"
    app_version: str = "0.1.0"
    environment: str = "local"
    rtsp_url: str = ""
    camera_source: str = "rtsp"
    webcam_index: int = 0
    video_file_path: str = ""
    loop_video_file: bool = False
    enable_stream: bool = True
    frame_skip: int = 0
    adaptive_frame_skip: bool = True
    target_fps: int = 20
    max_frame_skip: int = 3
    history_size: int = 10000
    ws_interval_ms: int = 250
    demo_mode: bool = False
    demo_interval_ms: int = 500
    yolo_model_path: str = "yolo11n.pt"
    yolo_pose_model_path: str = "yolo11s-pose.pt"
    yolo_confidence: float = 0.3
    yolo_pose_confidence: float = 0.25
    yolo_iou: float = 0.45
    yolo_pose_iou: float = 0.5
    yolo_imgsz: int = 640
    yolo_max_det: int = 30
    yolo_classes: str = ""
    yolo_tracker: str = "botsort.yaml"
    clothing_cache_frames: int = 30
    fall_rule_consecutive_frames: int = 3
    # Controls PersonIdentifier feature (kept for backward compatibility, was person_gallery_enabled)
    person_gallery_enabled: bool = True
    pose_full_frame_match: bool = True
    pose_match_min_iou: float = 0.15
    mjpeg_fps: int = 15
    mjpeg_quality: int = 75
    webcam_scan_max: int = 5
    use_ml_action: bool = False
    use_ml_fall: bool = False
    model_device: str = "cpu"
    action_model_path: str = "models/action_lstm.pt"
    fall_model_path: str = "models/fall_xgb.json"
    action_model_input_size: int = 99
    action_window_frames: int = 30
    action_stride_frames: int = 5
    action_smooth_window: int = 12
    action_min_confidence: float = 0.4
    keypoint_visibility_threshold: float = 0.5
    fall_drop_threshold: float = 0.18
    fall_aspect_threshold: float = 1.2
    fall_velocity_threshold: float = 0.12
    fall_confirm_ms: int = 1500
    fall_candidate_window_ms: int = 2500
    supabase_url: str = ""
    supabase_key: str = ""
    supabase_service_key: str = ""
    supabase_alerts_table: str = "alerts"
    supabase_reports_table: str = "reports"
    alert_check_interval_ms: int = 5000
    abnormal_window_ms: int = 60 * 60 * 1000
    abnormal_min_samples: int = 50
    abnormal_lying_ms: int = 60 * 1000
    abnormal_transition_threshold: int = 20
    abnormal_dominant_action_ratio: float = 0.55
    abnormal_min_score: float = 0.65
    abnormal_suppression_ms: int = 5 * 60 * 1000
    enable_event_reasoning: bool = True
    event_check_interval_ms: int = 1000
    loitering_window_ms: int = 2 * 60 * 1000
    loitering_min_idle_ratio: float = 0.7
    loitering_suppression_ms: int = 5 * 60 * 1000
    suspicious_window_ms: int = 60 * 1000
    suspicious_transition_threshold: int = 12
    suspicious_suppression_ms: int = 2 * 60 * 1000
    crowd_min_people: int = 5
    crowd_min_duration_ms: int = 10 * 1000
    crowd_suppression_ms: int = 2 * 60 * 1000
    abandoned_object_stationary_ms: int = 60 * 1000
    abandoned_object_move_ratio: float = 0.15
    abandoned_person_distance_ratio: float = 2.5
    abandoned_forget_ms: int = 5 * 60 * 1000
    abandoned_suppression_ms: int = 5 * 60 * 1000

    model_config = SettingsConfigDict(
        env_file=os.path.join(os.path.dirname(__file__), "../../.env"),
        env_file_encoding="utf-8",
        # Allow fields like model_device without clashing with Pydantic's model_* namespace
        protected_namespaces=("settings_",),
    )

    def ultralytics_device(self) -> str | int:
        """Resolve MODEL_DEVICE to a device usable by Ultralytics / torch.

        Falls back to CPU automatically when CUDA is requested but the
        installed PyTorch build has no CUDA support (e.g. CPU-only wheels).
        """
        import logging
        raw = self.model_device.strip().lower()
        if raw in ("cpu", "none", ""):
            return "cpu"

        # Any non-cpu value → check CUDA availability first
        try:
            import torch
            if not torch.cuda.is_available():
                logging.getLogger(__name__).warning(
                    "MODEL_DEVICE=%r requested but torch.cuda.is_available()=False "
                    "(PyTorch installed without CUDA support). Falling back to CPU. "
                    "Re-install PyTorch with CUDA: https://pytorch.org/get-started/locally/",
                    self.model_device,
                )
                return "cpu"
        except ImportError:
            return "cpu"

        if raw in ("cuda", "gpu"):
            return 0
        return self.model_device.strip()


@lru_cache()
def get_settings() -> Settings:
    return Settings()
