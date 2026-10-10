# Nestling — context for Claude Code

Self-hosted, open-source replacement for the **Nara Baby** tracker app (which went from free to paid).
Built from a reverse-engineered Nara API (a Python wrapper around Nara's Firebase backend).

**Privacy:** never put the owner's name, email, the live server's domain or any other personal or
private URL in code, docs, commits or screenshots. Use `nestling.example.com` and generic wording
("the owner"). The one exception: this repository's GitHub URL and account name (e.g. the
`ghcr.io/jfchenier/nestling` registry image).

## Status (2026-10-10)

- Server: `cargo test` green (37 tests), one cosmetic clippy warning (`nara_csv.rs`, complex type).
  Runs in Docker on the owner's home server (Portainer stack from `ghcr.io/jfchenier/nestling:latest`).
  The Nara CSV import is verified on a real export; the Nara *account* import is not yet tried.
- App (`app/`, Flutter): web build tested end-to-end in headless Chromium against the real server.
  CI builds the APK for tagged GitHub Releases (v0.1.0 to v0.2.1 so far); notifications,
  serverless sync and Drive are not yet tried on real phones.

## Working agreement

- For change requests: change the code and test it (analyze, tests, browser check), then commit
  and push. **Don't** start a GitHub release or redeploy Portainer unless the owner asks for it.

## Decisions already made (don't revisit without asking)

- Order of work: **server API first**, then a **web app (PWA)**, then a **native mobile app**.
- Client: **Flutter**, one codebase for web (served by the server) and Android. Nestling's own
  airy design (the owner did *not* want a Nara copy); the one thing taken from Nara is the home **activity
  cards** — two per row, fixed order (Feed·Sleep / Diaper·Pump / Growth·Health / Routine·Firsts),
  colored header band + a labelled History button (Charts, Book), **tap the card to log** (no floating +). Timers: big
  Left/Right circles (nursing) or one big button; editable start time and durations (pencils);
  ✕ closes while the timer keeps running, Save in the top bar, Delete at the bottom. Forms:
  sheet with icon + title, label/value rows, big Save. **Own palette** ("nursery garden": oat
  neutrals, eucalyptus accent, earthy pastels per activity; **no baby pink / baby blue**, nothing
  copied from Nara). **Light + dark themes** (dark uses darker activity shades). Platform
  sans-serif, bold titles (`serifStyle()` is the historic name). Filled Material icons on colored
  circles (`BlobIcon`), no copied artwork.
- Colors: always via `context.pal` (`AppColors` theme extension) and `Kind.on(pal)` for text/marks;
  never hard-code a color in a screen.
- Server in **Rust**: axum 0.8, sqlx 0.8 (SQLite, runtime queries — no `query!` macros, so no
  DATABASE_URL needed at build time), tokio. Single binary + one SQLite file.
- Hosting: **home server / NAS via Docker** (`docker compose up -d --build`).
- Multi-tenant: any number of caregivers and children. Family = sharing unit; invites by short code.
- Accounts: the first account on a server is the **admin**; sign-up is then closed
  (`NESTLING_OPEN_REGISTRATION` default false) and admins create accounts (`/admin/users`, app:
  Settings → Users). Recovery CLI: `nestling set-password <email> <pw>`, `nestling make-admin <email>`.
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
  timers (breastfeed/pump/sleep with segments; `PATCH` corrects start/durations; stop → event;
  `POST /events/{id}/continue` turns a saved entry back into a running timer — the Continue button on an entry's edit sheet), insights (summary, trends, SSE
  stream), import (Nara), export (CSV), admin (accounts), sync (offline push).
- `src/trends.rs` — pure daily stats (day/night split by the family's `day_start`/`day_end`, 06–18 local by
  default; app: Settings → Day and night), sleep split at midnight; `previous` = the period before.
