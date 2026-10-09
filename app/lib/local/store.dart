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
  int _seq = 0;

  Timer? _saveTimer;

  static Future<LocalStore> open([Persist? persist]) async {
    final store = LocalStore._(persist ?? await openPersist());
    try {
      final text = await store._persist.read(_key);
      if (text != null) store._fromJson(jsonDecode(text));
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
    pending[key] = Pending(nowMs(), ++_seq);
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
    _saveTimer?.cancel();
    await _persist.delete(_key);
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
  }
}
