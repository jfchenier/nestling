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
| `NESTLING_OPEN_REGISTRATION` | `false` | Let anyone create an account. Off: the first account (the admin) is created from the sign-in screen, then admins add accounts under Family → Users. |
| `NESTLING_WEB_DIR` | unset (`/web` in Docker) | Folder with the web app to serve at `/` |
| `RUST_LOG` | `nestling=info,tower_http=info` | Log level |

### Accounts

A new server asks for its **admin account** on the sign-in screen (the first account). After
that, sign-up is closed: admins add caregivers under **Family → Users** (optionally straight into
their family), reset forgotten passwords and make other admins. Everyone can change their own
password under Family → Account.

Locked out? From the host:

```bash
docker exec <container> nestling set-password me@example.com 'a new password'
docker exec <container> nestling make-admin me@example.com
```

Put it behind HTTPS (Caddy, Traefik, Nginx Proxy Manager, Tailscale…) before using it outside your home network.

### Deploy with Portainer (prebuilt image)

Every push to `main` publishes `ghcr.io/jfchenier/nestling:latest` (`.github/workflows/docker.yml`;
version tags add `:0.2.0`-style tags). In Portainer: **Stacks → Add stack → Web editor**, paste
[`deploy/portainer-stack.yml`](deploy/portainer-stack.yml) (port 8383 → 8080, data in the
`nestling-data` volume) and deploy. The image is private along with the repo: either make the
package public (GitHub → your profile → Packages → nestling → Package settings → Change visibility;
the code stays private) or add ghcr.io under Portainer **Registries** with a GitHub token that has
`read:packages`. To update: **Pull and redeploy** the stack.

Nginx Proxy Manager: proxy host `nestling.example.com` → `http://<server>:8383`, SSL on. Under
**Advanced**, add the lines below so live updates (Server-Sent Events) aren't buffered. The server sends
a keep-alive every 15 s, so Cloudflare's idle timeout doesn't cut the stream.

```nginx
location /api/v1/families/ {
    proxy_pass http://<server>:8383;
    proxy_http_version 1.1;
    proxy_set_header Connection "";
    proxy_buffering off;
    proxy_cache off;
    proxy_read_timeout 1h;
}
```
