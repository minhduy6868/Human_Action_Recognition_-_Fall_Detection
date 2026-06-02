from __future__ import annotations

import os
import sys
from typing import Any

import httpx

from app.core.config import get_settings


def _extract_chat_ids(payload: dict[str, Any]) -> list[str]:
    chat_ids: list[str] = []
    for item in payload.get("result", []):
        message = item.get("message") or item.get("channel_post") or {}
        chat = message.get("chat") or {}
        chat_id = chat.get("id")
        if chat_id is None:
            continue
        chat_ids.append(str(chat_id))
    return sorted(set(chat_ids))


def main() -> int:
    settings = get_settings()
    token = os.environ.get("TELEGRAM_BOT_TOKEN", settings.telegram_bot_token).strip()
    if not token:
        print("TELEGRAM_BOT_TOKEN is missing.", file=sys.stderr)
        return 1

    url = f"https://api.telegram.org/bot{token}/getUpdates"
    try:
        with httpx.Client(timeout=20) as client:
            response = client.get(url)
            response.raise_for_status()
    except Exception as exc:
        print(f"Failed to query Telegram API: {exc}", file=sys.stderr)
        return 1

    payload = response.json()
    chat_ids = _extract_chat_ids(payload)
    if not chat_ids:
        print("No chat IDs found yet. Open the bot in Telegram and send /start, then run this script again.")
        return 0

    print("Chat IDs:")
    for chat_id in chat_ids:
        print(chat_id)
    print()
    print("Copy them into backend/.env as TELEGRAM_CHAT_IDS=<id1>,<id2>")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())