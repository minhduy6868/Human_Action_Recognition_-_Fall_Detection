from __future__ import annotations

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import decode_access_token
from app.db.database import get_db
from app.db.models import User

_auth_scheme = HTTPBearer()
_optional_auth_scheme = HTTPBearer(auto_error=False)
def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_auth_scheme),
    db: Session = Depends(get_db),
) -> User:
    token = credentials.credentials
    payload = decode_access_token(token)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid access token",
        )

    user = db.execute(select(User).where(User.id == payload["sub"]))
    user = user.scalar_one_or_none()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )
    return user


def get_optional_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_optional_auth_scheme),
    db: Session = Depends(get_db),
) -> User | None:
    if credentials is None:
        return None

    payload = decode_access_token(credentials.credentials)
    if payload is None:
        return None

    user = db.execute(select(User).where(User.id == payload["sub"]))
    return user.scalar_one_or_none()
