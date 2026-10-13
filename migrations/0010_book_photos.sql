-- Photos on the baby book's own pages (a face on the family tree…), by a short key of the app's
-- like the page texts in `children.book`. Kept in the database like the other photos.
CREATE TABLE book_photos (
    child_id     TEXT NOT NULL REFERENCES children(id) ON DELETE CASCADE,
    key          TEXT NOT NULL,
    content_type TEXT NOT NULL,
    data         BLOB NOT NULL,
    updated_at   INTEGER NOT NULL,
    PRIMARY KEY (child_id, key)
);
