from __future__ import annotations

from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.api.response import api_response
from app.db.database import get_db
from app.models.schemas import AuthLoginRequest, AuthRefreshRequest, UserProfile
from app.services.auth_service import AuthService

router = APIRouter()
service = AuthService()


@router.post("/login", response_model=dict)
def login(
    payload: AuthLoginRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> dict:
    user = service.authenticate_user(db, payload.email, payload.password)
    tokens = service.issue_tokens(db, user)
    return api_response(tokens, request)


@router.post("/refresh", response_model=dict)
def refresh(
    payload: AuthRefreshRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> dict:
    tokens = service.rotate_refresh(db, payload.refresh_token)
    return api_response(tokens, request)


@router.post("/logout", response_model=dict)
def logout(
    payload: AuthRefreshRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> dict:
    service.revoke_refresh(db, payload.refresh_token)
    return api_response({"revoked": True}, request)


@router.get("/me", response_model=dict)
def me(request: Request, current_user=Depends(get_current_user)) -> dict:
    profile = UserProfile.from_orm(current_user)
    return api_response(profile.model_dump(), request)
