from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import delete, func, or_, select
from sqlalchemy.orm import Session

from app.api.deps import get_admin_user
from app.api.response import api_response
from app.db.database import get_db
from app.db.models import ChatHistory, DeviceToken, RefreshToken, SourceConnection, User
from app.models.schemas import AdminUserUpdate, UserProfile

router = APIRouter()


def _user_payload(user: User, source_count: int = 0) -> dict:
    data = UserProfile.model_validate(user).model_dump()
    data["source_count"] = source_count
    return data


@router.get("/stats", response_model=dict)
def admin_stats(
    request: Request,
    db: Session = Depends(get_db),
    _admin: User = Depends(get_admin_user),
) -> dict:
    users = db.execute(select(User)).scalars().all()
    sources = db.execute(select(func.count(SourceConnection.id))).scalar_one()
    return api_response(
        {
            "total_users": len(users),
            "free_users": sum(1 for user in users if user.plan == "free"),
            "vip_users": sum(1 for user in users if user.plan == "vip"),
            "admin_users": sum(1 for user in users if user.role == "admin"),
            "total_sources": int(sources or 0),
        },
        request,
    )


@router.get("/users", response_model=dict)
def list_users(
    request: Request,
    q: str | None = Query(default=None, max_length=255),
    plan: str | None = Query(default=None, max_length=50),
    role: str | None = Query(default=None, max_length=50),
    db: Session = Depends(get_db),
    _admin: User = Depends(get_admin_user),
) -> dict:
    stmt = select(User).order_by(User.created_at.desc())
    if q:
        pattern = f"%{q.strip()}%"
        stmt = stmt.where(
            or_(
                User.email.ilike(pattern),
                User.name.ilike(pattern),
            )
        )
    if plan in {"free", "vip"}:
        stmt = stmt.where(User.plan == plan)
    if role in {"user", "admin"}:
        stmt = stmt.where(User.role == role)

    users = db.execute(stmt).scalars().all()
    user_ids = [user.id for user in users]
    source_counts: dict[str, int] = {}
    if user_ids:
        rows = db.execute(
            select(SourceConnection.user_id, func.count(SourceConnection.id))
            .where(SourceConnection.user_id.in_(user_ids))
            .group_by(SourceConnection.user_id)
        ).all()
        source_counts = {row[0]: int(row[1]) for row in rows}

    data = [_user_payload(user, source_counts.get(user.id, 0)) for user in users]
    return api_response(data, request)


@router.get("/users/{user_id}", response_model=dict)
def get_user(
    user_id: str,
    request: Request,
    db: Session = Depends(get_db),
    _admin: User = Depends(get_admin_user),
) -> dict:
    user = db.execute(select(User).where(User.id == user_id)).scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    source_count = db.execute(
        select(func.count(SourceConnection.id)).where(SourceConnection.user_id == user_id)
    ).scalar_one()
    return api_response(_user_payload(user, int(source_count or 0)), request)


@router.get("/users/{user_id}/sources", response_model=dict)
def list_user_sources(
    user_id: str,
    request: Request,
    db: Session = Depends(get_db),
    _admin: User = Depends(get_admin_user),
) -> dict:
    user = db.execute(select(User).where(User.id == user_id)).scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    sources = db.execute(
        select(SourceConnection)
        .where(SourceConnection.user_id == user_id)
        .order_by(SourceConnection.created_at.desc())
    ).scalars().all()
    data = [
        {
            "id": source.id,
            "name": source.name,
            "source_type": source.source_type,
            "source_url": source.source_url,
            "is_active": source.is_active,
        }
        for source in sources
    ]
    return api_response(data, request)


@router.patch("/users/{user_id}", response_model=dict)
def update_user(
    user_id: str,
    payload: AdminUserUpdate,
    request: Request,
    db: Session = Depends(get_db),
    admin: User = Depends(get_admin_user),
) -> dict:
    user = db.execute(select(User).where(User.id == user_id)).scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    if payload.name is not None:
        user.name = payload.name.strip()

    if payload.role is not None:
        if payload.role not in {"user", "admin"}:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid role")
        if user.id == admin.id and payload.role != "admin":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot remove your own admin role",
            )
        user.role = payload.role

    if payload.plan is not None:
        if payload.plan not in {"free", "vip"}:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid plan")
        user.plan = payload.plan

    db.commit()
    db.refresh(user)
    source_count = db.execute(
        select(func.count(SourceConnection.id)).where(SourceConnection.user_id == user_id)
    ).scalar_one()
    return api_response(_user_payload(user, int(source_count or 0)), request)


@router.delete("/users/{user_id}", response_model=dict)
def delete_user(
    user_id: str,
    request: Request,
    db: Session = Depends(get_db),
    admin: User = Depends(get_admin_user),
) -> dict:
    user = db.execute(select(User).where(User.id == user_id)).scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    if user.id == admin.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot delete your own account")

    db.execute(delete(RefreshToken).where(RefreshToken.user_id == user_id))
    db.execute(delete(SourceConnection).where(SourceConnection.user_id == user_id))
    db.execute(delete(DeviceToken).where(DeviceToken.user_id == user_id))
    db.execute(delete(ChatHistory).where(ChatHistory.user_id == user_id))
    db.delete(user)
    db.commit()
    return api_response({"deleted": True, "user_id": user_id}, request)


@router.get("/plans", response_model=dict)
def plan_catalog(request: Request) -> dict:
    return api_response(
        {
            "plans": [
                {
                    "id": "free",
                    "name": "Free",
                    "max_sources": 1,
                    "max_active_sources": 1,
                    "daily_ai_queries": 20,
                    "history_window_hours": 24,
                },
                {
                    "id": "vip",
                    "name": "VIP",
                    "max_sources": None,
                    "max_active_sources": None,
                    "daily_ai_queries": None,
                    "history_window_hours": None,
                },
            ]
        },
        request,
    )
