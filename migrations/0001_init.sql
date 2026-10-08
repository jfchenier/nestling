-- All timestamps are Unix epoch milliseconds (UTC).

CREATE TABLE users (
    id            TEXT PRIMARY KEY,
    email         TEXT NOT NULL UNIQUE COLLATE NOCASE,
    name          TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    units         TEXT NOT NULL DEFAULT 'metric',
    created_at    INTEGER NOT NULL
);

-- Session tokens and long-lived API tokens (e.g. for Home Assistant).
-- Only a SHA-256 hash of the token is stored.
CREATE TABLE tokens (
    id           TEXT PRIMARY KEY,
    token_hash   TEXT NOT NULL UNIQUE,
    user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name         TEXT NOT NULL,
    kind         TEXT NOT NULL DEFAULT 'session', -- 'session' | 'api'
    created_at   INTEGER NOT NULL,
    last_used_at INTEGER
);

CREATE TABLE families (
    id         TEXT PRIMARY KEY,
    name       TEXT NOT NULL,
    timezone   TEXT NOT NULL DEFAULT 'UTC',
    created_at INTEGER NOT NULL
);

CREATE TABLE memberships (
    family_id  TEXT NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role       TEXT NOT NULL, -- 'owner' | 'caregiver'
    created_at INTEGER NOT NULL,
    PRIMARY KEY (family_id, user_id)
);

CREATE TABLE invites (
    code       TEXT PRIMARY KEY,
    family_id  TEXT NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    role       TEXT NOT NULL,
    created_by TEXT NOT NULL,
    expires_at INTEGER NOT NULL
);

CREATE TABLE children (
    id         TEXT PRIMARY KEY,
    family_id  TEXT NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    name       TEXT NOT NULL,
    birth_date TEXT,
    sex        TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
CREATE INDEX children_family ON children(family_id);

CREATE TABLE events (
    id         TEXT PRIMARY KEY,
    family_id  TEXT NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    child_id   TEXT NOT NULL REFERENCES children(id) ON DELETE CASCADE,
    type       TEXT NOT NULL,
    start_at   INTEGER NOT NULL,
    end_at     INTEGER,
    data       TEXT NOT NULL,          -- JSON of the type-specific details (includes "type")
    note       TEXT,
    created_by TEXT,
    updated_by TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,                -- soft delete so clients can sync deletions
    source     TEXT,                   -- e.g. 'nara' for imported records
    source_id  TEXT,                   -- id in the source system
    raw        TEXT                    -- original payload from the source system
);
CREATE INDEX events_child_start ON events(child_id, start_at);
CREATE INDEX events_family_updated ON events(family_id, updated_at);
CREATE UNIQUE INDEX events_source ON events(family_id, source, source_id);

-- Live timers (breastfeeding, pumping, sleep). A timer becomes an event when stopped.
CREATE TABLE timers (
    id         TEXT PRIMARY KEY,
    family_id  TEXT NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    child_id   TEXT NOT NULL REFERENCES children(id) ON DELETE CASCADE,
    kind       TEXT NOT NULL,          -- 'breastfeed' | 'pump' | 'sleep'
    segments   TEXT NOT NULL,          -- JSON array of {side, start, end}
    created_by TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
CREATE UNIQUE INDEX timers_child_kind ON timers(child_id, kind);
