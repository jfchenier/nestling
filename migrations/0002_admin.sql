-- Server admins create accounts (registration is closed after the first one).
ALTER TABLE users ADD COLUMN is_admin INTEGER NOT NULL DEFAULT 0;

-- Servers that already have accounts: the oldest one becomes the admin.
UPDATE users SET is_admin = 1 WHERE id = (SELECT id FROM users ORDER BY created_at, rowid LIMIT 1);
