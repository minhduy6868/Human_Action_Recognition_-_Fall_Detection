import logging
import time
import uuid

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy import select

from app.api.response import error_response
from app.api.v1.router import router as api_v1_router
from app.core.config import get_settings
from app.core.logging import configure_logging
from app.db.database import SessionLocal
from app.db.models import SourceConnection
from app.db.seed import init_db, seed_admin
from app.services.stream_manager import stream_manager
from app.services.telegram_bot_service import telegram_bot_service
from app.services.config_publisher import publish_ngrok_to_rtdb

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

settings = get_settings()

app = FastAPI(title=settings.app_name, version=settings.app_version)
app.include_router(api_v1_router, prefix="/api/v1")


@app.middleware("http")
async def request_id_middleware(request: Request, call_next):
    request_id = request.headers.get("x-request-id") or uuid.uuid4().hex
    request.state.request_id = request_id
    response = await call_next(request)
    response.headers["x-request-id"] = request_id
    return response


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    detail = exc.detail
    if isinstance(detail, dict):
        payload = detail
    else:
        payload = {"message": str(detail), "code": "http_error"}
    return JSONResponse(
        status_code=exc.status_code,
        content=error_response(payload, request),
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    payload = {
        "message": "Validation error",
        "code": "validation_error",
        "details": exc.errors(),
    }
    return JSONResponse(
        status_code=422,
        content=error_response(payload, request),
    )


@app.on_event("startup")
def start_stream() -> None:
    init_db()
    seed_admin()
    try:
        publish_ngrok_to_rtdb()
    except Exception:
        _startup_log.exception('Publishing ngrok URL to RTDB failed')
    telegram_bot_service.start()
    with SessionLocal() as db:
        active_sources = db.execute(
            select(SourceConnection).where(SourceConnection.is_active == True)
        ).scalars().all()

        for source in active_sources:
            stream_manager.start(
                source_id=source.id,
                user_id=source.user_id,
                source_type=source.source_type,
                source_url=source.source_url,
            )


@app.on_event("shutdown")
def stop_stream() -> None:
    telegram_bot_service.stop()
    for session in stream_manager.list():
        stream_manager.stop(session.source_id)


@app.get("/health")
def health_check() -> dict:
    return {"status": "ok"}
