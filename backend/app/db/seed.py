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
        _ensure_telegram_subscriber_schema()


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


def _ensure_telegram_subscriber_schema() -> None:
    statements = [
        "ALTER TABLE telegram_subscribers ADD COLUMN IF NOT EXISTS user_id TEXT NULL",
        "ALTER TABLE telegram_subscribers ADD COLUMN IF NOT EXISTS telegram_user_id TEXT NULL",
        "ALTER TABLE telegram_subscribers ADD COLUMN IF NOT EXISTS display_name TEXT NULL",
        "ALTER TABLE telegram_subscribers ADD COLUMN IF NOT EXISTS username TEXT NULL",
        "ALTER TABLE telegram_subscribers ADD COLUMN IF NOT EXISTS first_name TEXT NULL",
        "ALTER TABLE telegram_subscribers ADD COLUMN IF NOT EXISTS last_name TEXT NULL",
        "ALTER TABLE telegram_subscribers ADD COLUMN IF NOT EXISTS language_code TEXT NULL",
        "ALTER TABLE telegram_subscribers ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE",
        "ALTER TABLE telegram_subscribers ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ NULL",
        "ALTER TABLE telegram_subscribers ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()",
        "ALTER TABLE telegram_subscribers ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()",
        "CREATE INDEX IF NOT EXISTS idx_telegram_subscribers_user_id ON telegram_subscribers(user_id)",
        "CREATE INDEX IF NOT EXISTS idx_telegram_subscribers_telegram_user_id ON telegram_subscribers(telegram_user_id)",
        "CREATE INDEX IF NOT EXISTS idx_telegram_subscribers_active ON telegram_subscribers(is_active)",
    ]
    with engine.begin() as conn:
        for stmt in statements:
            conn.execute(text(stmt))

        conn.execute(
            text(
                """
                DO $$
                BEGIN
                    IF NOT EXISTS (
                        SELECT 1
                        FROM pg_constraint
                        WHERE conname = 'fk_telegram_subscribers_user_id'
                    ) THEN
                        ALTER TABLE telegram_subscribers
                            ADD CONSTRAINT fk_telegram_subscribers_user_id
                            FOREIGN KEY (user_id) REFERENCES users(id)
                            ON DELETE SET NULL;
                    END IF;
                END $$;
                """
            )
        )


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
