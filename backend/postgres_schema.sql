-- Postgres schema for video-ai-detect
-- Database: "video-ai-detect"

CREATE DATABASE "video-ai-detect";

\c "video-ai-detect";

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    email TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL DEFAULT '',
    password_hash TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'user',
    plan TEXT NOT NULL DEFAULT 'free',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id SERIAL PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT UNIQUE NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens(user_id);

CREATE TABLE IF NOT EXISTS source_connections (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    source_type TEXT NOT NULL,
    source_url TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ NULL
);

CREATE INDEX IF NOT EXISTS idx_sources_user_id ON source_connections(user_id);

CREATE TABLE IF NOT EXISTS alerts (
    id SERIAL PRIMARY KEY,
    alert_type TEXT NOT NULL,
    severity TEXT NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    timestamp_ms BIGINT NOT NULL,
    track_id TEXT NOT NULL,
    action TEXT NOT NULL,
    confidence DOUBLE PRECISION NOT NULL DEFAULT 0,
    source TEXT NOT NULL DEFAULT 'backend',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS summary_reports (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    window_ms BIGINT NOT NULL,
    generated_at_ms BIGINT NOT NULL,
    insight JSONB NOT NULL DEFAULT '{}'::jsonb,
    alert_counts JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS model_versions (
    id SERIAL PRIMARY KEY,
    model_name TEXT NOT NULL,
    version TEXT NOT NULL,
    checksum TEXT NULL,
    config JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (model_name, version)
);

CREATE INDEX IF NOT EXISTS idx_model_versions_name ON model_versions(model_name);

CREATE TABLE IF NOT EXISTS fall_events (
    id SERIAL PRIMARY KEY,
    timestamp_ms BIGINT NOT NULL,
    source_id TEXT NULL,
    user_id TEXT NULL,
    track_id TEXT NOT NULL,
    action TEXT NOT NULL DEFAULT 'unknown',
    confidence DOUBLE PRECISION NOT NULL DEFAULT 0,
    detected BOOLEAN NOT NULL DEFAULT TRUE,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    model_version_id INTEGER NULL REFERENCES model_versions(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fall_events_timestamp_ms ON fall_events(timestamp_ms DESC);
CREATE INDEX IF NOT EXISTS idx_fall_events_track_id ON fall_events(track_id);
CREATE INDEX IF NOT EXISTS idx_fall_events_source_id ON fall_events(source_id);
CREATE INDEX IF NOT EXISTS idx_fall_events_user_id ON fall_events(user_id);

CREATE TABLE IF NOT EXISTS camera_metrics (
    id SERIAL PRIMARY KEY,
    source_id TEXT NOT NULL,
    user_id TEXT NULL,
    window_ms BIGINT NOT NULL,
    window_start_ms BIGINT NOT NULL,
    fps DOUBLE PRECISION NOT NULL DEFAULT 0,
    latency_ms DOUBLE PRECISION NOT NULL DEFAULT 0,
    dropped_frames INTEGER NOT NULL DEFAULT 0,
    processed_frames INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_camera_metrics_source_id ON camera_metrics(source_id);
CREATE INDEX IF NOT EXISTS idx_camera_metrics_window_start_ms ON camera_metrics(window_start_ms DESC);
CREATE INDEX IF NOT EXISTS idx_camera_metrics_user_id ON camera_metrics(user_id);

CREATE TABLE IF NOT EXISTS device_tokens (
    id SERIAL PRIMARY KEY,
    user_id TEXT NULL REFERENCES users(id) ON DELETE SET NULL,
    source_id TEXT NULL,
    token TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'unknown',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_seen_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (token)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON device_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_device_tokens_source_id ON device_tokens(source_id);
CREATE INDEX IF NOT EXISTS idx_device_tokens_active ON device_tokens(is_active);

CREATE TABLE IF NOT EXISTS notification_logs (
    id SERIAL PRIMARY KEY,
    alert_id INTEGER NULL REFERENCES alerts(id) ON DELETE SET NULL,
    channel TEXT NOT NULL,
    provider TEXT NOT NULL DEFAULT 'unknown',
    status TEXT NOT NULL DEFAULT 'pending',
    error TEXT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notification_logs_alert_id ON notification_logs(alert_id);
CREATE INDEX IF NOT EXISTS idx_notification_logs_channel ON notification_logs(channel);

CREATE TABLE IF NOT EXISTS otp_requests (
    id SERIAL PRIMARY KEY,
    email TEXT NOT NULL,
    otp_hash TEXT NOT NULL,
    purpose TEXT NOT NULL DEFAULT 'verify',
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_otp_requests_email ON otp_requests(email);
CREATE INDEX IF NOT EXISTS idx_otp_requests_expires_at ON otp_requests(expires_at);

CREATE TABLE IF NOT EXISTS detection_logs (
    id SERIAL PRIMARY KEY,
    timestamp_ms BIGINT NOT NULL,
    track_id TEXT NOT NULL DEFAULT '0',
    action TEXT NOT NULL DEFAULT 'unknown',
    confidence DOUBLE PRECISION NOT NULL DEFAULT 0,
    fall BOOLEAN NOT NULL DEFAULT FALSE,
    fall_confidence DOUBLE PRECISION NOT NULL DEFAULT 0,
    people_count INTEGER NOT NULL DEFAULT 0,
    objects_count INTEGER NOT NULL DEFAULT 0,
    people_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    objects_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    source_id TEXT NULL,
    user_id TEXT NULL,
    model_version_id INTEGER NULL REFERENCES model_versions(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_detection_logs_timestamp_ms ON detection_logs(timestamp_ms DESC);
CREATE INDEX IF NOT EXISTS idx_detection_logs_track_id ON detection_logs(track_id);
CREATE INDEX IF NOT EXISTS idx_detection_logs_source_id ON detection_logs(source_id);
CREATE INDEX IF NOT EXISTS idx_detection_logs_user_id ON detection_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_detection_logs_model_version_id ON detection_logs(model_version_id);

CREATE TABLE IF NOT EXISTS chat_history (
    id SERIAL PRIMARY KEY,
    user_id TEXT NULL,
    source_id TEXT NULL,
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    intent TEXT NOT NULL,
    window_ms BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chat_history_created_at ON chat_history(created_at DESC);
