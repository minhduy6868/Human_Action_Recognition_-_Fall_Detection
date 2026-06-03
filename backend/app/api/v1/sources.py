from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.api.response import api_response
from app.db.database import get_db
from app.db.models import SourceConnection
from app.models.schemas import SourceCreate, SourceResponse, SourceUpdate
from app.core.config import get_settings
from app.services.stream_manager import stream_manager

router = APIRouter()
settings = get_settings()


def _is_free_plan(user) -> bool:
    return (user.plan or "free").lower() == "free"


def _is_vip_plan(user) -> bool:
    return (user.plan or "free").lower() == "vip"


def _apply_activation_policy(
    db: Session,
    user,
    source_id: str,
    *,
    source_already_active: bool = False,
) -> None:
    if _is_free_plan(user):
        _deactivate_other_sources(db, user.id, keep_source_id=source_id)
        _stop_other_sessions(user.id, keep_source_id=source_id)
        return

    if source_already_active:
        return

    limit = max(1, settings.vip_max_active_sources)
    query = select(func.count()).select_from(SourceConnection).where(
        SourceConnection.user_id == user.id,
        SourceConnection.is_active.is_(True),
    )
    if source_id != "__new__":
        query = query.where(SourceConnection.id != source_id)
    other_active = db.execute(query).scalar_one()
    if other_active >= limit:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail={
                "code": "ACTIVE_SOURCE_LIMIT",
                "message": f"VIP cho phép tối đa {limit} camera chạy cùng lúc. Tắt bớt một nguồn rồi thử lại.",
                "message_en": f"VIP allows at most {limit} simultaneous active cameras. Stop one source first.",
                "max_active_sources": limit,
            },
        )


def _enforce_max_sources(db: Session, user_id: str, max_sources: int) -> None:
    existing = db.execute(
        select(SourceConnection).where(SourceConnection.user_id == user_id)
    ).scalars().all()
    if len(existing) >= max_sources:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail={
                "code": "PLAN_LIMIT_REACHED",
                "message": "Gói Free chỉ được 1 nguồn camera. Nâng cấp VIP để thêm nhiều nguồn.",
                "message_en": "Free plan allows 1 camera source. Upgrade to VIP for more sources.",
                "upgrade_required": True,
            },
        )


def _deactivate_other_sources(db: Session, user_id: str, keep_source_id: str | None = None) -> None:
    sources = db.execute(
        select(SourceConnection).where(SourceConnection.user_id == user_id)
    ).scalars().all()
    for source in sources:
        if keep_source_id and source.id == keep_source_id:
            continue
        if source.is_active:
            source.is_active = False
            source.updated_at = datetime.now(timezone.utc)
            db.add(source)


def _stop_other_sessions(user_id: str, keep_source_id: str | None = None) -> None:
    for session in stream_manager.list(user_id=user_id):
        if keep_source_id and session.source_id == keep_source_id:
            continue
        stream_manager.stop(session.source_id)


def _start_stream_or_raise(
    *,
    source_id: str,
    user_id: str,
    source_type: str,
    source_url: str,
) -> None:
    try:
        stream_manager.start(
            source_id=source_id,
            user_id=user_id,
            source_type=source_type,
            source_url=source_url,
        )
    except PermissionError:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "FORBIDDEN", "message": "Source is owned by another account"},
        )


@router.get("", response_model=dict)
def list_sources(
    request: Request,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
) -> dict:
    sources = db.execute(
        select(SourceConnection).where(SourceConnection.user_id == current_user.id)
    ).scalars().all()
    payload = [SourceResponse.from_orm(source).model_dump() for source in sources]
    return api_response(payload, request)


@router.post("", response_model=dict)
def create_source(
    payload: SourceCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
) -> dict:
    if _is_free_plan(current_user):
        _enforce_max_sources(db, current_user.id, max_sources=1)
    elif _is_vip_plan(current_user):
        _enforce_max_sources(db, current_user.id, max_sources=50)

    if payload.is_active:
        if _is_free_plan(current_user):
            _deactivate_other_sources(db, current_user.id)
            _stop_other_sessions(current_user.id)
        else:
            _apply_activation_policy(
                db,
                current_user,
                source_id="__new__",
                source_already_active=False,
            )

    source = SourceConnection(
        user_id=current_user.id,
        name=payload.name,
        source_type=payload.source_type,
        source_url=payload.source_url,
        is_active=payload.is_active,
    )
    db.add(source)
    db.commit()
    db.refresh(source)
    if payload.is_active:
        _start_stream_or_raise(
            source_id=source.id,
            user_id=current_user.id,
            source_type=source.source_type,
            source_url=source.source_url,
        )
    return api_response(SourceResponse.from_orm(source).model_dump(), request)


@router.get("/{source_id}", response_model=dict)
def get_source(
    source_id: str,
    request: Request,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
) -> dict:
    source = db.execute(
        select(SourceConnection).where(
            SourceConnection.id == source_id,
            SourceConnection.user_id == current_user.id,
        )
    ).scalar_one_or_none()
    if source is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "NOT_FOUND", "message": "Source not found"},
        )
    return api_response(SourceResponse.from_orm(source).model_dump(), request)


@router.patch("/{source_id}", response_model=dict)
def update_source(
    source_id: str,
    payload: SourceUpdate,
    request: Request,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
) -> dict:
    source = db.execute(
        select(SourceConnection).where(
            SourceConnection.id == source_id,
            SourceConnection.user_id == current_user.id,
        )
    ).scalar_one_or_none()
    if source is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "NOT_FOUND", "message": "Source not found"},
        )

    data = payload.model_dump(exclude_unset=True)
    for key, value in data.items():
        setattr(source, key, value)

    if data.get("is_active") is True:
        _apply_activation_policy(
            db,
            current_user,
            source.id,
            source_already_active=source.is_active,
        )

    source.updated_at = datetime.now(timezone.utc)
    db.add(source)
    db.commit()
    db.refresh(source)
    if "is_active" in data:
        if source.is_active:
            _start_stream_or_raise(
                source_id=source.id,
                user_id=current_user.id,
                source_type=source.source_type,
                source_url=source.source_url,
            )
        else:
            stream_manager.stop(source.id)
    return api_response(SourceResponse.from_orm(source).model_dump(), request)


@router.delete("/{source_id}", response_model=dict)
def delete_source(
    source_id: str,
    request: Request,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
) -> dict:
    source = db.execute(
        select(SourceConnection).where(
            SourceConnection.id == source_id,
            SourceConnection.user_id == current_user.id,
        )
    ).scalar_one_or_none()
    if source is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "NOT_FOUND", "message": "Source not found"},
        )

    stream_manager.stop(source.id)
    db.delete(source)
    db.commit()
    return api_response({"deleted": True}, request)


@router.post("/{source_id}/activate", response_model=dict)
def activate_source(
    source_id: str,
    request: Request,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
) -> dict:
    source = db.execute(
        select(SourceConnection).where(
            SourceConnection.id == source_id,
            SourceConnection.user_id == current_user.id,
        )
    ).scalar_one_or_none()
    if source is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "NOT_FOUND", "message": "Source not found"},
        )

    _apply_activation_policy(
        db,
        current_user,
        source.id,
        source_already_active=source.is_active,
    )

    source.is_active = True
    source.updated_at = datetime.now(timezone.utc)
    db.add(source)
    db.commit()
    db.refresh(source)

    _start_stream_or_raise(
        source_id=source.id,
        user_id=current_user.id,
        source_type=source.source_type,
        source_url=source.source_url,
    )
    return api_response(SourceResponse.from_orm(source).model_dump(), request)
