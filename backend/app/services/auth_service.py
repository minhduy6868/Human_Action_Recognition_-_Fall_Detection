from __future__ import annotations

from datetime import datetime, timezone

import httpx
from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.security import (
    create_access_token,
    create_refresh_token,
    hash_token,
    refresh_expires_at,
    verify_password,
)
from app.db.models import RefreshToken, User
from app.services.user_service import UserService

settings = get_settings()
user_service = UserService()


class AuthService:
    def authenticate_user(self, db: Session, email: str, password: str) -> User:
        user = db.execute(select(User).where(User.email == email)).scalar_one_or_none()
        if user is None or not verify_password(password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password",
            )
        return user

    def authenticate_google_user(self, db: Session, id_token: str) -> User:
        try:
            response = httpx.get(
                "https://oauth2.googleapis.com/tokeninfo",
                params={"id_token": id_token},
                timeout=10.0,
            )
            response.raise_for_status()
            token_info = response.json()
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid Google token",
            ) from exc

        audience = token_info.get("aud")
        # Build allowed audience set from configuration (support multiple client IDs)
        allowed_aud = set()
        if settings.google_client_id:
            allowed_aud.add(settings.google_client_id)
        if getattr(settings, "google_client_ids", ""):
            parts = [p.strip() for p in settings.google_client_ids.split(",") if p.strip()]
            for p in parts:
                allowed_aud.add(p)

        if allowed_aud and audience not in allowed_aud:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Google token audience mismatch",
            )

        if str(token_info.get("email_verified", "false")).lower() not in {"true", "1"}:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Google account email is not verified",
            )

        email = token_info.get("email")
        if not email:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Google token missing email",
            )

        name = token_info.get("name") or token_info.get("given_name") or ""
        return user_service.get_or_create_google_user(db, email, name)

    def issue_tokens(self, db: Session, user: User) -> dict:
        access_token = create_access_token(user.id, user.role, user.plan)
        refresh_token = create_refresh_token()
        token_hash = hash_token(refresh_token)
        db.add(
            RefreshToken(
                user_id=user.id,
                token_hash=token_hash,
                expires_at=refresh_expires_at(),
            )
        )
        db.commit()
        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
            "expires_in": settings.access_token_exp_minutes * 60,
            "refresh_expires_in": settings.refresh_token_exp_days * 24 * 60 * 60,
        }

    def rotate_refresh(self, db: Session, refresh_token: str) -> dict:
        token_hash = hash_token(refresh_token)
        stored = db.execute(
            select(RefreshToken).where(RefreshToken.token_hash == token_hash)
        ).scalar_one_or_none()
        if stored is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid refresh token",
            )

        now = datetime.now(timezone.utc)
        if stored.revoked_at is not None or stored.expires_at <= now:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Refresh token expired",
            )

        stored.revoked_at = now
        db.add(stored)
        db.commit()
        db.refresh(stored)

        user = db.get(User, stored.user_id)
        if user is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found",
            )
        return self.issue_tokens(db, user)

    def revoke_refresh(self, db: Session, refresh_token: str) -> None:
        token_hash = hash_token(refresh_token)
        stored = db.execute(
            select(RefreshToken).where(RefreshToken.token_hash == token_hash)
        ).scalar_one_or_none()
        if stored is None:
            return

        stored.revoked_at = datetime.now(timezone.utc)
        db.add(stored)
        db.commit()
