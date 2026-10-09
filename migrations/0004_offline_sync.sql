-- When an event was last edited on the device that edited it (epoch ms). Offline edits are
-- pushed later through `POST /families/{id}/sync`; conflicts are settled by this time
-- (last writer wins), while `updated_at` stays the time the server received the change so
-- `GET /sync?since=` cursors keep working. NULL: same as `updated_at`.
ALTER TABLE events ADD COLUMN changed_at INTEGER;
