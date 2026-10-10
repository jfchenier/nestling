import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../models.dart';
import 'domain.dart';
import 'persist.dart';

/// A change made on this device that the sync target hasn't confirmed yet.
class Pending {
  Pending(this.changedAt, this.seq);
  final int changedAt;

  /// Bumped on every local change, so a push only clears what it actually sent.
  final int seq;
}

/// A timer as the device keeps it: segments in epoch ms (the API sends RFC 3339).
class StoredTimer {
  StoredTimer({
    required this.id,
    required this.childId,
    required this.kind,
    required this.segments,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
  });

  final String id;
  final String childId;
  final String kind;
  List<Segment> segments;
  final String? createdBy;
  final int createdAt;
  int updatedAt;

  /// Stopped or thrown away here; kept until the deletion is synced.
  bool deleted;

  /// From the API's timer JSON.
  factory StoredTimer.fromApi(Map<String, dynamic> j) {
    final segs = [
      for (final s in (j['segments'] as List? ?? []))
        Segment(s['side'], parseTimeMs(s['start']), parseOptTimeMs(s['end'])),
    ];
    final started = parseOptTimeMs(j['started_at']) ?? nowMs();
    return StoredTimer(
      id: j['id'],
      childId: j['child_id'],
      kind: j['kind'],
      segments: segs.isEmpty ? [Segment(j['side'], started)] : segs,
      createdBy: j['created_by'],
      createdAt: started,
      updatedAt: parseOptTimeMs(j['updated_at']) ?? started,
    );
  }

  /// The API's timer JSON, with elapsed times as of now.
  Map<String, dynamic> toApi() {
    final now = nowMs();
    final (left, right, total) = sideSeconds(segments, now);
    String fmt(int ms) => formatTime(DateTime.fromMillisecondsSinceEpoch(ms));
    return {
      'id': id,
      'child_id': childId,
      'kind': kind,
      'started_at': fmt(segments.isEmpty ? createdAt : segments.map((s) => s.start).reduce(math.min)),
      'running': segments.isNotEmpty && segments.last.end == null,
      'side': segments.lastOrNull?.side,
      'elapsed_seconds': total,
      'segments': [
        for (final s in segments) {'side': s.side, 'start': fmt(s.start), 'end': s.end == null ? null : fmt(s.end!)},
      ],
      'created_by': createdBy,
      'updated_at': fmt(updatedAt),
      if (kind != 'sleep') ...{'left_seconds': left, 'right_seconds': right},
    };
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'child_id': childId,
    'kind': kind,
    'segments': [for (final s in segments) [s.side, s.start, s.end]],
    'created_by': createdBy,
    'created_at': createdAt,
    'updated_at': updatedAt,
    if (deleted) 'deleted': true,
  };

  factory StoredTimer.fromJson(Map<String, dynamic> j) => StoredTimer(
    id: j['id'],
    childId: j['child_id'],
    kind: j['kind'],
    segments: [for (final s in (j['segments'] as List)) Segment(s[0], s[1], s[2])],
    createdBy: j['created_by'],
    createdAt: j['created_at'],
    updatedAt: j['updated_at'],
    deleted: j['deleted'] == true,
  );
}

/// Everything the app needs to keep working without its sync target: the account, families and
/// children, every event and running timer, and the changes not synced yet. Saved as one
/// document (a year of entries is a few hundred KB).
class LocalStore {
  LocalStore._(this._persist);

  static const _key = 'store';
  static const _photosKey = 'event_photos';
  final Persist _persist;

  /// The server this copy came from, and the account (`me`) it belongs to.
  String? server;
  Map<String, dynamic>? me;
  List<Map<String, dynamic>> families = [];

  /// Events by id, in the API's JSON shape. A deleted one is `{id, child_id, deleted: true}`
  /// while its deletion waits to be synced.
  final Map<String, Map<String, dynamic>> events = {};
  final Map<String, StoredTimer> timers = {};

  /// Changes waiting to be synced, keyed `e:<id>` (events) or `t:<id>` (timers).
  final Map<String, Pending> pending = {};

  /// Sync cursor per family (`GET /families/{id}/sync?since=`).
  final Map<String, int> cursors = {};

  /// When each record was last changed on any device (epoch ms), keyed like [pending] plus
  /// `c:<child id>`, `f:<family id>` and `p:<child id>` (photo). Decides merges between devices
  /// in serverless mode (the newest change wins).
  final Map<String, int> clocks = {};

