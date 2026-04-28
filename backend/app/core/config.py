from functools import lru_cache

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "video-ai-detect"
    app_version: str = "0.1.0"
    environment: str = "local"
    rtsp_url: str = ""
    camera_source: str = "rtsp"
    webcam_index: int = 0
    enable_stream: bool = True
    frame_skip: int = 1
    history_size: int = 200
    ws_interval_ms: int = 250

    class Config:
        env_file = ".env"


@lru_cache()
def get_settings() -> Settings:
    return Settings()
