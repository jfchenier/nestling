-- A baby's profile picture (one per child), kept in the database so backups stay one file.
CREATE TABLE child_photos (
    child_id     TEXT PRIMARY KEY REFERENCES children(id) ON DELETE CASCADE,
    content_type TEXT NOT NULL,
    data         BLOB NOT NULL,
    updated_at   INTEGER NOT NULL
);
