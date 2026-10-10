# Nestling app (Flutter)

The Nestling client: one Flutter codebase for the **web app** (served by the Nestling server) and the
**Android app**. It talks to the server's JSON API (`/api/v1`, see [`../docs/API.md`](../docs/API.md); the
OpenAPI description is [`../docs/openapi.yaml`](../docs/openapi.yaml)).

## Look

Nestling's own "nursery garden" palette: warm oat neutrals, a eucalyptus-green accent and one soft,
earthy pastel per activity — apricot (feeds), honey (bottle), butter (pump), sage (diapers), dusk
lilac (sleep), seafoam (routine), marigold (firsts), oat (growth), moss (health). No baby pink or
baby blue. **Light and dark themes**: follows the system, or pick one under Family → Settings →
Appearance (saved on the device).

Text is the platform sans-serif (Roboto), titles and big numbers bold. Activities are shown as
filled Material icons on a colored circle (`BlobIcon`); dark mode uses darker shades of each
activity color. Colors live in
`lib/theme.dart` (`AppColors.light` / `AppColors.dark`, read in widgets with `context.pal`; each
`Kind` has a pastel and a deep tone for light backgrounds). Blob icons and form rows are in
`lib/widgets/common.dart`.

## Screens

- **Home** — running-timer banners, today's totals, then two cards per row in a fixed order
  (Feed · Sleep / Diaper · Pump / Growth · Health / Routine · Firsts). Each card shows the latest
  entry and a big value ("last side", "dirty", "1h 06m"…), or the live clock of a running timer.
  **Tap a card to log** (Feed asks Breastfeed / Bottle / Solids / Combo); the clock icon in its header
  opens its history. "Add a note" sits under the grid.
- **Timers** — breastfeed (tap Left/Right to start, switch sides, pause), sleep (with location) and pump
  (left/right/both, asks for amounts at the end). Shared live with every caregiver. While one runs you can
  correct its start time and its time (per side for breastfeeding, total for sleep/pump) with the pencils;
  ✕ closes the page and the timer keeps running, **Save** stores it, **Delete** throws it away;
  an End Time row ("Now" until set) saves it as ending earlier. The breastfeed circles show a
  "Last side" badge on the side the last feed ended on. **Continue** on a saved breastfeed, pump or
  sleep entry's edit sheet turns it back into a running timer (`POST /events/{id}/continue`).
- **Offline** — when the server can't be reached the app keeps working from the device's copy of
  the data: log, edit and delete entries, run timers, see the home cards, timeline, calendar and
  trends. The header shows "offline · N to sync"; changes are sent when the server answers again
  (checked every 10 s), and the server settles conflicts (newest change wins, deletions are final).
  Online with nothing queued, every request goes to the server as before. Family settings,
  invites, imports and accounts need the server. The web app can't reload without the server.
- **Without a server** ("Use without a server" on the sign-in screen) — for families with no home
  server: everything is saved on the phone (`LocalApi`, the same local engine as offline mode, plus
  families, babies and photos). Phones pair with a QR code (Family → Pair a phone; the other phone
  picks "Join with a pairing code") and then sync over the home Wi-Fi whenever both apps are open
  (and right away when the app comes back to the foreground): each phone sends what changed since
  the other last heard from it (per-copy change stamps, `LocalStore.stamps`), the newest change of
  each entry wins, deletions travel along, and two timers started apart keep the earlier start
  (`lib/local/merge.dart`, `lib/local/peer_sync.dart`). For phones that aren't open at the same time
  or on the same Wi-Fi, Family → Sync through Google Drive keeps one encrypted, gzipped snapshot per
  phone in a Drive folder shared by link (`lib/local/relay.dart`, `lib/local/drive_relay.dart`;
  the folder id travels in the family record). It syncs when the app opens, 30 s after a change (3 s after a timer change),
  when the app goes to the background, and every minute while on screen; only changed files are
  downloaded and a phone uploads only after something changed. Everything between phones is encrypted with the family key from the
  QR code (AES-256-GCM). Phones find each other with a UDP announcement (port 47816) or their last
  address, and listen on port 47815. Phones that were apart catch up when they meet again. Google
  Drive keeps a daily backup in the app's private Drive folder (Family → Back up to Google Drive;
  "Restore from Google Drive" when setting up a new phone). Family → Import from Nara reads Nara's
  CSV export on the phone (`lib/local/nara_csv.dart`, a port of the server's `src/nara_csv.rs`;
  event ids come from the family and Nara's id, so importing again updates and paired phones
  agree). Not available without a server: signing in to Nara for an import, CSV export, invites by
  code, API tokens, live updates across town. Pairing and Drive need
  the Android app; the web app can run serverless alone (saved in the browser).
- **Times** use a 24-hour clock; date/time rows have separate day and time pills. Durations
  past 24 h read in days ("41d 11h").
- **Forms** — a sheet with the activity's icon and title, label/value rows and a big Save button
  (medicines, activities and solid foods are picked from the child's past entries, then a common
  list, or typed in: `widgets/medicine_picker.dart`):
  breastfeeding (manual), bottle, solids, sleep, diaper (wet/dirty/dry, color, consistency, rash,
  blowout) or potty trip (sat, pee/poo in the potty, accident; on the same page), pump, growth,
  health (medicine, temperature, vaccine, symptom, appointment), activity, milestone, note. Tap any
  entry to edit or delete it.