  /// Children deleted in serverless mode, kept so the deletion reaches the other phones.
  final Map<String, Map<String, dynamic>> deletedChildren = {};

  /// Profile pictures in serverless mode: child id → `{version, type, data (base64)}`.
  final Map<String, Map<String, dynamic>> photos = {};

  /// Photos on entries (the baby book) in serverless mode: event id → `{version, type, data
  /// (base64)}`; `{version: null}` once removed. `data` is missing while it is still on its way
  /// (Drive sync sends photos as files of their own). Clocks and stamps are keyed `ep:<event id>`.
  /// Saved apart from the rest ([eventPhotosChanged]), so logging doesn't rewrite every photo.
  final Map<String, Map<String, dynamic>> eventPhotos = {};
  bool _eventPhotosDirty = false;

  /// [eventPhotos] changed: saved with the next [save].
  void eventPhotosChanged() {
    _eventPhotosDirty = true;
    save();
  }

  /// Serverless mode: settings of this device (pairing key, peers…), see `local/peer_sync.dart`.
  Map<String, dynamic> serverless = {};
  int _seq = 0;

  /// Serverless mode: when each record last changed *on this copy* (a counter, keyed like
  /// [clocks]), whether changed here or merged in from another phone. Another phone that has
  /// everything up to [stamp] only needs the records stamped after it. [replica] names this copy,
  /// so a phone that starts over is sent everything again.
  final Map<String, int> stamps = {};
  int stamp = 0;
  String replica = _newReplica();

  static String _newReplica() {
    final r = math.Random.secure();
    return List.generate(12, (_) => r.nextInt(36).toRadixString(36)).join();
  }

  /// [key] changed on this copy (see [stamps]).
  void touch(String key) => stamps[key] = ++stamp;

  Timer? _saveTimer;

  static Future<LocalStore> open([Persist? persist]) async {
    final store = LocalStore._(persist ?? await openPersist());
    try {
      final text = await store._persist.read(_key);
      if (text != null) store._fromJson(jsonDecode(text));
      final photos = await store._persist.read(_photosKey);
      if (photos != null) {
        (jsonDecode(photos) as Map).forEach((k, v) => store.eventPhotos[k] = Map<String, dynamic>.from(v));
      }
    } catch (_) {
      // Unreadable: start over; the next sync fills it again.
    }
    return store;
  }

  bool get hasData => me != null;
  int get pendingCount => pending.length;

  // ---- lookups ----

  Map<String, dynamic>? familyOfChild(String childId) {
    for (final f in families) {
      for (final c in (f['children'] as List? ?? [])) {
        if (c is Map && c['id'] == childId) return f;
      }
    }
    return null;
  }

  Map<String, dynamic>? child(String childId) {
    for (final f in families) {
      for (final c in (f['children'] as List? ?? [])) {
        if (c is Map<String, dynamic> && c['id'] == childId) return c;
      }
    }
    return null;
  }

  Set<String> childIdsOf(String familyId) => {
    for (final f in families.where((f) => f['id'] == familyId))
      for (final c in (f['children'] as List? ?? [])) c['id'] as String,
  };

  /// Live (not deleted) events of a child.
  Iterable<Map<String, dynamic>> eventsOf(String childId) =>
      events.values.where((e) => e['child_id'] == childId && e['deleted'] != true);

  Iterable<StoredTimer> timersOf(String childId) => timers.values.where((t) => t.childId == childId && !t.deleted);

  // ---- local changes ----

  void markChanged(String key) {
    final now = nowMs();
    pending[key] = Pending(now, ++_seq);
    // Strictly increasing, so a change right after a merge still wins.
    clocks[key] = math.max(now, (clocks[key] ?? 0) + 1);
    touch(key);
    save();
  }

  // ---- data from the sync target (never overwrites a change that is still pending) ----

  void putEvent(Map<String, dynamic> json) {
    final id = json['id'] as String;
    if (pending.containsKey('e:$id')) return;
    if (json['deleted'] == true) {
      events.remove(id);
    } else {
      events[id] = json;
    }
  }

  void removeEvent(String id) {
    if (!pending.containsKey('e:$id')) events.remove(id);
  }

  void putTimer(Map<String, dynamic> json) {
    final id = json['id'] as String;
    if (pending.containsKey('t:$id')) return;
    timers[id] = StoredTimer.fromApi(json);
  }

