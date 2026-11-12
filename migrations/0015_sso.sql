-- Optional single sign-on through an OpenID Connect provider (e.g. Pocket ID), see `src/sso.rs`.

-- Accounts linked to the provider's account (`sub`), so a changed email still signs in.
CREATE TABLE user_identities (
    issuer     TEXT NOT NULL,
    subject    TEXT NOT NULL,
    user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at INTEGER NOT NULL,
    PRIMARY KEY (issuer, subject)
);

-- A sign-in in progress: from `/auth/sso/start` to the provider's callback (state_hash), then
-- from the callback to the app's `/auth/sso/token` (code_hash, user_id). Ten minutes at most.
CREATE TABLE sso_logins (
    state_hash    TEXT PRIMARY KEY,
    nonce         TEXT NOT NULL,
    pkce_verifier TEXT NOT NULL,
    redirect_uri  TEXT NOT NULL, -- this server's callback, as sent to the provider
    return_to     TEXT NOT NULL, -- the app's page or link to come back to
    app_challenge TEXT NOT NULL, -- base64url(SHA-256(the app's verifier))
    code_hash     TEXT UNIQUE,
    user_id       TEXT REFERENCES users(id) ON DELETE CASCADE,
    expires_at    INTEGER NOT NULL
);
