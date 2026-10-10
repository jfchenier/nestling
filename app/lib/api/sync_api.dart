import 'dart:async';
import 'dart:convert';

import '../local/engine.dart';
import '../local/store.dart';
import 'api.dart';

/// The API client: answers logging from this device's copy, with offline support.
///
/// Online, a logging change (event or timer) is applied to the [LocalStore] right away, so the
/// screen updates without waiting, and the same request is sent to the server in the background
/// (in order, see [_drain]). If the server refuses it (e.g. the timer was already stopped on
/// another phone), the local copy goes back to the server's and the user gets a notice. Other
/// requests go to the server as before; answers are copied into the store, and the family's
/// changes are pulled in the background (`GET /families/{id}/sync`).
///
/// When the server can't be reached, logging carries on against the local copy ([LocalEngine])
/// and every change is queued. Once the server answers again the queue is pushed
/// (`POST /families/{id}/sync`), where conflicts are settled, then the latest data is pulled.
/// While changes are queued or on their way, reads stay local so they show them.
class SyncApi extends Api {
  SyncApi(super.server, super.token, this.store, [super.client]) : engine = LocalEngine(store);

  final LocalStore store;
  final LocalEngine engine;

  /// The server couldn't be reached on the last try; retried every [retryEvery].
  bool offline = false;
  static Duration retryEvery = const Duration(seconds: 10);

  /// Offline state or the number of queued changes changed.
  void Function()? onStatus;

  /// A sync finished: data from other caregivers may have arrived.
  void Function()? onSynced;

  /// Messages for the user about changes the server didn't take as they were.
  final List<String> notices = [];

  /// Changes waiting for the server to be reachable (not the ones on their way right now).
  int get pending => store.pending.keys.where((k) => !_inFlight.contains(k)).length;

  /// Changes applied here while online, being sent to the server in order.
  final List<_Outgoing> _outbox = [];
  Set<String> get _inFlight => {for (final o in _outbox) ...o.keys.keys};
  bool _sending = false;

  Timer? _retry;
  bool _syncing = false, _again = false;

