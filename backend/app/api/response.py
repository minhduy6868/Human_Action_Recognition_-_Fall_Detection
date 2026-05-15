from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from fastapi import Request


def build_meta(request: Request) -> dict[str, Any]:
    request_id = getattr(request.state, "request_id", "")
    return {
        "request_id": request_id,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


def api_response(data: Any, request: Request) -> dict[str, Any]:
    return {
        "data": data,
        "meta": build_meta(request),
    }


def error_response(
    message: str | dict[str, Any],
    request: Request,
    code: str | None = None,
) -> dict[str, Any]:
    if isinstance(message, dict):
        payload = dict(message)
    else:
        payload = {
            "message": message,
        }
        if code:
            payload["code"] = code
    return {
        "error": payload,
        "meta": build_meta(request),
    }
