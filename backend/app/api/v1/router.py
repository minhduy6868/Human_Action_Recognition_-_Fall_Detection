from fastapi import APIRouter

from app.api.v1.auth import router as auth_router
from app.api.v1.monitoring import router as monitoring_router
from app.api.v1.sources import router as sources_router

router = APIRouter()
router.include_router(auth_router, prefix="/auth", tags=["auth"])
router.include_router(sources_router, prefix="/sources", tags=["sources"])
router.include_router(monitoring_router, tags=["monitoring"])
