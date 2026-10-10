-- A photo on an entry (the baby book's memories), one per event, kept in the database like the
-- profile pictures. Removed with the entry.
CREATE TABLE event_photos (
    event_id     TEXT PRIMARY KEY REFERENCES events(id) ON DELETE CASCADE,
    content_type TEXT NOT NULL,
    data         BLOB NOT NULL,
    updated_at   INTEGER NOT NULL
);
