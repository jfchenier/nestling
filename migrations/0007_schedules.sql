-- Medicine schedules and reminders, kept on the child (JSON lists, see src/schedule.rs).
ALTER TABLE children ADD COLUMN medicines TEXT NOT NULL DEFAULT '[]';
ALTER TABLE children ADD COLUMN reminders TEXT NOT NULL DEFAULT '[]';

-- The last reminder sent per child and reminder, so each one goes out once: `ref_at` is the
-- entry it is about (the last feed, the next dose's due time).
CREATE TABLE reminders_sent (
    child_id TEXT NOT NULL REFERENCES children(id) ON DELETE CASCADE,
    key      TEXT NOT NULL,
    ref_at   INTEGER NOT NULL,
    PRIMARY KEY (child_id, key)
);
