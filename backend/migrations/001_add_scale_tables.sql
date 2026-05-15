-- Migration: add scale-ready tables and link detection logs to model versions

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

ALTER TABLE detection_logs
    ADD COLUMN IF NOT EXISTS model_version_id INTEGER NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_detection_logs_model_version_id'
    ) THEN
        ALTER TABLE detection_logs
            ADD CONSTRAINT fk_detection_logs_model_version_id
            FOREIGN KEY (model_version_id) REFERENCES model_versions(id)
            ON DELETE SET NULL;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_detection_logs_model_version_id ON detection_logs(model_version_id);
