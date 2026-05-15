from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.api.response import api_response
from app.db.database import get_db
from app.db.models import SourceConnection
from app.models.schemas import SourceCreate, SourceResponse, SourceUpdate
from app.services.stream_manager import stream_manager

router = APIRouter()


def _is_free_plan(user) -> bool:
    return (user.plan or "free").lower() == "free"


def _enforce_max_sources(db: Session, user_id: str, max_sources: int) -> None:
    existing = db.execute(
        select(SourceConnection).where(SourceConnection.user_id == user_id)
    ).scalars().all()
    if len(existing) >= max_sources:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail={
                "code": "PLAN_LIMIT_REACHED",
                "message": "Source limit reached for current plan",
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
    for session in stream_manager.list():
        if session.user_id != user_id:
            continue
        if keep_source_id and session.source_id == keep_source_id:
            continue
        stream_manager.stop(session.source_id)


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

    source = SourceConnection(
        user_id=current_user.id,
        name=payload.name,
        source_type=payload.source_type,
        source_url=payload.source_url,
        is_active=payload.is_active,
    )
    if _is_free_plan(current_user) and payload.is_active:
        _deactivate_other_sources(db, current_user.id)
        _stop_other_sessions(current_user.id)
    db.add(source)
    db.commit()
    db.refresh(source)
    if payload.is_active:
        stream_manager.start(
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

    if _is_free_plan(current_user) and data.get("is_active") is True:
        _deactivate_other_sources(db, current_user.id, keep_source_id=source.id)
        _stop_other_sessions(current_user.id, keep_source_id=source.id)

    source.updated_at = datetime.now(timezone.utc)
    db.add(source)
    db.commit()
    db.refresh(source)
    if "is_active" in data:
        if source.is_active:
            stream_manager.start(
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

    if _is_free_plan(current_user):
        _deactivate_other_sources(db, current_user.id, keep_source_id=source.id)
        _stop_other_sessions(current_user.id, keep_source_id=source.id)

    source.is_active = True
    source.updated_at = datetime.now(timezone.utc)
    db.add(source)
    db.commit()
    db.refresh(source)

    stream_manager.start(
        source_id=source.id,
        user_id=current_user.id,
        source_type=source.source_type,
        source_url=source.source_url,
    )
    return api_response(SourceResponse.from_orm(source).model_dump(), request)
