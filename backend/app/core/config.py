from functools import lru_cache

from pydantic_settings import BaseSettings


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
    frame_skip: int = 1
    adaptive_frame_skip: bool = True
    target_fps: int = 15
    max_frame_skip: int = 4
    history_size: int = 10000
    ws_interval_ms: int = 250
    demo_mode: bool = False
    demo_interval_ms: int = 500
    yolo_model_path: str = "yolo11n.pt"
    yolo_pose_model_path: str = "yolo11s-pose.pt"
    yolo_confidence: float = 0.35
    yolo_pose_confidence: float = 0.25
    yolo_iou: float = 0.5
    yolo_pose_iou: float = 0.5
    yolo_imgsz: int = 640
    yolo_max_det: int = 20
    yolo_classes: str = ""
    yolo_tracker: str = "bytetrack.yaml"
    mjpeg_fps: int = 10
    mjpeg_quality: int = 80
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

    class Config:
        env_file = ".env"


@lru_cache()
def get_settings() -> Settings:
    return Settings()