- **Timeline** — everything, grouped by day, filter by type, infinite scroll; Summary sheet with counts per type (today / last 24 h).
- **Running-timer notifications** (Android) — while a timer runs, an ongoing notification shows it
  with a live clock that Android keeps counting with the app closed; paused timers say so; it goes
  away when the timer is saved or deleted (`lib/timer_notifications.dart`). Asked for once on
  Android 13+.
- **Calendar** — days at a glance: one column per day, 00–24 top to
  bottom, night hours shaded, a colored bar per entry as tall as its duration, a line at the
  current time. Drag sideways to scroll back through time (loads 14 days at a time, snaps to
  days), filter by activity, tap a bar to edit it.
- **Growth charts** — weight, length and head size over the WHO Child Growth Standards percentile
  curves (2nd–98th, birth to 24 months; by sex, or pick girls/boys if not set), each point's
  percentile and age, tap for details/edit. Open from the Growth card's chart icon or Trends.
  WHO tables in `lib/growth/who_lms.dart`, generated by `tool/who_tables.py`.
- **Trends** — 7/14/30-day averages (feeds, feed interval, sleep, wake window, naps, diapers, potty,
  bottle, breastfeeding, pumping) with the change since the period before, day/night splits, and
  daily charts.
- **Family** — babies (with a profile picture: tap a baby → Add a photo; cropped to a 512 px square
  before upload), caregivers, invite codes, join a family, units (metric/imperial), time zone,
  daytime hours for the day/night split (Day and night),
  history import from a previous tracker's CSV export (preview first), CSV export of everything, API token for Home
  Assistant, change password, users (admins), sign out.

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
sh tool/finish_web_build.sh    # per-build URLs so browsers don't keep an old app
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
  # or: Actions → Release → Run workflow, version = 0.2.0
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
- Logo and launcher icon: a bird on a nest of three bars, apricot and oat on eucalyptus. An
  adaptive icon (Android 8+) with a monochrome layer for Android 13+ themed icons. Shapes and
  colors live in `tool/android_icon.py` (edit, then run it from `app/`): it writes the Android
  vector drawables and the SVG masters in `assets/brand/`, from which the PNGs (web icons,
  favicon, `assets/icon.png`, `mipmap-*/` for Android < 8) are rendered.
- Plain `http://` servers on the home network are allowed (`usesCleartextTraffic`). Use HTTPS when
  the server is reachable from outside.

## Layout

```
lib/
  main.dart            app, sign-in/onboarding/main switch, bottom navigation
  state.dart           AppState: session, families, selected child, home data, live stream
  api/api.dart         JSON client + errors
  api/sync_api.dart    logging applied locally first, sent in the background; queued while offline
  local/               the device's copy (store.dart), the server's rules in Dart (domain.dart:
                       validation, timer math, daily stats) and requests answered locally (engine.dart)
  api/stream*.dart     live updates (EventSource on web, streamed HTTP elsewhere)
  models.dart          Me, Family, Child, Event, TimerModel
  format.dart          units (metric/imperial), durations, event descriptions
  theme.dart           colors, per-activity look (Kind), Material theme
  api/local_api.dart   serverless mode: the same requests answered from the device's copy
  local/peer_sync.dart, pairing.dart, relay.dart, drive_*.dart   phone-to-phone sync, Drive relay and backup
  push.dart            Firebase registration (notifications with the app closed)
  timer_notifications.dart   running-timer notification (Android)
  growth/              WHO growth tables
  screens/             home, timer, event form, timeline, summary, calendar, trends, growth chart,
                       family (+ history import, day and night, pairing), child form, users, login, onboarding
  widgets/             shared bits (badges, ticking rebuilds, chips, event row, date/time rows,
                       pickers for medicines/activities/foods, photos)
```

## Google Drive backup (serverless mode): one-time setup

The backup signs in with Google, so the Android build needs an OAuth client of your own:

1. In the [Google Cloud console](https://console.cloud.google.com/), create a project, enable the
   **Google Drive API**, and set up the OAuth consent screen (External; add the
   `.../auth/drive.appdata` scope for the backup and `.../auth/drive` for Drive sync; while in
   "Testing", add your caregivers' Google accounts as test users). Drive sync needs the full `drive`
   scope because each phone reads files the other caregiver's account wrote; Google calls it a
   restricted scope, so users see an "unverified app" screen, and a public release needs Google's
   verification and security assessment.
2. Create an OAuth client of type **Android**: package `org.nestling.nestling`, and the SHA-1 of the
   key that signs the APK (`keytool -list -v -keystore <your keystore>`).
3. Create an OAuth client of type **Web application** (no settings needed) and copy its client id.
4. Build with it: `flutter build apk --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>`
   (in CI: a `GOOGLE_SERVER_CLIENT_ID` secret passed the same way).

Without it, everything else works and the Drive rows say they aren't available.
