from __future__ import annotations

import logging
from typing import Optional

import httpx

from app.core.config import get_settings

logger = logging.getLogger(__name__)


def _normalize_base(url: str) -> str:
    if not url:
        return ""
    u = url.strip()
    if u.endswith('/'):
        return u[:-1]
    return u


def _ws_from_http(http_url: str) -> str:
    if http_url.startswith('https://'):
        return 'wss://' + http_url[len('https://'):]
    if http_url.startswith('http://'):
        return 'ws://' + http_url[len('http://'):]
    return http_url


def _detect_ngrok_local_api(timeout: float = 1.0) -> Optional[str]:
    try:
        with httpx.Client(timeout=timeout) as client:
            r = client.get('http://127.0.0.1:4040/api/tunnels')
            if r.status_code != 200:
                return None
            data = r.json()
            tunnels = data.get('tunnels') or []
            for t in tunnels:
                pub = t.get('public_url')
                if pub and pub.startswith(('http://', 'https://')):
                    return pub
    except Exception as exc:
        logger.debug('ngrok local API not available: %s', exc)
    return None


def _delete_existing_ngrok_tunnels(timeout: float = 1.5) -> None:
    """Best-effort delete all existing local ngrok tunnels.

    This helps force a new public URL on each backend startup.
    """
    try:
        with httpx.Client(timeout=timeout) as client:
            r = client.get('http://127.0.0.1:4040/api/tunnels')
            if r.status_code != 200:
                return
            data = r.json()
            tunnels = data.get('tunnels') or []
            for tunnel in tunnels:
                uri = tunnel.get('uri')  # e.g. /api/tunnels/command_line
                if not uri:
                    continue
                try:
                    client.delete(f'http://127.0.0.1:4040{uri}')
                except Exception:
                    logger.debug('Failed deleting tunnel %s', uri, exc_info=True)
    except Exception:
        logger.debug('No local ngrok API for tunnel cleanup', exc_info=True)


def _start_new_ngrok_tunnel(settings) -> Optional[str]:
    try:
        from pyngrok import conf, ngrok

        if getattr(settings, 'ngrok_authtoken', ''):
            try:
                conf.get_default().auth_token = settings.ngrok_authtoken
            except Exception:
                logger.debug('Failed to apply ngrok_authtoken from settings', exc_info=True)

        # Force new URL each backend startup:
        # 1) clear old tunnels from local ngrok API
        # 2) open a fresh tunnel
        _delete_existing_ngrok_tunnels()
        tunnel = ngrok.connect(8000, bind_tls=True)
        public_url = tunnel.public_url if hasattr(tunnel, 'public_url') else str(tunnel)
        if public_url:
            return public_url
    except Exception:
        logger.debug('Failed starting fresh ngrok tunnel', exc_info=True)
    return None


def _pick_public_url(settings) -> Optional[str]:
    # Priority: explicit env/config -> ngrok local API -> None
    if settings.ngrok_public_url:
        return settings.ngrok_public_url.strip()
    if getattr(settings, 'enable_auto_ngrok', False):
        started = _start_new_ngrok_tunnel(settings)
        if started:
            return started
    local = _detect_ngrok_local_api()
    if local:
        return local

    return None


def _is_ngrok_url_usable(public_url: str, timeout: float = 2.5) -> bool:
    """Check whether ngrok public URL is reachable and not quota-blocked.

    ngrok quota errors often return a 4xx/5xx page containing messages like
    "network bandwidth limit" or "has reached its limit".
    """
    if not public_url or "ngrok" not in public_url:
        return True
    test_url = public_url.rstrip("/") + "/health"
    try:
        with httpx.Client(timeout=timeout, follow_redirects=True) as client:
            r = client.get(test_url)
            body = (r.text or "").lower()
            if 200 <= r.status_code < 300:
                return True
            if (
                "network bandwidth limit" in body
                or "has reached its limit" in body
                or "traffic limit" in body
                or "payment required" in body
            ):
                logger.warning("ngrok appears quota-blocked at %s", test_url)
                return False
    except Exception as exc:
        # During app startup, backend may not be ready yet behind tunnel.
        # Do not force LAN fallback on transient probe failures.
        logger.info("ngrok health probe transient failure (%s): %s", test_url, exc)
        return True

    # Non-2xx without explicit quota markers can happen transiently (warmup/502).
    # Keep ngrok as primary and let clients retry/fallback if needed.
    return True


