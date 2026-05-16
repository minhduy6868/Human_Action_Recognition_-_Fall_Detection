from __future__ import annotations

import hashlib
import logging
import secrets
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from typing import Any, Iterable

import httpx

try:
    import firebase_admin
    from firebase_admin import credentials, messaging
except Exception:  # pragma: no cover - optional dependency at runtime
    firebase_admin = None
    credentials = None
    messaging = None

from app.core.config import get_settings
from app.db.database import SessionLocal
from app.db.models import DeviceToken, NotificationLog, OtpRequest
from app.models.schemas import AlertEvent

logger = logging.getLogger(__name__)
settings = get_settings()


class NotificationService:
    def __init__(self) -> None:
        self._executor = ThreadPoolExecutor(max_workers=2)
        self._fcm_ready = False
        self._last_fall_ms = 0
        self._init_fcm()

    def handle_alerts(
        self,
        alerts: Iterable[AlertEvent],
        image_bytes: bytes | None,
        user_id: str | None = None,
        source_id: str | None = None,
    ) -> None:
        for alert in alerts:
            if alert.alert_type != "fall":
                continue
            now_ms = int(time.time() * 1000)
            if now_ms - self._last_fall_ms < settings.notification_cooldown_ms:
                continue
            self._last_fall_ms = now_ms
            self._executor.submit(self._send_fall_notification, alert, image_bytes, user_id, source_id)

    def _init_fcm(self) -> None:
        if not settings.enable_push_notifications:
            return
        if firebase_admin is None:
            logger.warning("firebase_admin not available; push notifications disabled")
            return
        if not settings.fcm_credentials_path:
            logger.warning("FCM_CREDENTIALS_PATH is empty; push notifications disabled")
            return
        try:
            if not firebase_admin._apps:
                cred = credentials.Certificate(settings.fcm_credentials_path)
                firebase_admin.initialize_app(cred)
            self._fcm_ready = True
        except Exception as exc:  # pragma: no cover - defensive logging
            logger.exception("FCM init failed: %s", exc)

    def _send_fall_notification(
        self,
        alert: AlertEvent,
        image_bytes: bytes | None,
        user_id: str | None,
        source_id: str | None,
    ) -> None:
        image_url = None
        if image_bytes:
            image_url = self._upload_image(image_bytes)

        if settings.enable_push_notifications:
            self._send_push(alert, image_url, user_id, source_id)

        if settings.enable_email_notifications:
            self._send_email(alert, image_url, user_id, source_id)

    def _upload_image(self, image_bytes: bytes) -> str | None:
        if not settings.cloudinary_cloud_name or not settings.cloudinary_upload_preset:
            logger.warning("Cloudinary config missing; skip image upload")
            return None

        upload_url = (
            f"https://api.cloudinary.com/v1_1/{settings.cloudinary_cloud_name}/image/upload"
        )
        files = {"file": ("fall.jpg", image_bytes, "image/jpeg")}
        data = {"upload_preset": settings.cloudinary_upload_preset}

        try:
            with httpx.Client(timeout=15) as client:
                response = client.post(upload_url, data=data, files=files)
            response.raise_for_status()
            payload = response.json()
            return payload.get("secure_url")
        except Exception as exc:  # pragma: no cover - defensive logging
            logger.exception("Cloudinary upload failed: %s", exc)
            return None

    def _send_push(
        self,
        alert: AlertEvent,
        image_url: str | None,
        user_id: str | None,
        source_id: str | None,
    ) -> None:
        if not self._fcm_ready or messaging is None:
            return

        tokens = self._get_active_tokens(alert, user_id=user_id, source_id=source_id)
        if not tokens and settings.fcm_topic:
            self._send_push_topic(alert, image_url)
            return
        if not tokens:
            return

        notification = messaging.Notification(
            title=alert.title or "Fall detected",
            body=alert.message or "Fall alert from AI system",
            image=image_url,
        )
        data = {
            "alert_type": alert.alert_type,
            "track_id": alert.track_id,
            "action": alert.action,
            "confidence": f"{alert.confidence:.3f}",
            "timestamp_ms": str(alert.timestamp_ms),
            "image_url": image_url or "",
        }
        message = messaging.MulticastMessage(
            tokens=tokens,
            notification=notification,
            data=data,
        )

        try:
            response = messaging.send_multicast(message)
            self._log_notification(
                alert_id=alert.alert_id,
                channel="push",
                provider="fcm",
                status=f"success:{response.success_count}",
                payload={"image_url": image_url, "tokens": len(tokens)},
            )
        except Exception as exc:  # pragma: no cover - defensive logging
            logger.exception("Push send failed: %s", exc)
            self._log_notification(
                alert_id=alert.alert_id,
                channel="push",
                provider="fcm",
                status="failed",
                error=str(exc),
                payload={"image_url": image_url, "tokens": len(tokens)},
            )

    def _send_push_topic(self, alert: AlertEvent, image_url: str | None) -> None:
        notification = messaging.Notification(
            title=alert.title or "Fall detected",
            body=alert.message or "Fall alert from AI system",
            image=image_url,
        )
        data = {
            "alert_type": alert.alert_type,
            "track_id": alert.track_id,
            "action": alert.action,
            "confidence": f"{alert.confidence:.3f}",
            "timestamp_ms": str(alert.timestamp_ms),
            "image_url": image_url or "",
        }
        message = messaging.Message(
            topic=settings.fcm_topic,
            notification=notification,
            data=data,
        )

        try:
            response = messaging.send(message)
            self._log_notification(
                alert_id=alert.alert_id,
                channel="push",
                provider="fcm",
                status="success",
                payload={"image_url": image_url, "response": response},
            )
        except Exception as exc:  # pragma: no cover - defensive logging
            logger.exception("Push topic send failed: %s", exc)
            self._log_notification(
                alert_id=alert.alert_id,
                channel="push",
                provider="fcm",
                status="failed",
                error=str(exc),
                payload={"image_url": image_url},
            )

    def _send_email(
        self,
        alert: AlertEvent,
        image_url: str | None,
        user_id: str | None,
        source_id: str | None,
    ) -> None:
        if not settings.emailjs_service_id or not settings.emailjs_template_id:
            logger.warning("EmailJS config missing; skip email send")
            return

        recipient_email = user_id if self._is_email(user_id) else None
        if not recipient_email and self._is_email(settings.seed_admin_email):
            recipient_email = settings.seed_admin_email
        if not recipient_email:
            logger.warning("EmailJS alert recipient missing or invalid; skip email send")
            return

        payload = {
            "service_id": settings.emailjs_service_id,
            "template_id": settings.emailjs_template_id,
            "user_id": settings.emailjs_public_key,
            "template_params": {
                "email": recipient_email,
                "title": alert.title,
                "message": alert.message,
                "action": alert.action,
                "confidence": f"{alert.confidence:.3f}",
                "alert_type": alert.alert_type,
                "timestamp_ms": alert.timestamp_ms,
                "image_url": image_url or "",
            },
        }
        headers = {"Origin": "http://localhost"}

        try:
            logger.info("EmailJS send payload: %s", {k: v for k, v in payload.items() if k != 'template_params' })
            logger.debug("EmailJS template_params: %s", payload.get("template_params"))
            with httpx.Client(timeout=15) as client:
                response = client.post(
                    "https://api.emailjs.com/api/v1.0/email/send", json=payload, headers=headers
                )
            response.raise_for_status()
            self._log_notification(
                alert_id=alert.alert_id,
                channel="email",
                provider="emailjs",
                status="success",
                payload={"image_url": image_url},
            )
        except Exception as exc:  # pragma: no cover - defensive logging
            # log response body when available to aid debugging (httpx.HTTPStatusError)
            try:
                body = response.text
            except Exception:
                body = None
            logger.exception("Email send failed: %s; response=%s", exc, body)
            self._log_notification(
                alert_id=alert.alert_id,
                channel="email",
                provider="emailjs",
                status="failed",
                error=str(exc),
                payload={"image_url": image_url},
            )

    def request_otp(self, email: str, purpose: str) -> dict[str, Any]:
        otp = self._generate_otp()
        logger.info("request_otp: environment=%s email=%s purpose=%s", settings.environment, email, purpose)
        otp_hash = self._hash_otp(otp)
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.otp_ttl_minutes)

        with SessionLocal() as db:
            record = OtpRequest(
                email=email,
                otp_hash=otp_hash,
                purpose=purpose,
                expires_at=expires_at,
            )
            db.add(record)
            db.commit()

        self._send_otp_email(email, otp, purpose)
        res = {"expires_in": settings.otp_ttl_minutes * 60, "otp": otp}
        return res

    def verify_otp(self, email: str, otp: str, purpose: str) -> bool:
        otp_hash = self._hash_otp(otp)
        now = datetime.now(timezone.utc)

        with SessionLocal() as db:
            record = (
                db.query(OtpRequest)
                .filter(
                    OtpRequest.email == email,
                    OtpRequest.purpose == purpose,
                    OtpRequest.used_at.is_(None),
                    OtpRequest.expires_at > now,
                )
                .order_by(OtpRequest.created_at.desc())
                .first()
            )
            if not record:
                return False
            if record.otp_hash != otp_hash:
                return False
            record.used_at = now
            db.commit()
        return True

    def _send_otp_email(self, email: str, otp: str, purpose: str) -> None:
        template_id = settings.emailjs_template_id or settings.emailjs_otp_template_id
        if not settings.emailjs_service_id or not template_id:
            logger.warning("EmailJS OTP config missing; skip OTP email")
            return

        payload = {
            "service_id": settings.emailjs_service_id,
            "template_id": template_id,
            "user_id": settings.emailjs_public_key,
            "template_params": {
                "email": email,
                "OTP": otp,
                "otp": otp,
                "purpose": purpose,
                "ttl_minutes": settings.otp_ttl_minutes,
            },
        }
        headers = {"Origin": "http://localhost"}

        try:
            logger.info("EmailJS OTP payload template_id=%s, service_id=%s", template_id, settings.emailjs_service_id)
            logger.debug("OTP template_params: %s", payload.get("template_params"))
            with httpx.Client(timeout=15) as client:
                response = client.post(
                    "https://api.emailjs.com/api/v1.0/email/send", json=payload, headers=headers
                )
            response.raise_for_status()
        except Exception as exc:  # pragma: no cover - defensive logging
            try:
                body = response.text
            except Exception:
                body = None
            logger.exception("OTP email send failed: %s; response=%s", exc, body)

    def _generate_otp(self) -> str:
        digits = "0123456789"
        return "".join(secrets.choice(digits) for _ in range(settings.otp_length))

    def _hash_otp(self, otp: str) -> str:
        raw = f"{otp}:{settings.jwt_secret}".encode("utf-8")
        return hashlib.sha256(raw).hexdigest()

    def _is_email(self, value: str | None) -> bool:
        if not value:
            return False
        text = value.strip()
        return "@" in text and "." in text.split("@")[-1]

    def _get_active_tokens(
        self,
        alert: AlertEvent,
        user_id: str | None = None,
        source_id: str | None = None,
    ) -> list[str]:
        with SessionLocal() as db:
            query = db.query(DeviceToken).filter(DeviceToken.is_active.is_(True))
            if user_id:
                query = query.filter(DeviceToken.user_id == user_id)
            if source_id:
                query = query.filter(DeviceToken.source_id == source_id)
            tokens = [row.token for row in query.all()]
        return tokens

    def _log_notification(
        self,
        alert_id: int,
        channel: str,
        provider: str,
        status: str,
        payload: dict[str, Any],
        error: str | None = None,
    ) -> None:
        try:
            with SessionLocal() as db:
                record = NotificationLog(
                    alert_id=alert_id if alert_id > 0 else None,
                    channel=channel,
                    provider=provider,
                    status=status,
                    error=error,
                    payload=payload,
                )
                db.add(record)
                db.commit()
        except Exception as exc:  # pragma: no cover - defensive logging
            logger.exception("Notification log insert failed: %s", exc)
