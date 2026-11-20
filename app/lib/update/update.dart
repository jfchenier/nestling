import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'platform_io.dart' if (dart.library.js_interop) 'platform_web.dart' as platform;

/// The app's version: set at build time (`--dart-define=NESTLING_VERSION=…`; release.yml and the
/// Docker image do), empty for a local build.
const appVersion = String.fromEnvironment('NESTLING_VERSION');

/// Where releases are published (release.yml): the Android app looks there for a newer APK.
const releasesApi = 'https://api.github.com/repos/jfchenier/nestling/releases/latest';

/// A published release: its version, its APK and the checksums file next to it.
class Release {
  const Release({required this.version, required this.apk, this.checksums, required this.apkName, this.page});

  final String version;
  final Uri apk;
  final String apkName;
  final Uri? checksums;
  final Uri? page;

  /// GitHub's `releases/latest` answer (drafts and pre-releases are never "latest"); null when it
  /// has no APK.
  static Release? fromGitHub(Map<String, dynamic> json) {
    final tag = json['tag_name'];
    if (tag is! String || json['draft'] == true || json['prerelease'] == true) return null;
    final assets = [for (final a in json['assets'] as List? ?? const []) if (a is Map) a];
    Uri? url(Map a) => a['browser_download_url'] is String ? Uri.tryParse(a['browser_download_url'] as String) : null;
    final apk = assets.where((a) => '${a['name']}'.endsWith('.apk') && url(a) != null).firstOrNull;
    if (apk == null) return null;
    final sums = assets.where((a) => a['name'] == 'SHA256SUMS.txt').firstOrNull;
    return Release(
      version: tag.startsWith('v') ? tag.substring(1) : tag,
      apk: url(apk)!,
      apkName: '${apk['name']}',
      checksums: sums == null ? null : url(sums),
      page: json['html_url'] is String ? Uri.tryParse(json['html_url'] as String) : null,
    );
  }
}

/// Compares two versions like `0.9.1`, `v1.0.0` or `0.9.0-dev.12` (semantic versioning: numbers
/// part by part, then a version without a `-suffix` comes after the same one with it).
int compareVersions(String a, String b) {
  (List<String>, String?) split(String v) {
    v = v.trim();
    if (v.startsWith('v')) v = v.substring(1);
    v = v.split('+').first;
    final dash = v.indexOf('-');
    return dash < 0 ? (v.split('.'), null) : (v.substring(0, dash).split('.'), v.substring(dash + 1));
  }

  int parts(List<String> x, List<String> y) {
    for (var i = 0; i < x.length || i < y.length; i++) {
      if (i >= x.length) return -1;
      if (i >= y.length) return 1;
      final m = int.tryParse(x[i]), n = int.tryParse(y[i]);
      final c = m != null && n != null
          ? m.compareTo(n)
          : (m != null ? -1 : (n != null ? 1 : x[i].compareTo(y[i])));
      if (c != 0) return c;
    }
    return 0;
  }

  final (ca, pa) = split(a);
  final (cb, pb) = split(b);
  final width = ca.length > cb.length ? ca.length : cb.length;
  List<String> pad(List<String> c) => [...c, for (var i = c.length; i < width; i++) '0'];
  final core = parts(pad(ca), pad(cb));
  if (core != 0) return core;
  if (pa == null || pb == null) return pa == pb ? 0 : (pa == null ? 1 : -1);
  return parts(pa.split('.'), pb.split('.'));
}

/// The SHA-256 listed for [name] in a `sha256sum` file (release.yml's SHA256SUMS.txt).
String? checksumFor(String sums, String name) {
  for (final line in const LineSplitter().convert(sums)) {
    final m = RegExp(r'^([0-9a-fA-F]{64})\s+\*?(.+)$').firstMatch(line.trim());
    if (m != null && m.group(2)!.trim() == name) return m.group(1)!.toLowerCase();
  }
  return null;
}

/// Keeping the app up to date.
///
/// Android: looks for a newer release on GitHub (on start and back in the foreground, at most every
/// an hour; Settings → About turns it off), downloads its APK, checks it against the release's
/// SHA256SUMS.txt and hands it to Android's installer, which keeps the data (same signing key).
///
/// Web: the page is served by the server, so a redeployed server brings a new app; when the
/// server's version (`/auth/setup`) differs from this page's, the home screen offers a reload.
class AppUpdates extends ChangeNotifier {
  AppUpdates(this._prefs, {http.Client? client, String? current}) : _client = client, current = current ?? appVersion;

  final SharedPreferences _prefs;
  final http.Client? _client;

  /// This app's version (empty for a development build, which never looks for updates).
  final String current;

  /// A new release shows within the hour (a longer wait hid a release published just after the
  /// app's last look); GitHub allows 60 unauthenticated requests an hour per address.
  static const _checkEvery = Duration(hours: 1);

  /// Phones only (the web app follows the server); a development build has no version to compare.
  bool get supported => platform.canInstall && current.isNotEmpty;

  /// Settings → About → Check for updates (on by default).
  bool get enabled => _prefs.getBool('update_check') ?? true;

