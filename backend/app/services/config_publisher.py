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


def _pick_public_url(settings) -> Optional[str]:
    # Priority: explicit env/config -> ngrok local API -> None
    if settings.ngrok_public_url:
        return settings.ngrok_public_url.strip()
    local = _detect_ngrok_local_api()
    if local:
        return local

    # If configured, attempt to start ngrok automatically and re-check
    if getattr(settings, 'enable_auto_ngrok', False):
        try:
            from pyngrok import ngrok, conf

            if getattr(settings, 'ngrok_authtoken', ''):
                try:
                    conf.get_default().auth_token = settings.ngrok_authtoken
                except Exception:
                    pass

            # start a tunnel to port 8000 (http)
            t = ngrok.connect(8000, bind_tls=True)
            public_url = t.public_url if hasattr(t, 'public_url') else str(t)
            if public_url:
                return public_url
        except Exception as exc:
            logger.debug('auto-start ngrok failed: %s', exc)
    return None


def publish_ngrok_to_rtdb() -> None:
    settings = get_settings()
    if not settings.firebase_rtdb_url:
        logger.debug('No firebase_rtdb_url configured; skipping ngrok publish')
        return

    base = _normalize_base(settings.firebase_rtdb_url)
    if not base:
        logger.debug('Empty firebase_rtdb_url; skipping')
        return

    # Determine public URL: prefer ngrok/local API, then explicit ngrok_public_url, then local LAN IP
    public = _pick_public_url(settings)
    if not public:
        # fallback: try to compute local LAN IP
        try:
            import socket

            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            # doesn't need to be reachable
            s.connect(('8.8.8.8', 80))
            local_ip = s.getsockname()[0]
            s.close()
            public = f'http://{local_ip}:8000'
            logger.info('Falling back to local IP for public url: %s', public)
        except Exception:
            public = 'http://127.0.0.1:8000'
            logger.info('Falling back to loopback for public url: %s', public)

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
