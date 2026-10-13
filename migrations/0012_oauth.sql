-- OAuth for MCP clients (e.g. Claude): apps register themselves (`/oauth/register`), the owner
-- signs in on `/oauth/authorize` and picks a family, and `/oauth/token` turns the code into the
-- API token of a connected app (an 'integration' user) in that family.
CREATE TABLE oauth_clients (
    id            TEXT PRIMARY KEY,
    name          TEXT NOT NULL,
    redirect_uris TEXT NOT NULL, -- JSON array
    created_at    INTEGER NOT NULL,
    used_at       INTEGER          -- when a token was first given out (unused ones are pruned)
);

-- Authorization codes (only a SHA-256 hash is stored), single use, a few minutes long.
-- family_id is null while the owner still has to pick one of several families.
CREATE TABLE oauth_codes (
    code_hash      TEXT PRIMARY KEY,
    client_id      TEXT NOT NULL REFERENCES oauth_clients(id) ON DELETE CASCADE,
    user_id        TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    family_id      TEXT REFERENCES families(id) ON DELETE CASCADE,
    redirect_uri   TEXT NOT NULL,
    code_challenge TEXT NOT NULL,
    state          TEXT,
    expires_at     INTEGER NOT NULL
);
