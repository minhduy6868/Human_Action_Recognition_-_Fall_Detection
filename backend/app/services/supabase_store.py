import json
import logging
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from app.core.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


class SupabaseStore:
    def __init__(self) -> None:
        self._base_url = settings.supabase_url.rstrip("/")
        self._api_key = (settings.supabase_service_key or settings.supabase_key).strip()
        self._enabled = bool(self._base_url and self._api_key)

    def enabled(self) -> bool:
        return self._enabled

    def insert_alert(self, payload: dict[str, Any]) -> bool:
        return self._insert(settings.supabase_alerts_table, payload)

    def insert_report(self, payload: dict[str, Any]) -> bool:
        return self._insert(settings.supabase_reports_table, payload)

    def _insert(self, table: str, payload: dict[str, Any]) -> bool:
        if not self._enabled:
            return False

        url = f"{self._base_url}/rest/v1/{table}"
        body = json.dumps(payload).encode("utf-8")
        request = Request(
            url,
            data=body,
            method="POST",
            headers={
                "apikey": self._api_key,
                "Authorization": f"Bearer {self._api_key}",
                "Content-Type": "application/json",
                "Prefer": "return=minimal",
            },
        )

        try:
            with urlopen(request, timeout=4) as response:
                response.read()
            return True
        except HTTPError as exc:
            logger.warning("Supabase insert failed for %s: %s", table, exc)
        except URLError as exc:
            logger.warning("Supabase connection failed for %s: %s", table, exc)
        except Exception as exc:  # pragma: no cover - defensive logging
            logger.exception("Unexpected Supabase error for %s: %s", table, exc)
        return False
