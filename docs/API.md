# Nestling API v1

The HTTP API of the Nestling server — what the app uses, and what scripts, Home Assistant or
another client can use too.

Base URL: `http://<server>:8080/api/v1`. JSON in, JSON out.

The same API as an OpenAPI 3.0 document, for generating client code: [`openapi.yaml`](openapi.yaml),
also served by every server at `GET /api/v1/openapi.yaml`. `cargo test` fails when a route is
missing from it.

## Conventions

- **Auth:** `Authorization: Bearer <token>`. For `EventSource` (which can't set headers) use `?access_token=<token>`.
- **Times in requests:** `"now"`, a local time in the family's timezone (`"2026-10-08T14:30"`), or RFC 3339 with an offset (`"2026-10-08T14:30:00-04:00"`). Omitted `start` means now.
- **Times in responses:** RFC 3339; family data in the family's timezone, account and token times in UTC.
- **Units:** metric only — `_ml`, `_g`, `_cm`, `_c` (°C), `_seconds`. Each user has a `units` preference (`metric`/`imperial`) that clients use for display.
- **IDs:** opaque strings (time-sortable UUIDv7).
- **Errors:** `{"error": {"code": "bad_request", "message": "a diaper must be wet, dirty or dry"}}` with codes `bad_request` (400), `unauthorized` (401), `forbidden` (403), `not_found` (404), `conflict` (409), `too_many_requests` (429), `upstream_error` (502), `internal` (500). Things you don't have access to return 404.

## Accounts

| | | |
|---|---|---|
| `GET /auth/setup` | | public: `{needs_setup, open_registration}`; `needs_setup` while the server has no account |
| `POST /auth/register` | `{email, password (8+), name, units?}` | → `201 {token, user}`. Only the first account (it becomes the admin), unless `NESTLING_OPEN_REGISTRATION` is on; otherwise `403` |
| `POST /auth/login` | `{email, password}` | → `{token, user}`; a wrong email or password is `400`. After 5 failed attempts on an account, or 20 from one address (sign-ups count too), within 15 minutes: `429` until the oldest one is 15 minutes old. Behind a reverse proxy the address comes from `X-Real-IP` / `X-Forwarded-For` |
| `POST /auth/logout` | | revokes the current token |
| `GET /admin/users` | | admins: every account with `is_admin` and families |
| `POST /admin/users` | `{email, name, password, is_admin?, family_id?}` | admins: create an account (optionally added to a family as caregiver) |
| `PATCH /admin/users/{id}` | `{name?, is_admin?, password?}` | admins: a new password signs them out; the last admin can't be demoted |
| `DELETE /admin/users/{id}` | | admins: not yourself; families and their data stay |
| `GET /me` | | `{id, email, name, units, families: [{id, name, role}]}` |
| `PATCH /me` | `{name?, units?, password?, current_password?}` | changing the password signs out other sessions |
| `GET /me/tokens` | | sessions and API tokens |
| `POST /me/tokens` | `{name}` | → `{id, name, token}` long-lived API token (Home Assistant, scripts) |
| `DELETE /me/tokens/{id}` | | revoke |
| `GET /push/config` | | `{enabled: false}`, or `{enabled: true, android: {api_key, app_id, project_id, sender_id}}`: the Firebase settings the Android app registers with |
| `POST /me/push-devices` | `{token}` | this phone's Firebase token; it then gets a data message whenever a family timer starts, changes or stops (`{action: "show"\|"cancel", id, title, body, running, started_at, chip, seq}`). Forgotten when the session ends |
| `DELETE /me/push-devices/{token}` | | stop notifications to that phone |

## Families and caregivers

A family holds children and their data. Everyone in the family (`owner` or `caregiver`) can read and log
everything; owners can also remove members and delete the family.

| | | |
|---|---|---|
| `GET /families` | | families with members and children |
| `POST /families` | `{name, timezone?}` (IANA, default UTC) | creator becomes owner |
| `GET /families/{id}` | | |
| `PATCH /families/{id}` | `{name?, timezone?, day_start?, day_end?}` | the timezone sets day boundaries for trends; `day_start` / `day_end` (`"HH:MM"`, default `"06:00"` / `"18:00"`) set daytime for the day/night split |
| `DELETE /families/{id}` | | owner only; deletes everything |
| `POST /families/{id}/invites` | `{role?}` (default `caregiver`) | → `{code: "K7M2QX9A", expires_at}`; valid 7 days, single use |
| `POST /invites/{code}/accept` | | join the family |
| `DELETE /families/{id}/members/{user_id}` | | owner removes someone, or anyone leaves |

## Children

| | | |
|---|---|---|
| `GET /families/{id}/children` | | |
| `POST /families/{id}/children` | `{name, birth_date: "2026-06-01", sex?: female\|male\|other}` | `birth_date` (or due date) is required |
| `GET / PATCH / DELETE /children/{id}` | | `null` clears `birth_date`/`sex` |
| `PUT /children/{id}/photo` | raw JPEG, PNG or WebP (≤ 5 MB) | profile picture; the child's `photo_version` changes (null: no photo) |
| `GET / DELETE /children/{id}/photo` | | the image (`404` without one) / remove it |

### Medicine schedules and reminders

Saved on the child: `PATCH /children/{id}` with `medicines` and/or `reminders` replaces that whole
list (the child JSON carries both).

```json
{
  "medicines": [{"name": "Acetaminophen (Tylenol)", "every_hours": 4, "max_per_day": 5,
                 "dose": 2.5, "dose_unit": "mL", "remind": true}],
  "reminders": [{"type": "feed", "after_minutes": 180}]
}
```

- A medicine's doses are the child's `health` entries with `kind: "medicine"` and the same name
  (case and extra spaces ignored). `every_hours` 0.5–168; `max_per_day` (optional, 1–24) caps the
  doses in any 24 hours; `dose`/`dose_unit` only fill the app's form. The summary says when the
  next dose is allowed.
- `reminders`: one per `type` (`feed`, `sleep`, `diaper`, `pump`), `after_minutes` 15–1440. Sleep
  counts time awake.
- Reminders and a medicine's `remind` become phone notifications only on a server with
  notifications set up (`GET /push/config` → `enabled`). Checked every minute; each one is sent
  once per entry it is about, to every phone of the family.

## Events

Every record is an event with a `type`, a `start`, an optional `end`, an optional `note`, and type-specific fields.

| | |
|---|---|
| `GET /children/{id}/events?type=feed,diaper&from=&to=&limit=100` | newest first; page back with `to=<next_to>` |
| `POST /children/{id}/events` | create → `201`; may carry its own `id` (a UUID) so a retried request doesn't log twice (the repeat answers `200` with the same event) |
| `GET /events/{id}` | |
| `PATCH /events/{id}` | send only what changes; `null` removes a field |
| `DELETE /events/{id}` | |

Response shape:

```json
{
  "id": "0199c1a2-…", "child_id": "…", "type": "feed",
  "method": "bottle", "amount_ml": 120.0, "milk": "formula",
  "start": "2026-10-08T14:30:00-04:00", "end": "2026-10-08T14:45:00-04:00", "duration_seconds": 900,
  "note": "took it all", "created_by": "<user id>", "updated_by": "<user id>",
  "created_at": "…", "updated_at": "…", "source": "nara"
}
```

### Types

| `type` | Fields |
|---|---|
| `feed` | `method`: `breast` \| `bottle` \| `combo` \| `solids`; `left_seconds`, `right_seconds`, `start_side` (`left`/`right`); `amount_ml`, `milk` (`breast_milk` \| `formula` \| `mixed`), `formula_name`; `foods` |
| `sleep` | `location`. Requires `end` (use a timer for sleep in progress) |
| `diaper` | `wet`, `dirty`, `dry`, `rash`, `blowout` (booleans); `color`: `yellow` \| `green` \| `brown` \| `black` \| `red` \| `gray`; `consistency`: `runny` \| `mushy` \| `mucousy` \| `pebbles` \| `solid` (dirty only); `potty`: `sat_dry` \| `success` \| `accident` for a potty trip instead of a diaper (`wet`/`dirty` required for `success`/`accident`, with the same details as a diaper; `sat_dry` goes with `dry`) |
| `pump` | `left_ml`, `right_ml`, `left_seconds`, `right_seconds` |
| `growth` | `weight_g`, `length_cm`, `head_cm` (at least one) |
| `health` | `kind`: `medicine` (`name`, `dose`, `dose_unit`) \| `temperature` (`temperature_c`) \| `vaccine` (`name`) \| `appointment` (`name` = doctor) \| `symptom` (`name`) |
| `activity` | `kind`: free text, e.g. `bath`, `tummy_time`, `outdoor`, `play`, `read`, `nail_trim`, `vitamin` |
| `milestone` | `name` |
| `note` | just `note` |

Examples:

```json
{"type": "feed", "method": "breast", "left_seconds": 600, "right_seconds": 420, "start_side": "left", "start": "2026-10-08T03:10"}
{"type": "feed", "method": "combo", "left_seconds": 300, "amount_ml": 60, "milk": "breast_milk"}
{"type": "sleep", "start": "2026-10-08T13:00", "end": "2026-10-08T14:20", "location": "crib"}
{"type": "diaper", "wet": true}
{"type": "health", "kind": "temperature", "temperature_c": 38.2}
{"type": "growth", "weight_g": 6400, "length_cm": 62.5}
```

## Timers

One running timer per child per kind (`breastfeed`, `pump`, `sleep`), visible to every caregiver.
Stopping a timer saves it as an event.

| | | |
|---|---|---|
| `GET /children/{id}/timers` | | running/paused timers |
| `POST /children/{id}/timers` | `{id?, kind, side?, start?}` | breastfeed side: `left`/`right` (default left); pump: `left`/`right`/`both` (default both); `start` can be in the past |
| `GET /timers/{id}` | | |
| `POST /timers/{id}/switch` | `{side?}` | change side; without a body flips left↔right; resumes if paused |
| `POST /timers/{id}/pause` | | |
| `POST /timers/{id}/resume` | `{side?}` | |
| `PATCH /timers/{id}` | `{start?, left_seconds?, right_seconds?, seconds?}` | correct a timer: move its start (the total grows or shrinks by the same amount, even while running), set the time on each side (breastfeed) or the total time (`seconds`, sleep and pump); it keeps running |
| `POST /timers/{id}/stop` | `{event_id?, end?, note?, left_ml?, right_ml?, location?}` | → `201` created event; `end` lets you trim ("fell asleep 5 min ago"); `event_id` makes a retry return the same event (`200`). Two caregivers stopping at once save one event; the second gets `404` |
| `DELETE /timers/{id}` | | discard without saving |
| `POST /events/{id}/continue` | `{timer_id?, side?}` | → `201` running timer: a saved breastfeed, pump or sleep entry goes back to being a timer (same start, same time per side) and keeps going from now on `side` (default: the last side). The entry is deleted; stopping the timer saves it again. `409` if a timer of that kind is already running; `timer_id` makes a retry return the same timer (`200`) |

Timer shape: `{id, child_id, kind, started_at, running, side, elapsed_seconds, left_seconds, right_seconds, segments: [{side, start, end}], …}`.

## Summary and trends

`GET /children/{id}/summary` — home screen / Home Assistant:

```json
{
  "child": {…},
  "medicines": [{…the schedule, "last_at": "…" | null, "next_at": "…" | null, "due": true,
                 "doses_24h": 1, "limited": false}],
  "last":  {"feed": {event}, "sleep": {event}, "diaper": {event}, "pump": null},
  "since": {"feed_seconds": 5400, "sleep_seconds": 3600, "diaper_seconds": 1200, "pump_seconds": null},
  "timers": [ … ],
  "today": { day stats, see below },
  "last_24h": { the same stats over the 24 hours up to now }
}
```

`since.sleep_seconds` is time awake since the last sleep ended (`null` while a sleep timer runs).
`medicines[].next_at` is when the next dose is allowed (`null`: none given yet); `limited` means
`max_per_day` is what holds it back.

`GET /children/{id}/trends?days=7&to=2026-10-08` (1–90 days, default 7 ending today):

```json
{
  "timezone": "America/New_York", "from": "2026-10-02", "to": "2026-10-08",
  "days": [{
    "date": "2026-10-08", "complete": false,
    "feed":   {"count": 8, "breast_count": 6, "breast_seconds": 5400, "bottle_count": 2, "bottle_ml": 240, "solids_count": 0},
    "sleep":  {"total_seconds": 50400, "day_seconds": 14400, "night_seconds": 36000, "nap_count": 3, "longest_seconds": 18000},
    "diaper": {"count": 7, "wet": 6, "dirty": 3, "day_count": 4, "night_count": 3, "potty_count": 0, "potty_success": 0, "potty_accidents": 0},
    "pump":   {"count": 1, "total_ml": 150, "total_seconds": 900}
  }],
  "averages": {"days": 6, "feeds_per_day": 8.2, "sleep_seconds_per_day": 51000, "feed_interval_seconds": 10200,
               "wake_window_seconds": 5400, "avg_nap_seconds": 4100, "avg_bottle_ml": 115, …},
  "previous": { same keys as averages } | null
}
```

Days are calendar days in the family timezone; daytime is the family's `day_start`–`day_end` (06:00–18:00 by default). Sleep crossing midnight is split between days.
Daily averages use complete days only.
Potty trips are counted apart from diapers (`potty_count`, `potty_success`, `potty_accidents`; averages
`potty_per_day`, `potty_success_per_day`, `potty_accidents_per_day`).
Feeds and diapers count as daytime by their start time; feed days also carry `breast_left_seconds` /
`breast_right_seconds`, their `day_…` parts and bottle amounts by milk (`breast_milk_ml`, `formula_ml`, `mixed_ml`).
`previous` holds the same `averages` for the `days` days just before `from` (for "↑ 1.1 vs last week"), or
`null` when nothing was logged then.

## Live updates and sync

- `GET /families/{id}/stream` — Server-Sent Events. First an `event: ready`, then one `event: change` per change:
  `{"entity": "event"|"timer"|"child"|"family"|"import", "action": "created"|"updated"|"deleted", "data": {…}}`,
  or `{"entity": "sync", "action": "applied", "data": {"events": 2, "timers": 0}}` after another device pushed
  offline changes (reload what you show).
  If the client falls behind it gets `event: resync` and should call `/sync`.
  An `event: ping` comes every 15 s: a client that hears nothing for longer should reconnect (then reload, since
  changes made while it was disconnected aren't replayed). The response carries `X-Accel-Buffering: no` so nginx
  passes events through at once; other reverse proxies need response buffering turned off for this path.
- `GET /families/{id}/sync?since=<cursor>` — `{cursor, full, children, events, timers}`. Without `since` you get
  everything; with it, only events changed since, including deletions as `{"id", "deleted": true}`. Store `cursor`
  for next time.
- `POST /families/{id}/sync` — changes made offline:
  `{"events": [{id, child_id, changed_at, deleted?, start, …event fields}], "timers": [{id, child_id, kind, changed_at, deleted?, segments: [{side, start, end}]}]}`.
  `id`s are UUIDs made on the device; `changed_at` is when the change was made there. Each record is settled on
  its own and answered `{id, status}`: `applied`, `conflict` (the server kept its copy) or `rejected` (invalid,
  with a `message`); the last two include `current`, the server's copy (`null` if it has none). Rules: the most
  recent change wins (a `changed_at` in the future counts as now); a deletion is final; a timer started offline
  while another device started the same kind for the same child keeps the earlier start. Pushing the same batch
  twice changes nothing.

## Export

`GET /families/{id}/export.csv` (any member) — everything for the family as CSV, one row per
record plus a `Profile` row per child, in the same layout the CSV import below reads: `Type`,
start time (local and epoch ms), caregiver names, note, time zone, `[<Type>] <field>` columns with
their units (mL, kg, cm, °C) and the `_familyKey` / `_profileKey` / `_activityKey` ids. Extra
columns carry what that layout has no place for (pumping, combo feeds, doses, vaccines,
symptoms, appointments, sleep location, notes, exact `End Date/time`). Importing an export into
another family recreates the same children and records.

## History import

Brings over the history from the baby-tracking app a family used before. Two ways in; both preview
with `dry_run`, match records on the source app's id (re-running updates instead of duplicating)
and keep the original record in each event's `raw` column. Imported events have
`"source": "nara"`.

### From a CSV export (recommended)

`POST /families/{id}/import/nara-csv?dry_run=true&child_id=<id>` with the `.csv` file exported by the
previous app as the raw request body (`content-type: text/csv`, up to 64 MB).

- Reads every type in the export: Breastfeed, Bottle Feed, Diaper, Sleep, Growth, Medical (medicines and
  temperatures; a row with both becomes two events), Routine, plus the **Profile** row (child name,
  birth date, sex). Children created by the import get that name and birth date; an existing child
  gets a missing birth date / sex filled in.
- Times come from the epoch columns (falling back to the local time + `Time Zone` columns). Units
  (ML/OZ, KG/LB, CM/IN, C/F) are converted to metric.
- Child mapping as below; for several exported children into several family children pass
  `children=<profile key>:<child id>,…`.
- Response like the account import, plus `nara_children: [{key, name, birth_date, events, child_id}]` and,
  for a dry run, `first_ms` / `last_ms` (date range).

### From the previous app's account

`POST /families/{id}/import/nara`

```json
{"email": "login@example.com", "password": "…", "dry_run": true}
```

or upload an export instead of credentials: `{"tracks": <trackz object | full sync2 response | array of tracks>}`.

- Credentials are used once to download your data and are never stored.
- Children: with one child in the family (or none — one is created per exported child), mapping is automatic.
  Otherwise pass `"child_id": "<id>"` or `"children": {"<source child key>": "<child id>"}`; the error lists the keys found.
- Re-running is safe: records are matched by their source id and updated, not duplicated.
- The original record is kept on each event (`raw` column) so conversions can be redone later.
- Skipped: running timers / unfinished sleeps, deleted records, unknown types (counted in `skipped`).

Response: `{"tracks": 2140, "imported": 2131, "updated": 0, "by_type": {"feed": 1200, …}, "skipped": {"sleep still in progress": 1}, "children_created": […]}`.

Quantities are converted from `Num/Exp/Unit` fields (value = Num ÷ 10^Exp): fl oz → mL, lb/oz → g, in → cm, °F → °C.