def publish_ngrok_to_rtdb() -> None:
    settings = get_settings()
    if not settings.firebase_rtdb_url:
        logger.debug('No firebase_rtdb_url configured; skipping ngrok publish')
        return

    base = _normalize_base(settings.firebase_rtdb_url)
    if not base:
        logger.debug('Empty firebase_rtdb_url; skipping')
        return

    # Determine public URL: ngrok only.
    public = _pick_public_url(settings)
    if public and not _is_ngrok_url_usable(public):
        logger.warning(
            "ngrok URL is not usable (likely quota/limit). Skip RTDB publish and let clients use LAN fallback."
        )
        public = None
    if not public:
        logger.warning('No usable ngrok URL. Skipping RTDB publish for backend endpoint config.')
        return

    # Ensure public ends without slash
    public = public.rstrip('/')
    api_base = public + '/api/v1'
    ws_url = _ws_from_http(public) + '/api/v1/ws'

    from datetime import datetime

    payload = {
        'api_base_url': api_base,
        'ws_url': ws_url,
        'mjpeg_url': api_base + '/stream/mjpeg',
        'cameras_url': api_base + '/cameras',
        'published_at': datetime.utcnow().isoformat() + 'Z',
        'host': __import__('socket').gethostname(),
        'public_url': public,
    }

    # Write to RTDB root (overwrites root) or to '/backend' path
    # If firebase_rtdb_auth_param is provided, append it (like '?auth=...')
    write_url = base
    # choose to write under /backend to avoid overwriting unrelated keys
    write_url = write_url + '/backend.json'
    if settings.firebase_rtdb_auth_param:
        write_url = write_url + settings.firebase_rtdb_auth_param

    try:
        with httpx.Client(timeout=5.0) as client:
            r = client.put(write_url, json=payload)
            if r.status_code >= 200 and r.status_code < 300:
                logger.info('Published backend config to RTDB: %s', write_url)
            else:
                logger.warning('Failed to publish RTDB config (%s): %s', r.status_code, r.text)
    except Exception as exc:
        logger.exception('Error publishing RTDB config: %s', exc)

    # Also attempt to publish google-services.json (Firebase client config) if present
    try:
        publish_local_google_services(base, settings)
    except Exception:
        logger.debug('Publish local google-services.json failed', exc_info=True)


def publish_local_google_services(rtdb_base: str, settings) -> None:
    # Look for google-services.json in the mobile Android app directory
    import json
    from pathlib import Path

    # repo root assumed two levels up from this file
    this_dir = Path(__file__).resolve().parent
    repo_root = this_dir.parents[2]
    candidate = repo_root / 'mobile' / 'android' / 'app' / 'google-services.json'
    if not candidate.exists():
        logger.debug('No local google-services.json found at %s', candidate)
        return

    try:
        content = json.loads(candidate.read_text(encoding='utf-8'))
    except Exception as exc:
        logger.warning('Failed to read google-services.json: %s', exc)
        return

    # Write to RTDB under /firebase_config.json
    write_url = rtdb_base.rstrip('/') + '/firebase_config.json'
    if settings.firebase_rtdb_auth_param:
        write_url = write_url + settings.firebase_rtdb_auth_param

    try:
        with httpx.Client(timeout=5.0) as client:
            r = client.put(write_url, json=content)
            if 200 <= r.status_code < 300:
                logger.info('Published google-services.json to RTDB: %s', write_url)
            else:
                logger.warning('Failed to publish google-services.json (%s): %s', r.status_code, r.text)
    except Exception as exc:
        logger.exception('Error publishing google-services.json to RTDB: %s', exc)


if __name__ == '__main__':
    publish_ngrok_to_rtdb()
