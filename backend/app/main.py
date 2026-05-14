import logging
import time

from fastapi import FastAPI

from app.api.routes import router as api_router
from app.core.config import get_settings
from app.core.logging import configure_logging

configure_logging()
_startup_log = logging.getLogger(__name__)
_t0_ultra = time.perf_counter()
try:
    import ultralytics  # noqa: F401  # heavy first import (torch, etc.)
except ImportError:
    _startup_log.warning(
        "ultralytics not installed; install ML deps for video pipelines (requirements-ml.txt)"
    )
else:
    _startup_log.info(
        "Ultralytics pre-import done in %.1fs (avoids silent delay in stream thread)",
        time.perf_counter() - _t0_ultra,
    )

from app.services.stream_service import stream_service

settings = get_settings()

app = FastAPI(title=settings.app_name, version=settings.app_version)
app.include_router(api_router, prefix="/api")


@app.on_event("startup")
def start_stream() -> None:
    stream_service.start()


@app.on_event("shutdown")
def stop_stream() -> None:
    stream_service.stop()


@app.get("/health")
def health_check() -> dict:
    return {"status": "ok"}
