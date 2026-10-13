-- Connected apps (e.g. Home Assistant): accounts that are not a person. They have no password,
-- can't sign in, belong to one family with the role 'integration' and use one API token.
-- Removing one keeps the row so the entries it logged keep their author's name.
ALTER TABLE users ADD COLUMN kind TEXT NOT NULL DEFAULT 'person'; -- 'person' | 'integration'
