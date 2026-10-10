import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api.dart';
import 'api/local_api.dart';
import 'api/stream.dart';
import 'api/sync_api.dart';
import 'format.dart';
import 'local/drive_backup.dart';
import 'local/drive_relay.dart';
import 'local/engine.dart';
import 'local/peer_sync.dart';
import 'local/store.dart';
import 'models.dart';
import 'push.dart';
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
    if (_prefs.getString('mode') == 'serverless' && store.me != null) {
      _useServerless();
    } else if (server.isNotEmpty && token != null) {
      store.server ??= server;
      api = _syncApi(server, token);
    }
    // A phone that was in the background may have lost the live connection without noticing.
    _foreground = AppLifecycleListener(onResume: _resumed);
  }

  late final AppLifecycleListener _foreground;

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

  // ---- serverless mode ----

  /// No server: everything is kept on this phone and synced with paired phones.
  bool get serverless => api is LocalApi;

  /// Syncs paired phones over Wi-Fi (serverless mode).
  PeerSync? peers;

  /// Backups to the caregiver's Google Drive (serverless mode).
  DriveBackup get drive => DriveBackup(store);

  /// Syncs through a shared Google Drive folder, for phones that aren't open at the same time
  /// or on the same Wi-Fi (serverless mode).
  DriveRelay? relay;
  Timer? _relayTimer, _relayEvery;
  bool _relayStarted = false;
  AppLifecycleListener? _lifecycle;

  void _useServerless() {
    final local = LocalApi(store);
    peers = PeerSync(store)
      ..onMerged = (() => load().catchError((_) {}))
      ..onStatus = notifyListeners;
    relay = DriveRelay(store);
    local.onChanged = (path) {
      peers?.changed();
      // Upload a little later, so a burst of changes goes up once. A timer started, switched or
      // stopped goes up quickly so the other caregivers see what's happening now.
      _relayTimer?.cancel();
      _relayTimer = Timer(Duration(seconds: path.contains('/timers') ? 3 : 30), syncRelay);
    };
    api = local;
    _relayEvery?.cancel();
    // While the app is on screen; Drive only answers with files that changed.
    _relayEvery = Timer.periodic(const Duration(minutes: 1), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) syncRelay();
    });
    _lifecycle?.dispose();
    _lifecycle = AppLifecycleListener(
      // Back in the app: catch up with the other phones right away.
      onResume: () {
        unawaited(peers?.syncAll());
        syncRelay();
      },
      // Leaving the app: send what was logged before Android stops it.
      onHide: () {
        if (_relayTimer?.isActive ?? false) syncRelay();
      },
    );
  }

  /// Syncs through Google Drive if it is on for this phone (quietly; failures show in Family).
  Future<void> syncRelay() async {
    _relayTimer?.cancel();
    final r = relay;
    if (r == null || !r.on) return;
    try {
      if (await r.run()) await load();
    } catch (_) {
      // Kept in the relay's status (Family → Sync through Google Drive).
    }
    notifyListeners();
  }

  void _stopServerless() {
    _relayTimer?.cancel();
    _relayEvery?.cancel();
    _lifecycle?.dispose();
    _lifecycle = null;
    _relayStarted = false;
    relay = null;
  }

  /// Starts serverless mode as [name]: a fresh copy on this phone, no account or server.
  Future<void> startServerless(String name) async {
    await store.clear();
    store.me = {'id': LocalEngine.newId(), 'name': name.trim(), 'email': '', 'units': 'metric', 'is_admin': false};
    await store.flush();
    await _prefs.setString('mode', 'serverless');
    _useServerless();
    await load();
  }

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
  Timer? _watchdog;

  /// The server sends a `ping` every 15 s: this long without one means the connection is dead.
  static const _silenceLimit = Duration(seconds: 40);

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

  // Photos on entries (the baby book) by event id, with the version they were downloaded for.
  final Map<String, (int, Uint8List)> _eventPhotos = {};
  final Set<String> _eventPhotoLoads = {};

  /// A memory's photo once downloaded (null: none, or not loaded yet), like [photoFor].
  Uint8List? eventPhoto(Event e) {
    final version = toInt(e['photo_version']), a = api;
    final cached = _eventPhotos[e.id];
    if (version == null || a == null) return null;
    if (cached?.$1 == version) return cached!.$2;
    if (_eventPhotoLoads.add('${e.id}@$version')) {
      () async {
        try {
          _eventPhotos[e.id] = (version, await a.getBytes('/events/${e.id}/photo'));
          notifyListeners();
        } catch (_) {
          // Not reachable now (offline, or still on its way from another phone): retried on the
          // next change.
          _eventPhotoLoads.remove('${e.id}@$version');
        }
      }();
    }
    return cached?.$2;
  }

  /// A photo this device just uploaded, so it shows without downloading it again.
  void rememberEventPhoto(Map<String, dynamic> event, Uint8List bytes) {
    final version = toInt(event['photo_version']);
    if (version != null) _eventPhotos[event['id'] as String] = (version, bytes);
  }

  /// Signs out. [forget] also removes this device's copy of the data (kept when the session
  /// merely expired, so changes made offline still sync after signing in again).
  Future<void> signOut({bool forget = true}) async {
    try {
      await api?.post('/auth/logout');
    } catch (_) {}
    api?.close();
    await peers?.stop();
    peers = null;
    _stopServerless();
    if (serverless) await _prefs.remove('mode');
    if (forget) await store.clear();
    _stopStream();
    TimerNotifications.sync(const [], null);
    await PushRegistration.unregister();
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
  /// Home-screen reminders swiped away on this device. Each key names what it was about (e.g. the
  /// feed it counted from), so the reminder comes back once that changes.
  late final Set<String> dismissed = {...?_prefs.getStringList('dismissed_reminders')};

  void dismiss(String key) {
    dismissed.add(key);
    // Only the latest ones matter: older keys are about entries long replaced.
    final keep = dismissed.toList();
    if (keep.length > 100) keep.removeRange(0, keep.length - 100);
    dismissed
      ..clear()
      ..addAll(keep);
    unawaited(_prefs.setStringList('dismissed_reminders', keep));
    notifyListeners();
  }

  /// The server sends notifications to phones (Firebase is set up on it): reminders can be used.
  bool pushEnabled = false;

  Future<void> _checkPush(Api a) async {
    try {
      final enabled = (await a.get('/push/config'))['enabled'] == true;
      if (enabled != pushEnabled) {
        pushEnabled = enabled;
        notifyListeners();
      }
    } catch (_) {
      // Offline or an older server: keep what we knew.
    }
  }

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
      _startStream(refresh: false);
      await refreshChild(notify: false);
      // Push anything logged offline last time, and bring the local copy up to date.
      unawaited(a.sync());
      if (!serverless) {
        unawaited(PushRegistration.register(a));
        unawaited(_checkPush(a));
      }
      if (serverless) {
        unawaited(peers?.start());
        unawaited(drive.backUpIfDue());
        if (!_relayStarted) {
          _relayStarted = true;
          unawaited(syncRelay());
        }
      }
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
    if (familyChanged) _startStream(refresh: false);
    notifyListeners();
    refreshChild();
  }

  Future<void> setUnits(bool imperial) async {
    me = Me(await api!.patch('/me', {'units': imperial ? 'imperial' : 'metric'}));
    revision++;
    notifyListeners();
  }

  /// Runs an API call, then refreshes the home data. Returns the call's result. Logging changes
  /// apply to this device's copy at once and reach the server in the background (see [SyncApi]).
  Future<T> act<T>(Future<T> Function(Api api) call, {bool families = false}) async {
    final T result;
    try {
      result = await call(api!);
    } on ApiException catch (e) {
      // Another caregiver changed it first (this screen was out of date): show what's there now.
      if (e.status != 404 && e.status != 409) rethrow;
      await refreshChild().catchError((_) {});
      throw _explain(e);
    }
    if (families) {
      await load();
    } else {
      await refreshChild();
    }
    return result;
  }

  /// A clearer message for a change that lost to another caregiver's.
  static ApiException _explain(ApiException e) => ApiException(e.code, SyncApi.explain(e) ?? e.message, e.status);

  // ---- live updates ----

  /// Connects to the family's live stream. [refresh]: reload once connected, since whatever
  /// changed while there was no connection was never announced (the caller reloads otherwise).
  void _startStream({bool refresh = true}) {
    _stopStream();
    final a = api, f = familyId;
    if (a == null || f == null || serverless) return;
    _stream = familyStream(a.server, a.token!, f).listen(
      (event) {
        _watchdog?.cancel();
        _watchdog = Timer(_silenceLimit, _startStream);
        if (event == 'ready') {
          a.markOnline();
          live = true;
          notifyListeners();
          if (refresh) _refreshSoon(f);
        } else if (event == 'change' || event == 'resync') {
          _refreshSoon(f);
        }
      },
      onError: (_) {},
      onDone: () {
        _watchdog?.cancel();
        live = false;
        notifyListeners();
        _reconnect?.cancel();
        _reconnect = Timer(const Duration(seconds: 5), _startStream);
      },
      cancelOnError: false,
    );
    // Nothing at all (not even `ready`) also means the connection is stuck.
    _watchdog = Timer(_silenceLimit, _startStream);
  }

  /// Reloads the home data shortly (changes often come in bursts).
  void _refreshSoon(String familyId) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final a = api;
      // With changes still queued, screens read the local copy: bring it up to date first.
      if (a != null && a.store.pendingCount > 0) await a.pullSoon(familyId);
      await refreshChild().catchError((_) {});
    });
  }

  /// Back in the foreground: reconnect (and reload) rather than trust the old connection.
  void _resumed() {
    if (api == null || familyId == null || serverless) return;
    _startStream();
  }

  void _stopStream() {
    _reconnect?.cancel();
    _watchdog?.cancel();
    _stream?.cancel();
    _stream = null;
    live = false;
  }

  @override
  void dispose() {
    _foreground.dispose();
    _stopStream();
    _debounce?.cancel();
    super.dispose();
  }
}
