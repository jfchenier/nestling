# Nestling API v1

Base URL: `http://<server>:8080/api/v1`. JSON in, JSON out.

## Conventions

- **Auth:** `Authorization: Bearer <token>`. For `EventSource` (which can't set headers) use `?access_token=<token>`.
- **Times in requests:** `"now"`, a local time in the family's timezone (`"2026-10-08T14:30"`), or RFC 3339 with an offset (`"2026-10-08T14:30:00-04:00"`). Omitted `start` means now.
- **Times in responses:** RFC 3339 in the family's timezone.
- **Units:** metric only — `_ml`, `_g`, `_cm`, `_c` (°C), `_seconds`. Each user has a `units` preference (`metric`/`imperial`) that clients use for display.
- **IDs:** opaque strings (time-sortable UUIDv7).
- **Errors:** `{"error": {"code": "bad_request", "message": "a diaper must be wet, dirty or dry"}}` with codes `bad_request` (400), `unauthorized` (401), `forbidden` (403), `not_found` (404), `conflict` (409), `upstream_error` (502), `internal` (500). Things you don't have access to return 404.

## Accounts

| | | |
|---|---|---|
| `POST /auth/register` | `{email, password (8+), name, units?}` | → `201 {token, user}` |
| `POST /auth/login` | `{email, password}` | → `{token, user}` |
| `POST /auth/logout` | | revokes the current token |
| `GET /me` | | `{id, email, name, units, families: [{id, name, role}]}` |
| `PATCH /me` | `{name?, units?, password?, current_password?}` | changing the password signs out other sessions |
| `GET /me/tokens` | | sessions and API tokens |
| `POST /me/tokens` | `{name}` | → `{id, name, token}` long-lived API token (Home Assistant, scripts) |
| `DELETE /me/tokens/{id}` | | revoke |

## Families and caregivers

A family holds children and their data. Everyone in the family (`owner` or `caregiver`) can read and log
everything; owners can also remove members and delete the family.

| | | |
|---|---|---|
| `GET /families` | | families with members and children |
| `POST /families` | `{name, timezone?}` (IANA, default UTC) | creator becomes owner |
| `GET /families/{id}` | | |
| `PATCH /families/{id}` | `{name?, timezone?}` | the timezone sets day boundaries for trends |
| `DELETE /families/{id}` | | owner only; deletes everything |
| `POST /families/{id}/invites` | `{role?}` (default `caregiver`) | → `{code: "K7M2QX9A", expires_at}`; valid 7 days, single use |
| `POST /invites/{code}/accept` | | join the family |
| `DELETE /families/{id}/members/{user_id}` | | owner removes someone, or anyone leaves |

## Children

| | | |
|---|---|---|
| `GET /families/{id}/children` | | |
| `POST /families/{id}/children` | `{name, birth_date?: "2026-06-01", sex?: female\|male\|other}` | |
| `GET / PATCH / DELETE /children/{id}` | | `null` clears `birth_date`/`sex` |

## Events

Every record is an event with a `type`, a `start`, an optional `end`, an optional `note`, and type-specific fields.

| | |
|---|---|
| `GET /children/{id}/events?type=feed,diaper&from=&to=&limit=100` | newest first; page back with `to=<next_to>` |
| `POST /children/{id}/events` | create → `201` |
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
| `diaper` | `wet`, `dirty`, `dry`, `rash`, `blowout` (booleans); `color`: `yellow` \| `green` \| `brown` \| `black` \| `red` \| `gray`; `consistency`: `runny` \| `mushy` \| `mucousy` \| `pebbles` \| `solid` (dirty only) |
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
| `POST /children/{id}/timers` | `{kind, side?, start?}` | breastfeed side: `left`/`right` (default left); pump: `left`/`right`/`both` (default both); `start` can be in the past |
| `GET /timers/{id}` | | |
| `POST /timers/{id}/switch` | `{side?}` | change side; without a body flips left↔right; resumes if paused |
| `POST /timers/{id}/pause` | | |
| `POST /timers/{id}/resume` | `{side?}` | |
| `POST /timers/{id}/stop` | `{end?, note?, left_ml?, right_ml?, location?}` | → `201` created event; `end` lets you trim ("fell asleep 5 min ago") |
| `DELETE /timers/{id}` | | discard without saving |

Timer shape: `{id, child_id, kind, started_at, running, side, elapsed_seconds, left_seconds, right_seconds, segments: [{side, start, end}], …}`.

## Summary and trends

`GET /children/{id}/summary` — home screen / Home Assistant:

```json
{
  "child": {…},
  "last":  {"feed": {event}, "sleep": {event}, "diaper": {event}, "pump": null},
  "since": {"feed_seconds": 5400, "sleep_seconds": 3600, "diaper_seconds": 1200, "pump_seconds": null},
  "timers": [ … ],
  "today": { day stats, see below }
}
```

`since.sleep_seconds` is time awake since the last sleep ended (`null` while a sleep timer runs).

`GET /children/{id}/trends?days=7&to=2026-10-08` (1–90 days, default 7 ending today):

```json
{
  "timezone": "America/New_York", "from": "2026-10-02", "to": "2026-10-08",
  "days": [{
    "date": "2026-10-08", "complete": false,
    "feed":   {"count": 8, "breast_count": 6, "breast_seconds": 5400, "bottle_count": 2, "bottle_ml": 240, "solids_count": 0},
    "sleep":  {"total_seconds": 50400, "day_seconds": 14400, "night_seconds": 36000, "nap_count": 3, "longest_seconds": 18000},
    "diaper": {"count": 7, "wet": 6, "dirty": 3, "day_count": 4, "night_count": 3},
    "pump":   {"count": 1, "total_ml": 150, "total_seconds": 900}
  }],
  "averages": {"days": 6, "feeds_per_day": 8.2, "sleep_seconds_per_day": 51000, "feed_interval_seconds": 10200,
               "wake_window_seconds": 5400, "avg_nap_seconds": 4100, "avg_bottle_ml": 115, …}
}
```

Days are calendar days in the family timezone; daytime is 06:00–18:00. Sleep crossing midnight is split between days.
Daily averages use complete days only.

## Live updates and sync

- `GET /families/{id}/stream` — Server-Sent Events. First an `event: ready`, then one `event: change` per change:
  `{"entity": "event"|"timer"|"child"|"family"|"import", "action": "created"|"updated"|"deleted", "data": {…}}`.
  If the client falls behind it gets `event: resync` and should call `/sync`.
- `GET /families/{id}/sync?since=<cursor>` — `{cursor, full, children, events, timers}`. Without `since` you get
  everything; with it, only events changed since, including deletions as `{"id", "deleted": true}`. Store `cursor`
  for next time.

## Nara import

`POST /families/{id}/import/nara`

```json
{"email": "nara-login@example.com", "password": "…", "dry_run": true}
```

or upload an export instead of credentials: `{"tracks": <trackz object | full sync2 response | array of tracks>}`.

- Credentials are used once to download your data and are never stored.
- Children: with one child in the family (or none — one is created per Nara child), mapping is automatic.
  Otherwise pass `"child_id": "<id>"` or `"children": {"<nara child key>": "<child id>"}`; the error lists the Nara keys found.
- Re-running is safe: records are matched by Nara id and updated, not duplicated.
- The original Nara record is kept on each event (`raw` column) so conversions can be redone later.
- Skipped: running timers / unfinished sleeps, deleted records, unknown types (counted in `skipped`).

Response: `{"tracks": 2140, "imported": 2131, "updated": 0, "by_type": {"feed": 1200, …}, "skipped": {"sleep still in progress": 1}, "children_created": […]}`.

Units are converted from Nara's `Num/Exp/Unit` fields (value = Num ÷ 10^Exp): fl oz → mL, lb/oz → g, in → cm, °F → °C.