  Future<void> setEnabled(bool value) async {
    await _prefs.setBool('update_check', value);
    if (value) {
      unawaited(check(force: true));
    } else {
      available = null;
    }
    notifyListeners();
  }

  /// A newer release than this app, unless it was put off ([dismiss]).
  Release? available;

  /// The newest release seen by the last check (also when it is this version).
  Release? latest;

  /// A check is running (Settings → About → Check now).
  bool checking = false;

  /// Downloading the APK: 0–1, or -1 while the size is unknown; null when not downloading.
  double? progress;

  /// Why the last check or update failed (shown in About and on the home strip).
  String? error;

  /// Android first needs "Install unknown apps" turned on for Nestling: the home strip says so.
  bool needsPermission = false;

  DateTime? get lastCheck => DateTime.tryParse(_prefs.getString('update_checked_at') ?? '');

  /// Looks for a newer release. [force]: even if the last check was less than an hour ago (and
  /// shows a release that was put off).
  Future<Release?> check({bool force = false}) async {
    if (!supported || checking || (!enabled && !force)) return available;
    final last = lastCheck;
    if (!force && last != null && DateTime.now().difference(last) < _checkEvery) {
      // Checked recently (maybe in an earlier run): keep what that check found.
      final saved = _prefs.getString('update_latest');
      if (latest == null && saved != null) _found(Release.fromGitHub(jsonDecode(saved) as Map<String, dynamic>), force: false);
      return available;
    }
    checking = true;
    error = null;
    notifyListeners();
    final client = _client ?? http.Client();
    try {
      final res = await client
          .get(Uri.parse(releasesApi), headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw Exception('GitHub answered ${res.statusCode}');
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      await _prefs.setString('update_checked_at', DateTime.now().toUtc().toIso8601String());
      await _prefs.setString('update_latest', jsonEncode(_slim(json)));
      _found(Release.fromGitHub(json), force: force);
      unawaited(platform.cleanUp(keep: available?.apkName));
    } catch (e) {
      error = '$e';
      debugPrint('update: $e');
    } finally {
      if (_client == null) client.close();
      checking = false;
      notifyListeners();
    }
    return available;
  }

  /// Only what [Release.fromGitHub] reads (the full answer lists every change of the release).
  static Map<String, dynamic> _slim(Map<String, dynamic> json) => {
    for (final k in ['tag_name', 'draft', 'prerelease', 'html_url']) k: json[k],
    'assets': [
      for (final a in json['assets'] as List? ?? const [])
        if (a is Map) {'name': a['name'], 'browser_download_url': a['browser_download_url']},
    ],
  };

  void _found(Release? r, {required bool force}) {
    latest = r;
    final newer = r != null && compareVersions(r.version, current) > 0;
    if (force && newer) _prefs.remove('update_skipped');
    available = newer && _prefs.getString('update_skipped') != r.version ? r : null;
    notifyListeners();
  }

  /// "Not now": hides this version's notice on this device (a later version shows again).
  void dismiss() {
    final r = available;
    if (r == null) return;
    _prefs.setString('update_skipped', r.version);
    available = null;
    error = null;
    needsPermission = false;
    notifyListeners();
  }

  /// Downloads the new APK (checked against the release's checksum) and opens Android's
  /// installer. Asks for "Install unknown apps" first when Android needs it.
  Future<void> install() async {
    final r = available;
    if (r == null || progress != null) return;
    error = null;
    needsPermission = false;
    if (!await platform.mayInstall()) {
      needsPermission = true;
      notifyListeners();
      await platform.askToInstall();
      return;
    }
    progress = -1;
    notifyListeners();
    final client = _client ?? http.Client();
    try {
      String? sum;
      if (r.checksums case final sums?) {
        final res = await client.get(sums).timeout(const Duration(seconds: 30));
        if (res.statusCode == 200) sum = checksumFor(res.body, r.apkName);
      }
      final path = await platform.download(client, r.apk, r.apkName, sha256: sum, onProgress: (p) {
        progress = p;
        notifyListeners();
      });
      progress = null;
      notifyListeners();
      if (!await platform.openInstaller(path)) needsPermission = true;
    } catch (e) {
      error = '$e';
      debugPrint('update: $e');
    } finally {
      if (_client == null) client.close();
      progress = null;
      notifyListeners();
    }
  }

  // ---- web ----

  /// The server's version, from `/auth/setup` (web: a different one means the server was updated).
  String? serverVersion;

  /// Web: the server now runs another version than this page. Not offered again for a version a
  /// reload didn't bring (e.g. an app built apart from its server).
  bool get reloadOffered =>
      platform.canReload &&
      current.isNotEmpty &&
      serverVersion != null &&
      serverVersion!.isNotEmpty &&
      serverVersion != current &&
      _prefs.getString('update_reloaded_for') != serverVersion;

  void sawServerVersion(Object? version) {
    if (version is! String || version == serverVersion) return;
    serverVersion = version;
    notifyListeners();
  }

  /// Web: loads the new app (the page's own files are never cached, see tool/finish_web_build.sh).
  Future<void> reload() async {
    if (serverVersion != null) await _prefs.setString('update_reloaded_for', serverVersion!);
    platform.reloadPage();
  }
}
