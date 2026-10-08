# Nestling

A self-hosted baby tracker server, written in Rust. It's an open replacement for the Nara Baby
app's backend: feeds, sleep, diapers, pumping, growth and health, with live timers shared
between caregivers, daily trends, and a one-shot importer for your Nara history.

- **Any number of caregivers and children.** Families share data; invite people with a short code.
- **Clean JSON API.** Metric units everywhere (mL, g, cm, °C, seconds), readable times, one call per action.
- **Live timers.** Start a breastfeed on one phone, switch sides on the other.
- **Live updates.** Server-Sent Events stream of every change, plus incremental `/sync` for offline clients.
- **Trends.** Daily feed/sleep/diaper/pump totals and averages (feed interval, wake windows, naps).
- **Nara import.** Pull everything from your Nara account (or an export) and keep it.
- **Small.** One binary + one SQLite file. Runs happily on a NAS or next to Home Assistant.

The app (web + Android, built with Flutter) lives in [`app/`](app/README.md). The Docker image builds the
web app and serves it at `http://<your-server>:8080/`.

## Run it

```bash
docker compose up -d --build
# Web app at http://<your-server>:8080/, API at /api/v1, health check at /health
```

For the Android app, build the APK from [`app/`](app/README.md#android-app) and enter the server address
on the sign-in screen.

Data lives in `nestling.db` inside the `nestling-data` Docker volume. To back it up:
`docker compose stop && docker run --rm -v nestling_nestling-data:/data -v "$PWD":/backup debian cp /data/nestling.db /backup/`.

Without Docker:

```bash
cargo run --release
```

### Configuration

| Variable | Default | |
|---|---|---|
| `NESTLING_DATABASE_URL` | `sqlite://nestling.db` (`sqlite:///data/nestling.db` in Docker) | SQLite file |
| `NESTLING_BIND` | `0.0.0.0:8080` | Listen address |
| `NESTLING_OPEN_REGISTRATION` | `true` | Allow new accounts. The first account can always be created. Turn off once everyone has joined. |
| `NESTLING_WEB_DIR` | unset (`/web` in Docker) | Folder with the web app to serve at `/` |
| `RUST_LOG` | `nestling=info,tower_http=info` | Log level |

Put it behind HTTPS (Caddy, Traefik, Nginx Proxy Manager, Tailscale…) before using it outside your home network.

## Quick tour

```bash
API=http://localhost:8080/api/v1

# 1. Create an account (returns a token)
TOKEN=$(curl -s $API/auth/register -H 'content-type: application/json' \
  -d '{"email":"me@example.com","password":"a long password","name":"JF"}' | jq -r .token)
AUTH="authorization: Bearer $TOKEN"

# 2. Family + baby
FAMILY=$(curl -s $API/families -H "$AUTH" -H 'content-type: application/json' \
  -d '{"name":"Home","timezone":"America/New_York"}' | jq -r .id)
BABY=$(curl -s $API/families/$FAMILY/children -H "$AUTH" -H 'content-type: application/json' \
  -d '{"name":"Baby","birth_date":"2026-06-01"}' | jq -r .id)

# 3. Log things
curl -s $API/children/$BABY/events -H "$AUTH" -H 'content-type: application/json' \
  -d '{"type":"diaper","wet":true,"dirty":true,"color":"yellow"}'
curl -s $API/children/$BABY/events -H "$AUTH" -H 'content-type: application/json' \
  -d '{"type":"feed","method":"bottle","amount_ml":120,"milk":"formula","start":"2026-10-08T14:30"}'

# 4. Live breastfeeding timer
TIMER=$(curl -s $API/children/$BABY/timers -H "$AUTH" -H 'content-type: application/json' \
  -d '{"kind":"breastfeed","side":"left"}' | jq -r .id)
curl -s -X POST $API/timers/$TIMER/switch -H "$AUTH"   # now on the right
curl -s -X POST $API/timers/$TIMER/stop -H "$AUTH"     # saved as a feed event

# 5. Invite your partner (they POST /invites/<code>/accept after registering)
curl -s -X POST $API/families/$FAMILY/invites -H "$AUTH"

# 6. Bring your Nara history over
curl -s $API/families/$FAMILY/import/nara -H "$AUTH" -H 'content-type: application/json' \
  -d '{"email":"nara-login@example.com","password":"...","dry_run":true}'
```

Full reference: [docs/API.md](docs/API.md).

## Home Assistant

Create a long-lived token with `POST /api/v1/me/tokens {"name":"Home Assistant"}` and use
`GET /children/{id}/summary` as a REST sensor (time since last feed, diaper, sleep; running timers;
today's totals), and `POST /children/{id}/events` or the timer endpoints from scripts.

## Development

```bash
cargo test          # unit + end-to-end API tests (in-memory SQLite)
cargo run

cd app && flutter test && flutter build web --release --no-web-resources-cdn
NESTLING_WEB_DIR=app/build/web cargo run   # server + web app on :8080
```

Layout: `src/model.rs` (event types and validation), `src/routes/` (HTTP handlers),
`src/trends.rs` (statistics), `src/nara.rs` (Nara conversion), `migrations/` (schema), `app/` (Flutter client).

## Credits

The Nara importer is based on the reverse-engineering work in
[jfchenier/nara-baby-tracker-api](https://github.com/jfchenier/nara-baby-tracker-api).
Not affiliated with Nara Baby.
