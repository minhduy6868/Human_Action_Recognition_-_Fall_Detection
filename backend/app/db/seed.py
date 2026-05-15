from __future__ import annotations

from sqlalchemy import select, text

from app.core.config import get_settings
from app.core.security import hash_password
from app.db.database import Base, SessionLocal, engine
from app.db.models import User

settings = get_settings()


def init_db() -> None:
    if settings.db_auto_create:
        Base.metadata.create_all(bind=engine)
        _ensure_detection_log_schema()


def _ensure_detection_log_schema() -> None:
    statements = [
        "ALTER TABLE detection_logs ADD COLUMN IF NOT EXISTS people_json JSONB NOT NULL DEFAULT '[]'::jsonb",
        "ALTER TABLE detection_logs ADD COLUMN IF NOT EXISTS objects_json JSONB NOT NULL DEFAULT '[]'::jsonb",
        "ALTER TABLE detection_logs ADD COLUMN IF NOT EXISTS model_version_id INTEGER NULL",
        "CREATE INDEX IF NOT EXISTS idx_detection_logs_source_id ON detection_logs(source_id)",
        "CREATE INDEX IF NOT EXISTS idx_detection_logs_user_id ON detection_logs(user_id)",
        "CREATE INDEX IF NOT EXISTS idx_detection_logs_model_version_id ON detection_logs(model_version_id)",
    ]
    with engine.begin() as conn:
        for stmt in statements:
            conn.execute(text(stmt))


def seed_admin() -> None:
    if not settings.seed_admin:
        return

    with SessionLocal() as db:
        existing = db.execute(
            select(User).where(User.email == settings.seed_admin_email)
        ).scalar_one_or_none()
        if existing:
            return

        user = User(
            email=settings.seed_admin_email,
            name=settings.seed_admin_name,
            password_hash=hash_password(settings.seed_admin_password),
            role=settings.seed_admin_role,
            plan=settings.seed_admin_plan,
        )
        db.add(user)
        db.commit()
