from __future__ import annotations

import secrets

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.db.models import User


class UserService:
    def create_user(self, db: Session, email: str, name: str, password: str) -> User:
        existing = db.query(User).filter(User.email == email).first()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered",
            )
        user = User(email=email, name=name or "", password_hash=hash_password(password))
        db.add(user)
        db.commit()
        db.refresh(user)
        return user

    def get_or_create_google_user(self, db: Session, email: str, name: str) -> User:
        user = db.query(User).filter(User.email == email).first()
        if user:
            if name and user.name != name:
                user.name = name
                db.add(user)
                db.commit()
                db.refresh(user)
            return user

        random_password = secrets.token_urlsafe(32)
        user = User(
            email=email,
            name=name or email.split("@")[0],
            password_hash=hash_password(random_password),
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user

    def set_password(self, db: Session, email: str, new_password: str) -> None:
        user = db.query(User).filter(User.email == email).first()
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found",
            )
        user.password_hash = hash_password(new_password)
        db.add(user)
        db.commit()
