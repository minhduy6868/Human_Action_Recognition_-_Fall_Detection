from fastapi import FastAPI

from app.api.routes import router as api_router
from app.core.config import get_settings
from app.core.logging import configure_logging
from app.services.stream_service import stream_service

configure_logging()
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
