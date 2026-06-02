-- Migration: link Telegram subscribers to real app users

ALTER TABLE telegram_subscribers
    ADD COLUMN IF NOT EXISTS user_id TEXT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_telegram_subscribers_user_id'
    ) THEN
        ALTER TABLE telegram_subscribers
            ADD CONSTRAINT fk_telegram_subscribers_user_id
            FOREIGN KEY (user_id) REFERENCES users(id)
            ON DELETE SET NULL;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_telegram_subscribers_user_id ON telegram_subscribers(user_id);