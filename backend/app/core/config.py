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
    fall_ml_min_confidence: float = 0.9
    keypoint_visibility_threshold: float = 0.5
    fall_drop_threshold: float = 0.18
    fall_aspect_threshold: float = 1.2
    fall_velocity_threshold: float = 0.12
    fall_confirm_ms: int = 1500
    fall_candidate_window_ms: int = 2500
    database_url: str = "postgresql+psycopg://postgres:postgres123@localhost:5432/video-ai-detect"
    database_enabled: bool = True
    db_auto_create: bool = True
    jwt_secret: str = "change-me"
    jwt_algorithm: str = "HS256"
    access_token_exp_minutes: int = 15
    refresh_token_exp_days: int = 30
    google_client_id: str = ""
    # Comma-separated list of allowed Google OAuth client IDs (e.g. web, android)
    google_client_ids: str = ""
    seed_admin: bool = True
    seed_admin_email: str = "admin@local"
    seed_admin_password: str = "admin123"
    seed_admin_name: str = "Admin"
    seed_admin_role: str = "admin"
    seed_admin_plan: str = "vip"
    log_enabled: bool = True
    log_retention_days: int = 30
    log_cleanup_interval_ms: int = 60 * 60 * 1000
    log_every_n_frames: int = 1
    log_source_id: str = "default"
    chat_history_enabled: bool = True
    chat_history_retention_days: int = 30
    chat_history_cleanup_interval_ms: int = 6 * 60 * 60 * 1000
    daily_ai_queries_free: int = 20
    vip_max_active_sources: int = 5
    openrouter_api_key: str = ""
    openrouter_model: str = "baidu/cobuddy:free"
    openrouter_site_url: str = ""
    openrouter_app_name: str = "video-ai-detect"
    openrouter_timeout_seconds: float = 30.0
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

    enable_push_notifications: bool = True
    enable_email_notifications: bool = True
    fcm_credentials_path: str = ""
    fcm_topic: str = ""
    cloudinary_cloud_name: str = ""
    cloudinary_upload_preset: str = ""
    emailjs_service_id: str = ""
    emailjs_template_id: str = ""
    emailjs_public_key: str = ""
    emailjs_otp_template_id: str = ""
    # SMTP fallback settings
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_pass: str = ""
    smtp_use_tls: bool = True
    email_from: str = ""
    notification_cooldown_ms: int = 15 * 1000
    otp_length: int = 6
    otp_ttl_minutes: int = 10
    # Telegram notifications
    enable_telegram_notifications: bool = False
    telegram_bot_token: str = ""
    # Comma-separated chat ids to send notifications to (supports numbers or @channel)
    telegram_chat_ids: str = ""
    # Firebase Realtime Database URL (e.g. https://<project>.firebaseio.com/ or .asia-southeast1.firebasedatabase.app/)
    firebase_rtdb_url: str = "https://love-app-19405-default-rtdb.asia-southeast1.firebasedatabase.app"
    # Optional secret or auth param to append when writing to RTDB, e.g. '?auth=...'
    firebase_rtdb_auth_param: str = ""
    # Optional ngrok public url, can be provided via env when automatic detection is not possible
    ngrok_public_url: str = ""
    # Automatically start ngrok tunnel when not running (requires pyngrok)
    enable_auto_ngrok: bool = True
    # Optional ngrok authtoken to configure pyngrok (if provided)
    ngrok_authtoken: str = ""

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
