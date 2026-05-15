from __future__ import annotations

from datetime import datetime, timezone

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

settings = get_settings()


class AuthService:
    def authenticate_user(self, db: Session, email: str, password: str) -> User:
        user = db.execute(select(User).where(User.email == email)).scalar_one_or_none()
        if user is None or not verify_password(password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password",
            )
        return user

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
