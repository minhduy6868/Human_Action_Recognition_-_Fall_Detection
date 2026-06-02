-- Migration: add Telegram identity fields for subscriber tracking

ALTER TABLE telegram_subscribers
    ADD COLUMN IF NOT EXISTS telegram_user_id TEXT NULL,
    ADD COLUMN IF NOT EXISTS display_name TEXT NULL;

CREATE INDEX IF NOT EXISTS idx_telegram_subscribers_user_id ON telegram_subscribers(telegram_user_id);