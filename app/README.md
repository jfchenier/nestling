# Nestling app (Flutter)

The Nestling client: one Flutter codebase for the **web app** (served by the Nestling server) and the
**Android app**. It talks to the server's JSON API (`/api/v1`, see [`../docs/API.md`](../docs/API.md)).

## Look

Nestling's own "nursery garden" palette: warm oat neutrals, a eucalyptus-green accent and one soft,
earthy pastel per activity — apricot (feeds), honey (bottle), butter (pump), sage (diapers), dusk
lilac (sleep), seafoam (routine), marigold (firsts), oat (growth), moss (health). No baby pink or
baby blue. **Light and dark themes**: follows the system, or pick one under Family → Settings →
Appearance (saved on the device).

Titles use [Libre Caslon Text](https://github.com/google/fonts/tree/main/ofl/librecaslontext)
(SIL Open Font License, `assets/fonts/OFL.txt`), bundled so the app works offline. Colors live in
`lib/theme.dart` (`AppColors.light` / `AppColors.dark`, read in widgets with `context.pal`; each
`Kind` has a pastel and a deep tone for light backgrounds). Blob icons and form rows are in
`lib/widgets/common.dart`.

## Screens

- **Home** — a card per activity (Feed, Pump, Diaper, Sleep, Routine, Firsts, Growth, Health): the
  latest entry, a big value on the right ("next side", "dirty", "1h 06m"…), a round **+** to log
  another and "View history". Running timers show live in their card. Today's totals on top.
- **Timers** — nursing (tap Left/Right to start, switch sides, pause), sleep (with location) and pump
  (left/right/both, asks for amounts at the end). Shared live with every caregiver. While one runs you can
  correct its start time and its time (per side for nursing, total for sleep/pump) with the pencils;
  ✕ closes the page and the timer keeps running, **Save** stores it, **Delete** throws it away;
  "Ended earlier…" trims the end.
- **Forms** — nursing (manual), bottle, solids, sleep, diaper (wet/dirty/dry, color, consistency, rash,
  blowout), pump, growth, health (medicine, temperature, vaccine, symptom, appointment), activity,
  milestone, note. Tap any entry to edit or delete it.
- **Timeline** — everything, grouped by day, filter by type, infinite scroll.
- **Trends** — 7/14/30-day averages (feeds, feed interval, sleep, wake window, naps, diapers, bottle,
  nursing, pumping) and daily charts.
- **Family** — babies, caregivers, invite codes, join a family, units (metric/imperial), time zone,
  Nara import (preview first), API token for Home Assistant, sign out.

Changes made by other caregivers appear within a second (Server-Sent Events from `/families/{id}/stream`;
the green dot on Home shows the live connection).

## Develop

Requires Flutter 3.35 or newer (tested with 3.47).

```bash
cd app
flutter pub get
flutter run -d chrome          # web, pointing at a server you enter on the sign-in screen
flutter test                   # unit tests
flutter analyze
```

When the app is served by the Nestling server it uses that server automatically. Otherwise
(Android, `flutter run`) the sign-in screen asks for the server address, e.g. `http://192.168.1.10:8080`.
The server allows cross-origin requests, so `flutter run -d chrome` works against a remote server.

## Web app

```bash
flutter build web --release --no-web-resources-cdn
# then run the server with NESTLING_WEB_DIR=app/build/web
```

`--no-web-resources-cdn` bundles the rendering engine so the app works without internet access
(e.g. on a home network). The Docker image builds and serves it automatically. It's installable as a
PWA ("Add to Home screen" / "Install app").

## Releases (GitHub Actions)

- `.github/workflows/ci.yml` — on every push/PR: `cargo test` + `clippy`, `flutter analyze`,
  `flutter test`, web build.
- `.github/workflows/release.yml` — push a tag to publish a GitHub Release with the APK, the web
  app zip and checksums:

  ```bash
  git tag v0.2.0 && git push origin v0.2.0
  ```

  The version comes from the tag (`0.2.0`), the build number from the run number. Tags with a `-`
  (`v0.2.0-beta.1`) are marked as pre-releases. "Run workflow" on the Actions tab builds an APK as a
  downloadable artifact without releasing.

**Signing key (do this once).** Android only installs an update if it's signed with the same key
as the installed app, so give CI a permanent key:

```bash
keytool -genkeypair -v -keystore nestling-upload.jks -alias upload \
  -keyalg RSA -keysize 4096 -validity 10000
base64 -w0 nestling-upload.jks > nestling-upload.jks.b64   # macOS: base64 -i nestling-upload.jks
```

Add repository secrets (Settings → Secrets and variables → Actions): `ANDROID_KEYSTORE_BASE64`
(contents of the `.b64` file), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`upload`),
`ANDROID_KEY_PASSWORD`. Keep the `.jks` and passwords somewhere safe (password manager) — losing
them means users must uninstall to get updates. Without the secrets CI signs with a throwaway
debug key and warns.

To sign local release builds with the same key, create `android/key.properties` (git-ignored):
`storeFile=/path/to/nestling-upload.jks`, `storePassword=…`, `keyAlias=upload`, `keyPassword=…`.

## Android app

Needs the Android SDK (install Android Studio, or the command-line tools, then `flutter doctor`).

```bash
flutter build apk --release     # build/app/outputs/flutter-apk/app-release.apk
flutter install                 # or copy the APK to the phone and open it
flutter build appbundle         # .aab for the Play Store
```

Notes:

- Release builds use `android/key.properties` when present (see "Signing key" above), otherwise the
  debug key.
- The application id is `org.nestling.nestling` (`android/app/build.gradle.kts`). Change it **before**
  publishing to a store; it can't change afterwards.
- Plain `http://` servers on the home network are allowed (`usesCleartextTraffic`). Use HTTPS when
  the server is reachable from outside.

## Layout

```
lib/
  main.dart            app, sign-in/onboarding/main switch, bottom navigation
  state.dart           AppState: session, families, selected child, home data, live stream
  api/api.dart         JSON client + errors
  api/stream*.dart     live updates (EventSource on web, streamed HTTP elsewhere)
  models.dart          Me, Family, Child, Event, TimerModel
  format.dart          units (metric/imperial), durations, event descriptions
  theme.dart           colors, per-activity look (Kind), Material theme
  screens/             home, timer, event form, timeline, trends, family (+ Nara import), login, onboarding
  widgets/             shared bits (badges, ticking rebuilds, chips, event row)
```
