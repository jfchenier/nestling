/// Serverless sync between phones: each phone sends the whole family as a snapshot, and the
/// other keeps, record by record, whichever copy was changed last (the same rules as the
/// server's `POST /sync`). Deletions travel as tombstones. Applying a snapshot twice, or in any
/// order, ends in the same state, so phones that were apart for a while catch up whenever they
/// meet.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'domain.dart';
import 'store.dart';

/// One family's data, ready to send to another phone (or to a backup).
Map<String, dynamic> exportFamily(LocalStore store, String familyId) {
  final f = store.families.firstWhere((f) => f['id'] == familyId);
  final kids = <String>{
    for (final c in (f['children'] as List? ?? [])) c['id'],
    for (final d in store.deletedChildren.values)
      if (d['family_id'] == familyId) d['id'],
  };
  int clock(String key) => store.clocks[key] ?? 0;
  return {
    'v': 1,
    'family_id': familyId,
    'family': {for (final e in f.entries) if (e.key != 'children' && e.key != 'role') e.key: e.value},
    'family_clock': clock('f:$familyId'),
    'children': [
      for (final c in (f['children'] as List? ?? [])) {...c, '_clock': clock('c:${c['id']}')},
      for (final d in store.deletedChildren.values)
        if (d['family_id'] == familyId) {...d, '_clock': clock('c:${d['id']}')},
    ],
    'events': [
      for (final e in store.events.values)
        if (kids.contains(e['child_id'])) {...e, '_clock': clock('e:${e['id']}')},
    ],
    'timers': [
      for (final t in store.timers.values)
        if (kids.contains(t.childId)) {...t.toJson(), '_clock': clock('t:${t.id}')},
    ],
    'photos': {
      for (final MapEntry(:key, :value) in store.photos.entries)
        if (kids.contains(key)) key: {...value, '_clock': clock('p:$key')},
    },
  };
}

/// Applies another phone's snapshot. Returns whether anything changed here.
bool mergeFamily(LocalStore store, Map<String, dynamic> snap) {
  if (snap['v'] != 1) throw const FormatException('unknown snapshot version');
  final familyId = snap['family_id'] as String;
  var changed = false;

  bool newer(String key, dynamic theirs, {required bool exists}) {
    final mine = exists ? (store.clocks[key] ?? 0) : -1;
    final t = theirs is int ? theirs : 0;
    if (t <= mine) return false;
    store.clocks[key] = t;
    changed = true;
    return true;
  }

  // The family itself (name, timezone); caregivers are the union of both lists.
  var f = store.families.where((f) => f['id'] == familyId).firstOrNull;
  final theirFamily = Map<String, dynamic>.from(snap['family'] as Map);
  var theirsNewer = false;
  if (f == null) {
    f = {...theirFamily, 'role': 'owner', 'members': <dynamic>[], 'children': <dynamic>[]};
    store.families.add(f);
    store.clocks['f:$familyId'] = snap['family_clock'] ?? 0;
    changed = theirsNewer = true;
  } else if (newer('f:$familyId', snap['family_clock'], exists: true)) {
    theirsNewer = true;
  }
  if (theirsNewer) {
    for (final k in ['name', 'timezone', 'created_at']) {
      f[k] = theirFamily[k];
    }
  }
  final members = [for (final m in (f['members'] as List? ?? [])) Map<String, dynamic>.from(m)];
  for (final m in (theirFamily['members'] as List? ?? [])) {
    final i = members.indexWhere((x) => x['user_id'] == m['user_id']);
    if (i < 0) {
      members.add(Map<String, dynamic>.from(m));
      changed = true;
    } else if (theirsNewer) {
      members[i] = Map<String, dynamic>.from(m);
    }
  }
  f['members'] = members;

  // Children.
  final kids = f['children'] as List;
  for (final c in (snap['children'] as List? ?? [])) {
    final id = c['id'] as String;
    final exists = kids.any((k) => k['id'] == id) || store.deletedChildren.containsKey(id);
    if (!newer('c:$id', c['_clock'], exists: exists)) continue;
    final clean = Map<String, dynamic>.from(c)..remove('_clock');
    kids.removeWhere((k) => k['id'] == id);
    if (clean['deleted'] == true) {
      store.deletedChildren[id] = clean;
    } else {
      store.deletedChildren.remove(id);
      kids.add(clean);
    }
  }

  // Events (deleted ones are tombstones).
  for (final e in (snap['events'] as List? ?? [])) {
    final id = e['id'] as String;
    if (!newer('e:$id', e['_clock'], exists: store.events.containsKey(id))) continue;
    store.events[id] = Map<String, dynamic>.from(e)..remove('_clock');
  }

  // Timers.
  for (final t in (snap['timers'] as List? ?? [])) {
    final id = t['id'] as String;
    if (!newer('t:$id', t['_clock'], exists: store.timers.containsKey(id))) continue;
    store.timers[id] = StoredTimer.fromJson(Map<String, dynamic>.from(t));
  }

  // Photos.
  (snap['photos'] as Map? ?? {}).forEach((childId, p) {
    if (!newer('p:$childId', p['_clock'], exists: store.photos.containsKey(childId))) return;
    store.photos[childId] = Map<String, dynamic>.from(p)..remove('_clock');
  });

  if (resolveTimerClashes(store)) changed = true;
  if (changed) store.save();
  return changed;
}

/// Two phones each started, say, a sleep timer for the same baby while apart: the one that
/// started first stays, the other is dropped (and that drop syncs like any change).
bool resolveTimerClashes(LocalStore store) {
  final byKind = <String, List<StoredTimer>>{};
  for (final t in store.timers.values.where((t) => !t.deleted)) {
    byKind.putIfAbsent('${t.childId}/${t.kind}', () => []).add(t);
  }
  var changed = false;
  for (final list in byKind.values.where((l) => l.length > 1)) {
    int first(StoredTimer t) => t.segments.isEmpty ? t.createdAt : t.segments.map((s) => s.start).reduce(math.min);
    list.sort((a, b) => first(a) != first(b) ? first(a).compareTo(first(b)) : a.id.compareTo(b.id));
    for (final t in list.skip(1)) {
      t.deleted = true;
      store.clocks['t:${t.id}'] = math.max(nowMs(), (store.clocks['t:${t.id}'] ?? 0) + 1);
      changed = true;
    }
  }
  return changed;
}

/// Snapshot to bytes and back (JSON, UTF-8).
List<int> encodeSnapshot(Map<String, dynamic> snap) => utf8.encode(jsonEncode(snap));
Map<String, dynamic> decodeSnapshot(List<int> bytes) => jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
