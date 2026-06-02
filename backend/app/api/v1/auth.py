from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Request, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.api.response import api_response
from app.db.database import get_db
from app.db.models import DeviceToken
from app.models.schemas import (
    AuthLoginRequest,
    GoogleAuthRequest,
    AuthRefreshRequest,
    DeviceTokenRequest,
    DeviceTokenRemoveRequest,
    UserProfile,
    OtpRequestPayload,
    OtpVerifyPayload,
    OtpResponse,
    RegisterRequest,
    PasswordResetRequest,
)
from app.services.auth_service import AuthService
from app.services.notification_service import NotificationService
from app.services.user_service import UserService

router = APIRouter()
service = AuthService()
notification = NotificationService()
user_service = UserService()


@router.post("/login", response_model=dict)
def login(
    payload: AuthLoginRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> dict:
    user = service.authenticate_user(db, payload.email, payload.password)
    tokens = service.issue_tokens(db, user)
    return api_response(tokens, request)


@router.post("/google", response_model=dict)
def login_with_google(
    payload: GoogleAuthRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> dict:
    user = service.authenticate_google_user(db, payload.id_token)
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


@router.post("/register", response_model=dict)
def register(
    payload: RegisterRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> dict:
    user = user_service.create_user(db, payload.email, payload.name or "", payload.password)
    tokens = service.issue_tokens(db, user)
    return api_response(tokens, request)


@router.post("/otp/request", response_model=dict)
def otp_request(payload: OtpRequestPayload, request: Request) -> dict:
    res = notification.request_otp(payload.email, payload.purpose)
    body = {"ok": True, "expires_in": res.get("expires_in")}
    if res.get("otp"):
        body["otp"] = res.get("otp")
    return api_response(body, request)


@router.post("/otp/verify", response_model=dict)
def otp_verify(payload: OtpVerifyPayload, request: Request) -> dict:
    ok = notification.verify_otp(payload.email, payload.otp, payload.purpose)
    return api_response({"ok": ok}, request)


@router.post("/password/reset", response_model=dict)
def password_reset(
    payload: PasswordResetRequest,
    request: Request,
    db: Session = Depends(get_db),
) -> dict:
    ok = notification.verify_otp(payload.email, payload.otp, "reset")
    if not ok:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid OTP")
    user_service.set_password(db, payload.email, payload.new_password)
    return api_response({"reset": True}, request)


@router.post("/device-token/register", response_model=dict)
def register_device_token(
    payload: DeviceTokenRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
) -> dict:
    token = payload.token.strip()
    if not token:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Token is required")

    now = datetime.now(timezone.utc)
    record = db.execute(select(DeviceToken).where(DeviceToken.token == token)).scalar_one_or_none()

    if record is None:
        record = DeviceToken(
            user_id=current_user.id,
            source_id=payload.source_id,
            token=token,
            platform=payload.platform or "unknown",
            is_active=True,
            last_seen_at=now,
        )
    else:
        record.user_id = current_user.id
        record.source_id = payload.source_id
        record.platform = payload.platform or record.platform or "unknown"
        record.is_active = True
        record.last_seen_at = now

    db.add(record)
    db.commit()
    return api_response({"registered": True}, request)


@router.post("/device-token/remove", response_model=dict)
def remove_device_token(
    payload: DeviceTokenRemoveRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
) -> dict:
    token = payload.token.strip()
    if not token:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Token is required")

    record = db.execute(select(DeviceToken).where(DeviceToken.token == token)).scalar_one_or_none()
    if record is None:
        return api_response({"removed": False}, request)

    if record.user_id and record.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Token does not belong to current user")

    record.is_active = False
    record.last_seen_at = datetime.now(timezone.utc)
    db.add(record)
    db.commit()
    return api_response({"removed": True}, request)
