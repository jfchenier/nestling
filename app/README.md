# Nestling app (Flutter)

The Nestling client: one Flutter codebase for the **web app** (served by the Nestling server) and the
**Android app**. It talks to the server's JSON API (`/api/v1`, see [`../docs/API.md`](../docs/API.md)).

## Screens

- **Home** — baby's name and age, running timers, time since the last feed / sleep / diaper
  (with "Next: Left/Right" for nursing), big round buttons for every activity, today's totals, latest entries.
- **Timers** — nursing (tap L/R to start, switch sides, pause), sleep (with location) and pump
  (left/right/both, asks for amounts at the end). Shared live with every caregiver; "Ended earlier…" trims the end.
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

## Android app

Needs the Android SDK (install Android Studio, or the command-line tools, then `flutter doctor`).

```bash
flutter build apk --release     # build/app/outputs/flutter-apk/app-release.apk
flutter install                 # or copy the APK to the phone and open it
flutter build appbundle         # .aab for the Play Store
```

Notes:

- The release build is signed with the debug key so it can be sideloaded. For the Play Store, create
  an upload key and set up signing in `android/app/build.gradle.kts`
  (see <https://docs.flutter.dev/deployment/android#signing-the-app>).
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