  void removeTimer(String id) {
    if (!pending.containsKey('t:$id')) timers.remove(id);
  }

  /// The full list of timers for [childIds]: anything else (not pending) is gone.
  void replaceTimers(Set<String> childIds, List<dynamic> list) {
    final keep = {for (final t in list) t['id']};
    timers.removeWhere((id, t) => childIds.contains(t.childId) && !keep.contains(id) && !pending.containsKey('t:$id'));
    for (final t in list) {
      putTimer(t);
    }
  }

  /// Replaces one child's JSON inside its family (name or photo changed elsewhere).
  void putChild(Map<String, dynamic> child) {
    for (final f in families) {
      final kids = f['children'];
      if (kids is List) {
        final i = kids.indexWhere((c) => c is Map && c['id'] == child['id']);
        if (i >= 0) kids[i] = child;
      }
    }
  }

  void setChildren(String familyId, List<dynamic> children) {
    for (final f in families.where((f) => f['id'] == familyId)) {
      f['children'] = children;
    }
  }

  /// Everything of a family (before a full sync replaces it), except pending changes.
  void clearFamilyData(String familyId) {
    final kids = childIdsOf(familyId);
    events.removeWhere((id, e) => kids.contains(e['child_id']) && !pending.containsKey('e:$id'));
  }

  /// Forget everything (sign-out or another account).
  Future<void> clear() async {
    server = null;
    me = null;
    families = [];
    events.clear();
    timers.clear();
    pending.clear();
    cursors.clear();
    clocks.clear();
    deletedChildren.clear();
    photos.clear();
    eventPhotos.clear();
    serverless = {};
    stamps.clear();
    stamp = 0;
    replica = _newReplica();
    _saveTimer?.cancel();
    await _persist.delete(_key);
    await _persist.delete(_photosKey);
  }

  // ---- saving ----

  /// Saves soon (several changes in a row are written once).
  void save() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), flush);
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    try {
      if (_eventPhotosDirty) {
        _eventPhotosDirty = false;
        await _persist.write(_photosKey, jsonEncode(eventPhotos));
      }
      await _persist.write(_key, jsonEncode(_toJson()));
    } catch (_) {
      // Storage full or unavailable: keep going in memory.
    }
  }

  Map<String, dynamic> _toJson() => {
    'v': 1,
    'server': server,
    'me': me,
    'families': families,
    'events': events.values.toList(),
    'timers': [for (final t in timers.values) t.toJson()],
    'pending': {for (final MapEntry(:key, :value) in pending.entries) key: [value.changedAt, value.seq]},
    'cursors': cursors,
    'seq': _seq,
    'clocks': clocks,
    'deleted_children': deletedChildren,
    'photos': photos,
    'serverless': serverless,
    'stamps': stamps,
    'stamp': stamp,
    'replica': replica,
  };

  void _fromJson(Map<String, dynamic> j) {
    if (j['v'] != 1) return;
    server = j['server'];
    me = j['me'];
    families = [for (final f in (j['families'] as List? ?? [])) f as Map<String, dynamic>];
    for (final e in (j['events'] as List? ?? [])) {
      events[e['id']] = e;
    }
    for (final t in (j['timers'] as List? ?? [])) {
      final timer = StoredTimer.fromJson(t);
      timers[timer.id] = timer;
    }
    (j['pending'] as Map? ?? {}).forEach((k, v) => pending[k] = Pending(v[0], v[1]));
    (j['cursors'] as Map? ?? {}).forEach((k, v) => cursors[k] = v);
    _seq = j['seq'] ?? 0;
    (j['clocks'] as Map? ?? {}).forEach((k, v) => clocks[k] = v);
    (j['deleted_children'] as Map? ?? {}).forEach((k, v) => deletedChildren[k] = v);
    (j['photos'] as Map? ?? {}).forEach((k, v) => photos[k] = v);
    serverless = j['serverless'] ?? {};
    (j['stamps'] as Map? ?? {}).forEach((k, v) => stamps[k] = v);
    stamp = j['stamp'] ?? 0;
    if (j['replica'] is String) replica = j['replica'];
    // Saved before stamps existed: every record counts as changed once.
    for (final key in clocks.keys) {
      if (!stamps.containsKey(key)) touch(key);
    }
  }
}
