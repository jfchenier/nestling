-- Phones that get notifications (Firebase Cloud Messaging), one row per app install. Tied to the
-- session that registered it, so signing out (or a revoked session) stops its notifications.
CREATE TABLE push_devices (
    fcm_token  TEXT PRIMARY KEY,
    user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_id TEXT NOT NULL REFERENCES tokens(id) ON DELETE CASCADE,
    created_at INTEGER NOT NULL
);
CREATE INDEX push_devices_user ON push_devices(user_id);
