import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api.dart';
import 'api/stream.dart';
import 'api/sync_api.dart';
import 'format.dart';
import 'local/store.dart';
import 'models.dart';
import 'timer_notifications.dart';

/// Default server: on the web the app is usually served by the Nestling server itself.
String defaultServer() => kIsWeb && Uri.base.scheme.startsWith('http') ? Uri.base.origin : '';

/// App-wide state: session, families, the selected child and its home-screen data.
/// Refreshes itself when the family's live stream reports a change.
class AppState extends ChangeNotifier {
  AppState(this._prefs, this.store) {
    server = _prefs.getString('server') ?? defaultServer();
    themeMode = ThemeMode.values.where((m) => m.name == _prefs.getString('theme')).firstOrNull ?? ThemeMode.system;
    final token = _prefs.getString('token');
    if (server.isNotEmpty && token != null) {
      store.server ??= server;
      api = _syncApi(server, token);
    }
  }

  final SharedPreferences _prefs;

  /// This device's copy of the family's data, used while the server can't be reached.
  final LocalStore store;
  String server = '';

  /// Light / dark / follow the system; stored on this device.
  ThemeMode themeMode = ThemeMode.system;

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    _prefs.setString('theme', mode.name);
    notifyListeners();
  }

  SyncApi? api;

  /// The server can't be reached right now: changes are saved here and synced later.
  bool get offline => api?.offline ?? false;

  /// Changes made offline that the server hasn't received yet.
  int get pendingChanges => api?.pending ?? 0;

  /// A message for the user (e.g. an offline change the server didn't keep); shown once.
  String? notice;

  SyncApi _syncApi(String server, String token) => SyncApi(server, token, store)
    ..onStatus = _syncStatus
    ..onSynced = () => refreshChild().catchError((_) {});

  void _syncStatus() {
    final notices = api?.notices;
    if (notices != null && notices.isNotEmpty) {
      notice = notices.toSet().join('\n');
      notices.clear();
    }
    notifyListeners();
  }

  Me? me;
  List<Family> families = [];
  String? familyId;
  String? childId;

  /// `/children/{id}/summary` for the selected child.
  Map<String, dynamic>? summary;
  List<TimerModel> timers = [];
  List<Event> recent = [];

  /// Latest growth / health / activity / milestone entries (home cards).
  List<Event> others = [];

  /// Bumped on every change so screens with their own data (timeline, trends) can reload.
  int revision = 0;
  bool loading = false;
  String? error;
  bool live = false;

  StreamSubscription<String>? _stream;
  Timer? _reconnect;
  Timer? _debounce;

  bool get signedIn => api?.token != null;
  Units get units => Units(me?.imperial ?? false);
  Family? get family => families.where((f) => f.id == familyId).firstOrNull;
  List<Child> get children => family?.children ?? [];
  Child? get child => children.where((c) => c.id == childId).firstOrNull;

  // ---- session ----

  static String normalizeServer(String server) {
    server = server.trim().replaceAll(RegExp(r'/+$'), '');
    return server.startsWith('http') ? server : 'http://$server';
  }

  /// `{needs_setup, open_registration}` from a server (null if unreachable): a new server
  /// starts with its admin account, after that only admins create accounts.
  static Future<Map<String, dynamic>?> setupStatus(String server) async {
    if (server.trim().isEmpty) return null;
    try {
      return await Api(normalizeServer(server)).get('/auth/setup') as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> signIn(String server, String email, String password, {String? name, bool register = false}) async {
    server = normalizeServer(server);
    final a = Api(server);
    final res = register
        ? await a.post('/auth/register', {'email': email.trim(), 'password': password, 'name': name?.trim()})
        : await a.post('/auth/login', {'email': email.trim(), 'password': password});
    final user = res['user'];
    // Another account or server: this device's copy isn't theirs.
    final sameAccount = store.server == server && user is Map && store.me?['id'] == user['id'];
    if (!sameAccount) await store.clear();
    store.server = server;
    api?.close();
    api = _syncApi(server, res['token']);
    this.server = server;
    await _prefs.setString('server', server);
    await _prefs.setString('token', api!.token!);
    await load();
  }

  // Profile pictures by child id, with the version they were downloaded for.
  final Map<String, (int, Uint8List)> _photos = {};
  final Set<String> _photoLoads = {};

  /// The child's profile picture once downloaded (null: none, or not loaded yet). Downloads it
  /// on first use and again when `photo_version` changes; the old one shows meanwhile.
  Uint8List? photoFor(Child child) {
    final version = child.photoVersion, a = api;
    final cached = _photos[child.id];
    if (version == null || a == null) return null;
    if (cached?.$1 == version) return cached!.$2;
    final key = '${child.id}@$version';
    if (_photoLoads.add(key)) {
      () async {
        try {
          _photos[child.id] = (version, await a.getBytes('/children/${child.id}/photo'));
          notifyListeners();
        } catch (_) {
          // Shown as the initial; retried on the next change.
        }
      }();
    }
    return cached?.$2;
  }

  /// Signs out. [forget] also removes this device's copy of the data (kept when the session
  /// merely expired, so changes made offline still sync after signing in again).
  Future<void> signOut({bool forget = true}) async {
    try {
      await api?.post('/auth/logout');
    } catch (_) {}
    api?.close();
    if (forget) await store.clear();
    _stopStream();
    TimerNotifications.sync(const [], null);
    await _prefs.remove('token');
    api = null;
    me = null;
    families = [];
    familyId = childId = null;
    summary = null;
    timers = [];
    recent = [];
    others = [];
    notifyListeners();
  }

  // ---- loading ----

  /// Loads the account and families, then the selected child's data.
  Future<void> load() async {
    final a = api;
    if (a == null) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      me = Me(await a.get('/me'));
      families = [for (final f in (await a.get('/families'))['families'] as List) Family(f)];
      familyId = families.any((f) => f.id == familyId)
          ? familyId
          : families.where((f) => f.id == _prefs.getString('family')).firstOrNull?.id ?? families.firstOrNull?.id;
      final kids = children;
      childId = kids.any((c) => c.id == childId)
          ? childId
          : kids.where((c) => c.id == _prefs.getString('child')).firstOrNull?.id ?? kids.firstOrNull?.id;
      _startStream();
      await refreshChild(notify: false);
      // Push anything logged offline last time, and bring the local copy up to date.
      unawaited(a.sync());
    } on ApiException catch (e) {
      if (e.unauthorized) {
        await signOut(forget: false);
        return;
      }
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshChild({bool notify = true}) async {
    final a = api, id = childId;
    if (a == null || id == null) {
      summary = null;
      timers = [];
      recent = [];
      others = [];
    } else {
      final since = DateTime.now().subtract(const Duration(hours: 24));
      final results = await Future.wait([
        a.get('/children/$id/summary'),
        a.get('/children/$id/events', {'from': formatTime(since), 'limit': '200'}),
        a.get('/children/$id/events', {'type': 'growth,health,activity,milestone', 'limit': '100'}),
      ]);
      summary = results[0];
      // Keep the family's copy of this child current (name, photo changed on another device).
      final fresh = summary!['child'], kids = family?.json['children'];
      if (fresh is Map<String, dynamic> && kids is List) {
        final i = kids.indexWhere((c) => c is Map && c['id'] == fresh['id']);
        if (i >= 0) kids[i] = fresh;
      }
      timers = [for (final t in (summary!['timers'] as List)) TimerModel(t)];
      recent = [for (final e in (results[1]['events'] as List)) Event(e)];
      others = [for (final e in (results[2]['events'] as List)) Event(e)];
    }
    revision++;
    if (notify) notifyListeners();
    TimerNotifications.sync(timers, child?.name);
    unawaited(a?.pullSoon(familyId));
  }

  /// Reloads everything (families too), e.g. after a family/child change.
  Future<void> refreshAll() => load();

  void selectChild(String id) {
    final f = families.firstWhere((f) => f.children.any((c) => c.id == id), orElse: () => families.first);
    final familyChanged = f.id != familyId;
    familyId = f.id;
    childId = id;
    _prefs.setString('family', f.id);
    _prefs.setString('child', id);
    if (familyChanged) _startStream();
    notifyListeners();
    refreshChild();
  }

  Future<void> setUnits(bool imperial) async {
    me = Me(await api!.patch('/me', {'units': imperial ? 'imperial' : 'metric'}));
    revision++;
    notifyListeners();
  }

  /// Runs an API call, then refreshes the home data. Returns the call's result.
  Future<T> act<T>(Future<T> Function(Api api) call, {bool families = false}) async {
    final result = await call(api!);
    if (families) {
      await load();
    } else {
      await refreshChild();
    }
    return result;
  }

  // ---- live updates ----

  void _startStream() {
    _stopStream();
    final a = api, f = familyId;
    if (a == null || f == null) return;
    _stream = familyStream(a.server, a.token!, f).listen(
      (event) {
        if (event == 'ready') {
          a.markOnline();
          live = true;
          notifyListeners();
        } else if (event == 'change' || event == 'resync') {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 400), () {
            refreshChild().catchError((_) {});
          });
        }
      },
      onError: (_) {},
      onDone: () {
        live = false;
        notifyListeners();
        _reconnect?.cancel();
        _reconnect = Timer(const Duration(seconds: 5), _startStream);
      },
      cancelOnError: false,
    );
  }

  void _stopStream() {
    _reconnect?.cancel();
    _stream?.cancel();
    _stream = null;
    live = false;
  }

  @override
  void dispose() {
    _stopStream();
    _debounce?.cancel();
    super.dispose();
  }
}