- `src/nara.rs` — Nara Firebase login/fetch + `convert()` of tracks. Quantities are
  `Num / 10^Exp` in `Unit` (same as the wrapper's trends.py).
- `src/nara_csv.rs` — Nara's CSV export (`Type`, `[<Type>] <field>` columns, `_activityKey` = same
  `t-…` id as the API). Both importers feed `routes/import.rs::apply()` (child mapping, upsert on
  `source_id`). Check against a real export with
  `NARA_CSV=export.csv cargo test real_export -- --ignored --nocapture` (never commit real exports).
- `migrations/0001_init.sql`, `tests/api.rs` (end-to-end with in-memory SQLite), `docs/API.md`.
- `docs/openapi.yaml` — OpenAPI 3.0 description of the API, built into the binary and served at
  `/api/v1/openapi.yaml`. **Any route or response change updates it and `docs/API.md` too**;
  `tests/openapi.rs` fails when a route/method in `src/routes/mod.rs` is missing from the spec (it
  doesn't check bodies, so keep schemas in step by hand).
- `app/` — Flutter client; see `app/README.md` for its layout. `AppState` (`app/lib/state.dart`)
  holds the session and home data and refreshes on SSE `change` events.
- Potty trips are `diaper` events with `potty` (`sat_dry`/`success`/`accident`; `wet`/`dirty` = pee/poo),
  counted apart from diapers in Trends. Medicines, activities and solid foods are picked from lists
  (`app/lib/widgets/medicine_picker.dart`): the child's past entries first (custom names included), then common ones.

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
- [x] `cargo build` + `cargo test` green; `cargo clippy` has one cosmetic warning (nara_csv.rs).
- [x] Run in Docker on the home server (Portainer stack, image built by `docker.yml`).
- [x] Nara CSV import verified on a real export.
- [ ] Nara **account** import dry run on the real account to verify the assumptions above.

### 2. Known server gaps
- [x] **Timer stop race:** `timers::stop` deletes the timer and saves the event in one transaction.
- [x] **Offline/idempotent writes:** clients may supply event/timer ids (`id`, stop's `event_id`);
      offline changes are pushed to `POST /families/{id}/sync` (`src/routes/sync.rs`; last writer
      wins on the device's `changed_at`, deletions final, earlier timer start wins). The app keeps a
      local copy (`app/lib/local/`) and queues changes in `SyncApi` (`app/lib/api/sync_api.dart`).
      Its Dart ports of validation/timers/trends must follow any change to the Rust rules.
      Online too, logging is applied to the local copy first (instant screen) and the same request
      goes to the server in the background, in order (`SyncApi._drain`); a refused one (e.g. timer
      already stopped on another phone) is undone from the server's copy, with a notice.
- [x] **Nara child names:** the CSV import reads the Profile row (name, birth date, sex). The
      account import still creates "Baby" / "Baby N".
- [x] **Nara CSV import** (`/import/nara-csv`, app: Settings → Import from Nara → Export file); verified
      on a real export (2,090 rows → 2,086 events, 4 empty medical rows skipped).
- [x] **Security basics:** login/register rate limits (`src/limiter.rs`, in memory). Password reset
      without email: admins set a new password, or the `set-password` CLI.
- [x] **Data export:** `GET /families/{id}/export.csv` (app: Settings → Export data), in
      the layout the CSV import reads, so it imports back without loss.
- [x] Every time in a response is RFC 3339 (family ones in family tz, account/token ones in UTC).
      Resume/switch drop a closed segment under 1 s (unless it holds the start).
- [x] **OpenAPI spec** (`docs/openapi.yaml`, served at `/api/v1/openapi.yaml`). The app's
      hand-written Dart client (`app/lib/api/`) isn't generated from it yet.
- [x] **Notifications on phones** (optional, Firebase): `src/push.rs` sends a data message per
      timer change to every registered phone of the family; `android/…/Push.kt` shows it as the
      running-timer notification with the app closed. Not tried on real phones yet. Texts are
      made on the server in step with `app/lib/timer_notifications.dart`.
- [x] **Medicine schedules + reminders** (`src/schedule.rs`, `src/reminders.rs`; Dart port
      `app/lib/local/schedule.dart`): lists saved on the child; the summary says when the next dose
      is allowed; reminders ("no feed in 3 h", "dose due") show on the app's home strip when due
      (any mode) and are pushed only when Firebase is set up (`state.push`), checked every minute,
      once per entry (`reminders_sent`). App: Settings → Medicines and reminders; home strip
      (`_ReminderStrip`, same due rule as `reminders.rs`); early-dose warning in the medicine form.
- [x] **Baby book** (the Firsts card's Book button; tapping the card adds a memory; `app/lib/screens/baby_book.dart`): milestones as a
      scrapbook with one photo each (`/events/{id}/photo`, table `event_photos`; events carry
      `photo_version`), built-in ideas of firsts plus custom ones. Serverless: `LocalStore.eventPhotos`
      (saved apart, clocks `ep:<id>`), Drive sync sends each photo once as `photo-<id>-<version>.bin`.
      Teeth chart (`app/lib/screens/teeth_chart.dart`): milestones with `tooth` = A–T (A–J upper, the
      baby's right to left; K–T lower, left to right); only "First tooth" shows as a memory card.
      Chapters (Waiting for you, Hello world, Firsts, Growing up, Celebrations) live in the app
      (`BookChapter`); a milestone's `chapter` is any short id to the server. The book's own pages
      are texts on the child (`book`, replaced whole by `PATCH /children/{id}`; CSV `[Profile] Book`).
      "Banana for scale": repeatable milestones shown as a monthly photo strip.
      Bottom tabs: Home, Timeline, Calendar, Trends, Book; Family and Settings open from Home's two top-right buttons.
- [ ] Optional: Home Assistant integration (`/children/{id}/summary` already works as a REST sensor).
- Note: SSE behind a reverse proxy needs response buffering disabled (the stream sends `X-Accel-Buffering: no`,
  which covers nginx). The app reconnects after 40 s without the 15 s `ping`, on resume, and reloads on reconnect.

### 3. App (Flutter, `app/`) — web served by the server via `NESTLING_WEB_DIR`
- [x] Nara-like home: big buttons, "time since" cards, live timers, today's totals, latest entries.
- [x] Timeline with edit/delete; forms for every event type; metric/imperial display.
- [x] Trends (7/14/30 days): averages + daily charts.
- [x] Calendar tab: week grid (days × 00–24), a bar per entry, filters, tap to edit.
- [x] Sign-in, onboarding, family invites, child switcher, settings, Nara import screen.
- [x] Live updates via `/families/{id}/stream`; installable PWA (manifest, icons).
- [x] Layout after the owner's Nara screenshots; original palette; light + dark themes.
- [x] GitHub Actions: CI (`ci.yml`), Docker image (`docker.yml`) and tag-triggered APK release
      (`release.yml`), all running.
- [x] On GitHub; releases v0.1.0 to v0.2.1.
- [ ] Check the Android signing-key secrets are set (they were lost when the repo was recreated;
      without them release APKs are debug-signed and can't update an installed copy).
- [ ] Pick the final application id (now `org.nestling.nestling`) before the first public release.

### 4. Native mobile app (Android first, same Flutter codebase)
- [x] Offline logging + `/sync`.
- [x] Serverless mode (no server): data on the phone, QR pairing + encrypted Wi-Fi sync between
      phones (only changes since the other phone's last sync, last writer wins per record), sync
      through a link-shared Google Drive folder for phones that are apart (full `drive` scope:
      restricted, needs Google verification before a public release), daily Google Drive backup. Drive needs
      a Google OAuth client (`--dart-define=GOOGLE_SERVER_CLIENT_ID`, see app/README.md) — not
      set up yet. Not yet tried on real phones. The Nara CSV import runs on the phone (`app/lib/local/nara_csv.dart`, a port
      of `src/nara_csv.rs`: keep both in step); the Nara account import still needs a server.
- [ ] Home-screen widgets.
- [ ] Distribution: Play Store vs sideloading (undecided).