  @override
  Future<dynamic> send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    List<int>? raw,
    String? contentType,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final local = raw == null && store.hasData && LocalEngine.handles(method, path);
    // Once the family's data is here (first pull done) and nothing older is waiting for a sync.
    if (local && method != 'GET' && !offline && store.cursors.isNotEmpty && store.pending.keys.every(_inFlight.contains)) {
      final res = _applyNow(method, path, query, body);
      if (res != null) return res.$1;
    }
    if (local && (offline || store.pendingCount > 0)) return _local(method, path, query, body);
    final sent = local ? _withIds(method, path, body) : body;
    try {
      final res = await super.send(
        method,
        path,
        body: sent,
        query: query,
        raw: raw,
        contentType: contentType,
        timeout: local ? const Duration(seconds: 12) : timeout,
      );
      markOnline();
      _mirror(method, path, res);
      return res;
    } on ApiException catch (e) {
      if (!unreachable(e)) rethrow;
      _markOffline();
      if (local) return _local(method, path, query, sent);
      throw ApiException('offline', 'You\'re offline. This needs a connection to the server (${Uri.parse(server).host}).');
    }
  }

  /// No answer, or a reverse proxy saying the server behind it is down.
  static bool unreachable(ApiException e) => e.code == 'network' || const [502, 503, 504].contains(e.status);

  dynamic _local(String method, String path, Map<String, String>? query, Object? body) {
    final copy = body == null ? null : jsonDecode(jsonEncode(body));
    final res = engine.handle(method, path, query: query, body: copy);
    if (method != 'GET') {
      onStatus?.call();
      unawaited(sync());
    }
    return res;
  }

  /// Applies a write to the local copy and queues the same request for the server; null when the
  /// local copy can't take it (an entry or timer it doesn't have, or out of date: 404 / 409), so
  /// the server answers instead.
  (dynamic,)? _applyNow(String method, String path, Map<String, String>? query, Object? body) {
    final sent = _withIds(method, path, body);
    final before = {for (final MapEntry(:key, :value) in store.pending.entries) key: value.seq};
    final dynamic res;
    try {
      res = engine.handle(method, path, query: query, body: sent == null ? null : jsonDecode(jsonEncode(sent)));
    } on ApiException catch (e) {
      if ((e.status == 404 || e.status == 409) && _outbox.isEmpty) return null;
      rethrow;
    }
    final keys = {
      for (final MapEntry(:key, :value) in store.pending.entries)
        if (before[key] != value.seq) key: value.seq,
    };
    _outbox.add(_Outgoing(method, path, query, sent, keys));
    unawaited(_drain());
    return (res,);
  }

  /// Sends the [_outbox] in order. Sent: the local changes are confirmed. Refused: the local copy
  /// goes back to the server's, with a notice. Server unreachable: the changes stay queued and
  /// go with the next sync.
  Future<void> _drain() async {
    if (_sending) return;
    _sending = true;
    var refused = false;
    try {
      while (_outbox.isNotEmpty) {
        final o = _outbox.first;
        try {
          final res = await super.send(o.method, o.path, body: o.body, query: o.query, timeout: const Duration(seconds: 12));
          _outbox.removeAt(0);
          _confirm(o);
          _mirror(o.method, o.path, res);
        } on ApiException catch (e) {
          if (!const [400, 403, 404, 409, 422].contains(e.status)) {
            // Kept as pending changes: pushed by the next sync.
            _outbox.clear();
            if (unreachable(e)) _markOffline();
            break;
          }
          _outbox.removeAt(0);
          _confirm(o);
          refused = true;
          notices.add(explain(e) ?? 'A change couldn\'t be saved: ${e.message}');
          await _restore(o);
        }
      }
    } finally {
      _sending = false;
      onStatus?.call();
      if (refused) onSynced?.call();
    }
  }

  /// The server has this request's changes (or refused them): they aren't pending any more,
  /// unless changed again since.
  void _confirm(_Outgoing o) {
    for (final MapEntry(:key, value: seq) in o.keys.entries) {
      if (store.pending[key]?.seq == seq) store.pending.remove(key);
    }
    store.save();
  }

  /// Puts back the server's copy of what a refused request changed here.
  Future<void> _restore(_Outgoing o) async {
    await Future.wait([
      for (final key in o.keys.keys)
        if (!store.pending.containsKey(key))
          () async {
            final id = key.substring(2), event = key.startsWith('e:');
            try {
              final current = await super.send('GET', '/${event ? 'events' : 'timers'}/$id', timeout: const Duration(seconds: 12));
              event ? store.putEvent(current) : store.putTimer(current);
            } on ApiException catch (e) {
              if (e.status != 404) return;
              event ? store.events.remove(id) : store.timers.remove(id);
            }
          }(),
    ]);
    store.save();
  }

  /// A clearer message for a change that lost to another caregiver's (null: none).
  static String? explain(ApiException e) => switch (e.message) {
    'timer not found' => 'This timer was already stopped on another phone. The screen is up to date now.',
    'event not found' => 'This entry was deleted on another phone.',
    final m when m.contains('timer is already running') => 'Someone already started this timer. It\'s shown now.',
    _ => null,
  };

  /// Ids chosen here, so a request retried (or replayed from the queue) never logs twice.
  Object? _withIds(String method, String path, Object? body) {
    if (method != 'POST') return body;
    final b = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    if (RegExp(r'^/children/[^/]+/(events|timers)$').hasMatch(path)) {
      b['id'] ??= LocalEngine.newId();
    } else if (RegExp(r'^/timers/[^/]+/stop$').hasMatch(path)) {
      b['event_id'] ??= LocalEngine.newId();
    } else if (RegExp(r'^/events/[^/]+/continue$').hasMatch(path)) {
      b['timer_id'] ??= LocalEngine.newId();
    } else {
      return body;
    }
    return b;
  }

  /// Keeps the local copy current with what the server answered.
  void _mirror(String method, String path, dynamic res) {
    final seg = path.split('/').where((s) => s.isNotEmpty).toList();
    switch ((method, seg)) {
      case ('GET', ['me']) || ('PATCH', ['me']):
        store.me = res;
      case ('GET', ['families']):
        store.families = [for (final f in res['families'] as List) jsonDecode(jsonEncode(f)) as Map<String, dynamic>];
      case ('GET', ['children', final id, 'summary']):
        if (res['child'] case final Map<String, dynamic> child) store.putChild(jsonDecode(jsonEncode(child)));
        store.replaceTimers({id}, res['timers'] as List);
      case ('GET', ['children', _, 'events']):
        for (final e in res['events'] as List) {
          store.putEvent(e);
        }
      case ('GET', ['children', final id, 'timers']):
        store.replaceTimers({id}, res['timers'] as List);
      case ('POST', ['children', _, 'events']) || ('PATCH', ['events', _]):
        store.putEvent(res);
      case ('DELETE', ['events', final id]):
        store.removeEvent(id);
      case ('POST', ['children', _, 'timers']) || ('PATCH', ['timers', _]) || ('POST', ['timers', _, 'pause' || 'resume' || 'switch']):
        store.putTimer(res);
      case ('POST', ['timers', final id, 'stop']):
        store.putEvent(res);
        store.removeTimer(id);
      case ('DELETE', ['timers', final id]):
        store.removeTimer(id);
      case ('POST', ['events', final id, 'continue']):
        store.removeEvent(id);
        store.putTimer(res);
      default:
        return;
    }
    store.save();
  }

  // ---- connectivity ----

  /// The server answered: push anything queued.
  void markOnline() {
    if (!offline) return;
    offline = false;
    _retry?.cancel();
    _retry = null;
    onStatus?.call();
    unawaited(sync());
  }

  void _markOffline() {
    if (offline) return;
    offline = true;
    onStatus?.call();
    _retry?.cancel();
    _retry = Timer.periodic(retryEvery, (_) async {
      if (await Api.ping(server, client)) markOnline();
    });
  }

  // ---- sync ----

  /// Pushes queued changes, then pulls every family's latest data. Safe to call any time.
  Future<void> sync() async {
    if (offline || token == null) return;
    if (_syncing) {
      _again = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _again = false;
        try {
          await _push();
        } on ApiException catch (e) {
          if (unreachable(e)) rethrow;
          // Kept for the next try (next change, reconnection or app start); still pull below.
          notices.add('Changes made offline couldn\'t be sent yet: ${e.message}');
        }
        for (final f in store.families.map((f) => f['id'] as String).toList()) {
          await pull(f);
        }
      } while (_again);
      onSynced?.call();
    } on ApiException catch (e) {
      if (unreachable(e)) _markOffline();
    } finally {
      _syncing = false;
      onStatus?.call();
    }
  }

  String _iso(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();

  Future<void> _push() async {
    // Changes on their way in the outbox are sent there.
    final snapshot = Map.of(store.pending)..removeWhere((k, _) => _inFlight.contains(k));
    if (snapshot.isEmpty) return;
    final batches = <String, ({List<Map<String, dynamic>> events, List<Map<String, dynamic>> timers})>{};
    for (final MapEntry(:key, value: p) in snapshot.entries) {
      final id = key.substring(2);
      final isEvent = key.startsWith('e:');
      final childId = isEvent ? (store.events[id]?['child_id'] as String?) : store.timers[id]?.childId;
      final family = childId == null ? null : store.familyOfChild(childId)?['id'] as String?;
      if (family == null) {
        // Its child or family is gone: nothing to sync it to.
        store.pending.remove(key);
        continue;
      }
      final batch = batches.putIfAbsent(family, () => (events: [], timers: []));
      final changedAt = _iso(p.changedAt);
      if (isEvent) {
        final e = store.events[id]!;
        batch.events.add(
          e['deleted'] == true
              ? {'id': id, 'child_id': childId, 'changed_at': changedAt, 'deleted': true}
              : {
                  ...LocalEngine.detailsOf(e),
                  'id': id,
                  'child_id': childId,
                  'start': e['start'],
                  'end': ?e['end'],
                  'note': ?e['note'],
                  'changed_at': changedAt,
                },
        );
      } else {
        final t = store.timers[id]!;
        batch.timers.add({
          'id': id,
          'child_id': childId,
          'kind': t.kind,
          'changed_at': changedAt,
          if (t.deleted) 'deleted': true else 'segments': t.toApi()['segments'],
        });
      }
    }
    for (final MapEntry(key: family, value: batch) in batches.entries) {
      final res = await super.send('POST', '/families/$family/sync', body: {'events': batch.events, 'timers': batch.timers});
      for (final (prefix, results) in [('e', res['events'] as List), ('t', res['timers'] as List)]) {
        for (final r in results) {
          final key = '$prefix:${r['id']}';
          // Changed again while the push was on its way: that newer change goes next time.
          if (store.pending[key]?.seq != snapshot[key]?.seq) continue;
          store.pending.remove(key);
          if (r['status'] == 'applied') {
            if (prefix == 't' && store.timers[r['id']]?.deleted == true) store.timers.remove(r['id']);
            continue;
          }
          final current = r['current'];
          if (prefix == 'e') {
            current == null ? store.events.remove(r['id']) : store.putEvent(current);
          } else {
            current == null ? store.timers.remove(r['id']) : store.putTimer(current);
          }
          notices.add(
            r['status'] == 'conflict'
                ? 'Something you changed was also changed on another device; the newer change was kept.'
                : 'Something you logged couldn\'t be saved: ${r['message']}',
          );
        }
      }
    }
    store.save();
  }

  /// Brings in a family's changes since the last pull (everything on the first one).
  Future<void> pull(String familyId) async {
    final since = store.cursors[familyId];
    final res = await super.send('GET', '/families/$familyId/sync', query: {'since': ?since?.toString()});
    if (res['full'] == true) store.clearFamilyData(familyId);
    store.setChildren(familyId, jsonDecode(jsonEncode(res['children'])));
    for (final e in res['events'] as List) {
      store.putEvent(e);
    }
    store.replaceTimers(store.childIdsOf(familyId), res['timers'] as List);
    store.cursors[familyId] = res['cursor'] as int;
    store.save();
  }

  bool _pulling = false;

  /// A background pull after the server reported changes (no-op while offline or busy). Queued
  /// changes are never overwritten by it.
  Future<void> pullSoon(String? familyId) async {
    if (familyId == null || offline || _pulling || _syncing) return;
    _pulling = true;
    try {
      await pull(familyId);
    } catch (_) {
      // The next refresh tries again.
    } finally {
      _pulling = false;
    }
  }

  /// Stops the retry timer (sign-out).
  void close() {
    _retry?.cancel();
    _retry = null;
  }
}

/// A request applied locally, on its way to the server, with the pending changes (key → seq) it
/// made here.
class _Outgoing {
  _Outgoing(this.method, this.path, this.query, this.body, this.keys);
  final String method, path;
  final Map<String, String>? query;
  final Object? body;
  final Map<String, int> keys;
}
