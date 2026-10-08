# Nestling — context for Claude Code

Self-hosted, open-source replacement for the **Nara Baby** tracker app (which went from free to paid).
Owner: JF (github.com/jfchenier). Built from his reverse-engineered Nara API:
https://github.com/jfchenier/nara-baby-tracker-api (Python wrapper around Nara's Firebase backend).

## Status (2026-10-08)

- The whole server was written in a cloud session that **could not reach crates.io**, so it has
  **never been compiled or tested**. First job: `cargo build`, `cargo test`, fix compile errors
  and failing tests. Expect a handful of small type/borrow errors.
- Code was hand-reviewed; the likely-fragile spots are listed under "Watch out for".

## Decisions already made (don't revisit without asking)

- Order of work: **server API first**, then a **web app (PWA)**, then a **native mobile app**.
- Server in **Rust**: axum 0.8, sqlx 0.8 (SQLite, runtime queries — no `query!` macros, so no
  DATABASE_URL needed at build time), tokio. Single binary + one SQLite file.
- Hosting: **home server / NAS via Docker** (`docker compose up -d --build`).
- Multi-tenant: any number of caregivers and children. Family = sharing unit; invites by short code.
- v1 scope: feed, sleep, diaper, growth, health + Nara import. Pump/activity/milestone/note exist
  too so the Nara import loses nothing.
- API should be **friendlier than Nara's**: metric units only (mL, g, cm, °C, seconds) — clients
  convert for display using the user's `units` preference; times accepted as `"now"`, local
  (`"2026-10-08T14:30"`, interpreted in family tz) or RFC 3339; responses in family tz.
  One write per action (no Nara-style double write to `trackz` + `instreamz`).

## Layout

- `src/model.rs` — event `Details` enum (serde internally tagged by `type`, flattened into
  `EventInput`/`EventOut`) + validation.
- `src/routes/` — accounts, families (members, invites), children, events (CRUD, list, sync),
  timers (breastfeed/pump/sleep with segments; stop → event), insights (summary, trends, SSE
  stream), import (Nara).
- `src/trends.rs` — pure daily stats (day/night split 06–18 local, sleep split at midnight).
- `src/nara.rs` — Nara Firebase login/fetch + `convert()` of tracks. Quantities are
  `Num / 10^Exp` in `Unit` (same as the wrapper's trends.py).
- `migrations/0001_init.sql`, `tests/api.rs` (end-to-end with in-memory SQLite), `docs/API.md`.

## Watch out for

- axum 0.8 extractor traits use native `async fn` (no `#[async_trait]`); paths use `{id}`.
- `Option<T>` is not usable as an optional body extractor in axum 0.8 — optional bodies are read
  as `Bytes` and parsed manually (invites, timer switch/resume/stop).
- serde `flatten` + internally tagged enum on `EventInput` / `EventOut`.
- Closure coercions in `trends.rs` (`avg(&|d| ...)` with `&dyn Fn(&DayStats) -> f64`).
- Argon2 salt uses `rand::rngs::OsRng` (rand 0.8 / rand_core 0.6 to match password-hash 0.5).
- Tests use `sqlite::memory:` with `max_connections(1)` — a second connection would see an empty DB.

## Unverified assumptions about Nara data (check with a dry-run import on the real account)

- Num/Exp decoding is right for data written by the app; records written by the old Python
  wrapper may be off by 10x (its bottle/pump/growth writers used inconsistent exponents).
- Deleted tracks are assumed to carry `deleted: true` or `deleteDt`.
- `sync2` with `prevSyncKey: null` is assumed to return the full history (no pagination).
- Child names are not fetched from Nara; imported children are created as "Baby" / "Baby N".

## Roadmap (what's left)

### 1. Make the server work (next)
- [ ] `cargo build` + `cargo test` green; `cargo clippy` clean.
- [ ] Run in Docker on the home server; smoke-test with the curl tour in README.md.
- [ ] Nara import **dry run** on the real account to verify the assumptions above.

### 2. Known server gaps
- [ ] **Timer stop race:** `timers::stop` inserts the event, then deletes the timer, outside a
      transaction. Two caregivers stopping at once can create duplicate events. Do it in one
      transaction and only insert if the timer delete affected a row.
- [ ] **Offline/idempotent writes** (needed by the native app): let clients supply event ids
      (or an `Idempotency-Key`) so retried uploads don't duplicate.
- [ ] **Nara child names:** importer creates "Baby" / "Baby N"; find where Nara stores child
      profiles (names, birth dates) and import them.
- [ ] **Security basics:** rate-limit login/register; password reset without email (e.g. owner
      generates a reset code, or a CLI command on the server).
- [ ] **Data export:** download everything as CSV/JSON (today: copy the SQLite file).
- [ ] **OpenAPI spec** so the web and native clients can generate their API code.
- [ ] Optional: reminders ("no feed in 3 h"), photos on milestones, Home Assistant integration
      (`/children/{id}/summary` already works as a REST sensor).
- Note: SSE behind a reverse proxy needs response buffering disabled.

### 3. Web app (PWA), served by the server via `NESTLING_WEB_DIR`
- [ ] Nara-like home: big feed/sleep/diaper buttons with "time since", live timers
      (switch side/pause/stop), today's totals.
- [ ] Timeline with edit/delete; forms for every event type; metric/imperial display.
- [ ] Trends charts (1/7/14+ days).
- [ ] Sign-in, family invites, child switcher, settings, Nara import screen.
- [ ] Live updates via `/families/{id}/stream`; installable (manifest + service worker).

### 4. Native mobile app
- [ ] React Native or Flutter (undecided), same API.
- [ ] Adds over the PWA: offline logging + `/sync`, home-screen widgets, lock-screen live timer.
- [ ] Distribution: app stores vs TestFlight vs sideloading (undecided).
