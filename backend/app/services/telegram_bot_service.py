from __future__ import annotations

import logging
import re
import threading
import time
from dataclasses import dataclass
from datetime import datetime, timezone

import httpx
from sqlalchemy import select

from app.core.config import get_settings
from app.core.security import verify_password
from app.db.database import SessionLocal
from app.db.models import TelegramSubscriber, User

logger = logging.getLogger(__name__)
settings = get_settings()


@dataclass
class _LinkState:
    step: str = "awaiting_email"
    email: str = ""


class TelegramBotService:
    def __init__(self) -> None:
        self._thread: threading.Thread | None = None
        self._stop_event = threading.Event()
        self._offset = 0
        self._link_states: dict[str, _LinkState] = {}

    def start(self) -> None:
        if not settings.enable_telegram_notifications:
            logger.info("Telegram polling disabled by config")
            return
        if not settings.telegram_bot_token:
            logger.warning("Telegram bot token missing; polling disabled")
            return
        if self._thread and self._thread.is_alive():
            return

        self._stop_event.clear()
        self._thread = threading.Thread(target=self._run, name="telegram-bot-poller", daemon=True)
        self._thread.start()
        logger.info("Telegram polling worker started")

    def stop(self) -> None:
        self._stop_event.set()
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=2)

    def _run(self) -> None:
        base_url = f"https://api.telegram.org/bot{settings.telegram_bot_token}"
        while not self._stop_event.is_set():
            try:
                self._poll_once(base_url)
            except Exception as exc:  # pragma: no cover - defensive logging
                logger.exception("Telegram polling failed: %s", exc)
                time.sleep(2)

    def _poll_once(self, base_url: str) -> None:
        params = {"timeout": 30}
        if self._offset > 0:
            params["offset"] = self._offset

        with httpx.Client(timeout=35) as client:
            response = client.get(f"{base_url}/getUpdates", params=params)
            response.raise_for_status()

        payload = response.json()
        for update in payload.get("result", []):
            update_id = update.get("update_id")
            if isinstance(update_id, int):
                self._offset = max(self._offset, update_id + 1)

            message = update.get("message") or update.get("channel_post") or {}
            text = (message.get("text") or "").strip()
            normalized = text.lower()
            chat = message.get("chat") or {}
            from_user = message.get("from") or {}
            chat_id = chat.get("id")
            if chat_id is None:
                continue

            chat_key = str(chat_id)
            if normalized in {"/cancel", "cancel", "/unlink", "unlink", "huy", "huỷ", "hủy"}:
                self._unlink_subscriber(chat_key)
                self._link_states.pop(chat_key, None)
                self._send_message(base_url, chat_id, "Đã hủy liên kết Telegram với tài khoản hiện tại. Gõ /start để liên kết lại.")
                continue

            if normalized in {"/me", "me", "/profile", "profile"}:
                profile_message = self._build_profile_message(chat_key)
                self._send_message(base_url, chat_id, profile_message)
                continue

            if normalized in {"/start", "start"}:
                existing_user_label = self._get_linked_user_label(chat_key)
                if existing_user_label:
                    self._send_message(
                        base_url,
                        chat_id,
                        f"Telegram này đã được liên kết với {existing_user_label}. Nếu muốn đổi, gõ /unlink rồi /start lại.",
                    )
                    continue

                self._link_states[chat_key] = _LinkState(step="awaiting_email")
                self._send_message(
                    base_url,
                    chat_id,
                    "Gửi email tài khoản của bạn để liên kết Telegram này với user thật trong database. Bạn có thể gõ /cancel để hủy.",
                )
                continue

            state = self._link_states.get(chat_key)
            if state is None:
                continue

            if state.step == "awaiting_email":
                email = text.strip().lower()
                if not self._looks_like_email(email):
                    self._send_message(base_url, chat_id, "Email không hợp lệ. Vui lòng nhập lại email đăng ký.")
                    continue
                state.email = email
                state.step = "awaiting_password"
                self._link_states[chat_key] = state
                self._send_message(base_url, chat_id, "Nhập mật khẩu của tài khoản đó để xác nhận liên kết.")
                continue

            if state.step == "awaiting_password":
                password = text.strip()
                if not password:
                    self._send_message(base_url, chat_id, "Mật khẩu không được để trống. Vui lòng nhập lại.")
                    continue

                user = self._authenticate_email_password(state.email, password)
                if user is None:
                    self._send_message(
                        base_url,
                        chat_id,
                        "Sai email hoặc mật khẩu. Gõ /start để thử lại.",
                    )
                    self._link_states.pop(chat_key, None)
                    continue

                self._upsert_subscriber(
                    chat_id=chat_key,
                    user_id=user.id,
                    telegram_user_id=str(from_user.get("id")) if from_user.get("id") is not None else None,
                    display_name=self._build_display_name(user, from_user, chat),
                    username=from_user.get("username") or chat.get("username"),
                    first_name=from_user.get("first_name") or chat.get("first_name"),
                    last_name=from_user.get("last_name") or chat.get("last_name"),
                    language_code=from_user.get("language_code") if isinstance(from_user, dict) else None,
                )
                self._link_states.pop(chat_key, None)
                self._send_message(
                    base_url,
                    chat_id,
                    self._build_success_message(user),
                )

    @staticmethod
    def _looks_like_email(email: str) -> bool:
        return bool(re.match(r"^[^\s@]+@[^\s@]+\.[^\s@]+$", email))

    def _authenticate_email_password(self, email: str, password: str) -> User | None:
        with SessionLocal() as db:
            user = db.execute(select(User).where(User.email == email)).scalar_one_or_none()
            if user is None:
                return None
            if not verify_password(password, user.password_hash):
                return None
            return user

    def _get_linked_user_label(self, chat_id: str) -> str | None:
        with SessionLocal() as db:
            subscriber = db.get(TelegramSubscriber, chat_id)
            if subscriber is None or not subscriber.user_id:
                return None
            user = db.get(User, subscriber.user_id)
            if user is None:
                return subscriber.display_name or subscriber.username or subscriber.telegram_user_id
            return user.name or user.email

    def _upsert_subscriber(
        self,
        chat_id: str,
        user_id: str | None,
        telegram_user_id: str | None,
        display_name: str | None,
        username: str | None,
        first_name: str | None,
        last_name: str | None,
        language_code: str | None,
    ) -> None:
        now = datetime.now(timezone.utc)
        with SessionLocal() as db:
            subscriber = db.get(TelegramSubscriber, chat_id)
            if subscriber is None:
                subscriber = TelegramSubscriber(
                    chat_id=chat_id,
                    user_id=user_id,
                    telegram_user_id=telegram_user_id,
                    display_name=display_name,
                    username=username,
                    first_name=first_name,
                    last_name=last_name,
                    language_code=language_code,
                    is_active=True,
                    last_seen_at=now,
                )
                db.add(subscriber)
            else:
                subscriber.user_id = user_id
                subscriber.telegram_user_id = telegram_user_id
                subscriber.display_name = display_name
                subscriber.username = username
                subscriber.first_name = first_name
                subscriber.last_name = last_name
                subscriber.language_code = language_code
                subscriber.is_active = True
                subscriber.last_seen_at = now
            db.commit()

    def _unlink_subscriber(self, chat_id: str) -> None:
        now = datetime.now(timezone.utc)
        with SessionLocal() as db:
            subscriber = db.get(TelegramSubscriber, chat_id)
            if subscriber is None:
                return
            subscriber.user_id = None
            subscriber.is_active = False
            subscriber.last_seen_at = now
            db.commit()

    @staticmethod
    def _build_display_name(user: User, from_user: dict, chat: dict) -> str | None:
        if user.name:
            return user.name

        first_name = (from_user.get("first_name") or chat.get("first_name") or "").strip()
        last_name = (from_user.get("last_name") or chat.get("last_name") or "").strip()
        username = (from_user.get("username") or chat.get("username") or "").strip()

        full_name = " ".join(part for part in [first_name, last_name] if part)
        if full_name:
            return full_name
        if username:
            return f"@{username.lstrip('@')}"
        telegram_user_id = from_user.get("id")
        return f"Telegram user {telegram_user_id}" if telegram_user_id is not None else None

    @staticmethod
    def _build_success_message(user: User) -> str:
        name = user.name.strip() if user.name else "(chua dat ten)"
        role = user.role.strip() if user.role else "user"
        plan = user.plan.strip() if user.plan else "free"
        return (
            "Đã liên kết thành công, thông tin của bạn là:\n"
            f"- Name: {name}\n"
            f"- Email: {user.email}\n"
            f"- Role: {role}\n"
            f"- Plan: {plan}\n"
            "Từ giờ cảnh báo sẽ gửi tới tài khoản này."
        )

    def _build_profile_message(self, chat_id: str) -> str:
        with SessionLocal() as db:
            subscriber = db.get(TelegramSubscriber, chat_id)
            if subscriber is None or not subscriber.user_id:
                return (
                    "Bạn chưa liên kết tài khoản nào.\n"
                    "Gõ /start để bắt đầu liên kết tài khoản."
                )

            user = db.get(User, subscriber.user_id)
            if user is None:
                return (
                    "Đã tìm thấy telegram trong hệ thống nhưng không thể kết nối.\n"
                    "Gõ /unlink roi /start de lien ket lai."
                )

            name = user.name.strip() if user.name else "(chua dat ten)"
            role = user.role.strip() if user.role else "user"
            plan = user.plan.strip() if user.plan else "free"
            return (
                "Thông tin tài khoản đang liên kết:\n"
                f"- Name: {name}\n"
                f"- Email: {user.email}\n"
                f"- Role: {role}\n"
                f"- Plan: {plan}\n"
                f"- Telegram chat id: {subscriber.chat_id}"
            )

    def _send_message(self, base_url: str, chat_id: int | str, text: str) -> None:
        try:
            with httpx.Client(timeout=15) as client:
                response = client.post(
                    f"{base_url}/sendMessage",
                    data={"chat_id": chat_id, "text": text},
                )
                response.raise_for_status()
        except Exception:
            logger.exception("Failed to send Telegram message")


telegram_bot_service = TelegramBotService()
