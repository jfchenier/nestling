import 'dart:math' as math;

import '../models.dart';
import 'domain.dart';
import 'store.dart';

/// Answers the API's requests from the [LocalStore], with the server's rules, so the app works
/// the same without a connection. Writes are recorded as pending changes for the next sync.
///
/// Covers what logging needs: the account and families (read only), each child's summary,
/// events, timers and trends, and every event and timer write.
class LocalEngine {
  LocalEngine(this.store);
  final LocalStore store;

  static final _routes = <(String, RegExp)>[
    ('GET', RegExp(r'^/me$')),
    ('GET', RegExp(r'^/families$')),
    ('GET', RegExp(r'^/children/([^/]+)$')),
    ('GET', RegExp(r'^/children/([^/]+)/(summary|trends|timers|events)$')),
    ('POST', RegExp(r'^/children/([^/]+)/(timers|events)$')),
    ('GET|PATCH|DELETE', RegExp(r'^/(events|timers)/([^/]+)$')),
    ('POST', RegExp(r'^/timers/([^/]+)/(pause|resume|switch|stop)$')),
  ];

  /// Whether this request can be answered locally.
  static bool handles(String method, String path) =>
      _routes.any((r) => r.$1.split('|').contains(method) && r.$2.hasMatch(path));

  static String newId() => uuidV7();

  String fmt(int ms) => formatTime(DateTime.fromMillisecondsSinceEpoch(ms));

  String? get _userId => store.me?['id'];

  /// Runs one request. Throws [ApiException]s like the server would.
  dynamic handle(String method, String path, {Map<String, String>? query, Object? body}) {
    final q = query ?? const {};
    final b = body is Map<String, dynamic> ? body : <String, dynamic>{};
    final seg = path.split('/').where((s) => s.isNotEmpty).toList();
    switch ((method, seg)) {
      case ('GET', ['me']):
        return store.me ?? (throw notFound('account'));
      case ('GET', ['families']):
        return {'families': store.families};
      case ('GET', ['children', final id]):
        return _child(id);
      case ('GET', ['children', final id, 'summary']):
        return summary(id);
      case ('GET', ['children', final id, 'events']):
        return listEvents(id, q);
      case ('GET', ['children', final id, 'timers']):
        _child(id);
        return {'timers': [for (final t in _timersOf(id)) t.toApi()]};
      case ('GET', ['children', final id, 'trends']):
        return trends(id, q);
      case ('POST', ['children', final id, 'events']):
        return createEvent(id, b);
      case ('POST', ['children', final id, 'timers']):
        return startTimer(id, b);
      case ('GET', ['events', final id]):
        return _event(id);
      case ('PATCH', ['events', final id]):
        return updateEvent(id, b);
      case ('DELETE', ['events', final id]):
        return deleteEvent(id);
      case ('GET', ['timers', final id]):
        return _timer(id).toApi();
      case ('PATCH', ['timers', final id]):
        return editTimer(id, b);
      case ('DELETE', ['timers', final id]):
        return discardTimer(id);
      case ('POST', ['timers', final id, 'pause']):
        return pauseTimer(id);
      case ('POST', ['timers', final id, 'resume']):
        return resumeTimer(id, b);
      case ('POST', ['timers', final id, 'switch']):
        return switchTimer(id, b);
      case ('POST', ['timers', final id, 'stop']):
        return stopTimer(id, b);
    }
    throw notFound('endpoint');
  }

  Map<String, dynamic> _child(String id) => store.child(id) ?? (throw notFound('child'));

  // ---- events ----

  static const _common = {
    'id',
    'child_id',
    'start',
    'end',
    'duration_seconds',
    'note',
    'created_by',
    'updated_by',
    'created_at',
    'updated_at',
    'source',
    'deleted',
  };

  static Map<String, dynamic> detailsOf(Map<String, dynamic> event) => {
    for (final e in event.entries)
      if (!_common.contains(e.key)) e.key: e.value,
  };

  static int startOf(Map<String, dynamic> e) => parseTimeMs(e['start']);
  static int? endOf(Map<String, dynamic> e) => parseOptTimeMs(e['end']);

  Map<String, dynamic> eventJson({
    required String id,
    required String childId,
    required Map<String, dynamic> details,
    required int start,
    int? end,
    String? note,
    String? createdBy,
    String? updatedBy,
    required String createdAt,
    required int updatedAt,
    String? source,
  }) => {
    'id': id,
    'child_id': childId,
    for (final e in details.entries)
      if (e.value != null) e.key: e.value,
    'start': fmt(start),
    if (end != null) 'end': fmt(end),
    if (end != null) 'duration_seconds': (end - start) ~/ 1000,
    'note': ?note,
    'created_by': createdBy,
    'updated_by': updatedBy,
    'created_at': createdAt,
    'updated_at': fmt(updatedAt),
    'source': ?source,
  };

  Map<String, dynamic> _event(String id) {
    final e = store.events[id];
    if (e == null || e['deleted'] == true) throw notFound('event');
    return e;
  }

  Map<String, dynamic> listEvents(String childId, Map<String, String> q) {
    _child(childId);
    final limit = (int.tryParse(q['limit'] ?? '') ?? 100).clamp(1, 1000);
    final from = q['from'] == null ? null : parseTimeMs(q['from']!);
    final to = q['to'] == null ? null : parseTimeMs(q['to']!);
    final types = (q['type'] ?? '').split(',').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toSet();
    for (final t in types) {
      if (!eventTypes.contains(t)) throw badRequest("unknown type '$t' (expected one of ${eventTypes.join(', ')})");
    }
    final rows = [
      for (final e in store.eventsOf(childId))
        if (types.isEmpty || types.contains(e['type'])) (startOf(e), e),
    ].where((r) => (from == null || r.$1 >= from) && (to == null || r.$1 < to)).toList()
      ..sort((a, b) => b.$1.compareTo(a.$1));
    final page = rows.take(limit).toList();
    return {
      'events': [for (final r in page) r.$2],
      'next_to': rows.length > limit ? fmt(page.last.$1) : null,
    };
  }

  Map<String, dynamic> createEvent(String childId, Map<String, dynamic> input) {
    _child(childId);
    final id = input['id'] as String? ?? newId();
    final existing = store.events[id];
    if (existing != null && existing['deleted'] != true) return existing;
    final start = parseOptTimeMs(input['start']) ?? nowMs();
    final end = parseOptTimeMs(input['end']);
    final details = normalizeDetails(input);
    validateEvent(details, start, end, input['note']);
    final now = nowMs();
    final json = eventJson(
      id: id,
      childId: childId,
      details: details,
      start: start,
      end: end,
      note: cleanNote(input['note']),
      createdBy: _userId,
      updatedBy: _userId,
      createdAt: fmt(now),
      updatedAt: now,
    );
    store.events[id] = json;
    store.markChanged('e:$id');
    return json;
  }

  Map<String, dynamic> updateEvent(String id, Map<String, dynamic> patch) {
    final row = _event(id);
    for (final key in ['id', 'child_id', 'created_by', 'updated_by', 'created_at', 'updated_at', 'duration_seconds', 'source']) {
      if (patch.containsKey(key)) throw badRequest("'$key' cannot be changed");
    }
    final current = {...detailsOf(row), 'start': row['start'], 'end': ?row['end'], 'note': ?row['note']};
    patch.forEach((k, v) => v == null ? current.remove(k) : current[k] = v);
    if (current['start'] is! String) throw badRequest('start cannot be removed');
    final start = parseTimeMs(current['start']);
    final end = parseOptTimeMs(current['end']);
    final details = normalizeDetails(current);
    validateEvent(details, start, end, current['note']);
    final json = eventJson(
      id: id,
      childId: row['child_id'],
      details: details,
      start: start,
      end: end,
      note: cleanNote(current['note']),
      createdBy: row['created_by'],
      updatedBy: _userId,
      createdAt: row['created_at'],
      updatedAt: nowMs(),
      source: row['source'],
    );
    store.events[id] = json;
    store.markChanged('e:$id');
    return json;
  }

  dynamic deleteEvent(String id) {
    final row = _event(id);
    store.events[id] = {'id': id, 'child_id': row['child_id'], 'deleted': true, 'updated_at': fmt(nowMs())};
    store.markChanged('e:$id');
    return null;
  }

  // ---- summary & trends ----

  List<TrendEvent> _trendEvents(String childId, int r0, int r1) => [
    for (final e in store.eventsOf(childId))
      if (const ['feed', 'sleep', 'diaper', 'pump'].contains(e['type']))
        if (startOf(e) case final s when s >= r0 - 2 * 24 * 3600 * 1000 && s < r1) TrendEvent(s, endOf(e), e),
  ];

  Map<String, dynamic> summary(String childId) {
    final child = _child(childId);
    final now = nowMs();
    final last = <String, dynamic>{}, since = <String, dynamic>{};
    for (final kind in const ['feed', 'sleep', 'diaper', 'pump']) {
      Map<String, dynamic>? latest;
      int? latestStart;
      for (final e in store.eventsOf(childId).where((e) => e['type'] == kind)) {
        final s = startOf(e);
        if (latestStart == null || s > latestStart) (latest, latestStart) = (e, s);
      }
      last[kind] = latest;
      if (latest == null) {
        since['${kind}_seconds'] = null;
      } else {
        final reference = kind == 'sleep' ? endOf(latest) ?? latestStart! : latestStart!;
        since['${kind}_seconds'] = math.max((now - reference) ~/ 1000, 0);
      }
    }
    final timers = [for (final t in _timersOf(childId)) t.toApi()];
    if (timers.any((t) => t['kind'] == 'sleep')) since['sleep_seconds'] = null;
    final today = dateOnly(DateTime.now());
    final (r0, r1) = rangeMs(today, 1);
    final events = _trendEvents(childId, r0, r1);
    return {
      'child': child,
      'last': last,
      'since': since,
      'timers': timers,
      'today': (computeTrends(events, today, 1, now)['days'] as List).first,
      'last_24h': last24h(events, now),
    };
  }

  Map<String, dynamic> trends(String childId, Map<String, String> q) {
    _child(childId);
    final days = int.tryParse(q['days'] ?? '') ?? 7;
    if (days < 1 || days > 90) throw badRequest('days must be between 1 and 90');
    final to = q['to'] == null ? dateOnly(DateTime.now()) : DateTime.tryParse(q['to']!) ?? (throw badRequest('invalid date'));
    final from = DateTime(to.year, to.month, to.day - days + 1);
    final (r0, r1) = rangeMs(from, days);
    return computeTrends(_trendEvents(childId, r0, r1), from, days, nowMs());
  }

  // ---- timers ----

  List<StoredTimer> _timersOf(String childId) => store.timersOf(childId).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  StoredTimer _timer(String id) {
    final t = store.timers[id];
    if (t == null || t.deleted) throw notFound('timer');
    return t;
  }

  Map<String, dynamic> _save(StoredTimer t) {
    t.updatedAt = nowMs();
    store.markChanged('t:${t.id}');
    return t.toApi();
  }

  Map<String, dynamic> startTimer(String childId, Map<String, dynamic> req) {
    _child(childId);
    final kind = req['kind'];
    if (!timerKinds.contains(kind)) throw badRequest("unknown variant `$kind`, expected one of ${timerKinds.join(', ')}");
    final id = req['id'] as String? ?? newId();
    final same = store.timers[id];
    if (same != null && !same.deleted) return same.toApi();
    final now = nowMs();
    final start = parseOptTimeMs(req['start']) ?? now;
    if (start > now + 60000) throw badRequest('a timer cannot start in the future');
    final side = checkSide(kind, req['side']);
    final running = _timersOf(childId).where((t) => t.kind == kind).firstOrNull;
    if (running != null) throw conflict('a $kind timer is already running (${running.id})');
    final t = StoredTimer(
      id: id,
      childId: childId,
      kind: kind,
      segments: [Segment(side, start)],
      createdBy: _userId,
      createdAt: now,
      updatedAt: now,
    );
    store.timers[id] = t;
    return _save(t);
  }

  Map<String, dynamic> pauseTimer(String id) {
    final t = _timer(id);
    final last = t.segments.lastOrNull;
    if (last == null || last.end != null) throw conflict('timer is already paused');
    last.end = math.max(nowMs(), last.start);
    return _save(t);
  }

  Map<String, dynamic> resumeTimer(String id, Map<String, dynamic> req) {
    final t = _timer(id);
    if (t.segments.lastOrNull?.end == null && t.segments.isNotEmpty) throw conflict('timer is already running');
    final side = checkSide(t.kind, req['side'] ?? t.segments.lastOrNull?.side);
    t.segments.add(Segment(side, nowMs()));
    return _save(t);
  }

  Map<String, dynamic> switchTimer(String id, Map<String, dynamic> req) {
    final t = _timer(id);
    if (t.kind == 'sleep') throw badRequest('sleep timers have no sides');
    final current = t.segments.lastOrNull?.side;
    final target = checkSide(t.kind, req['side'] ?? (current == 'left' ? 'right' : 'left'));
    final now = nowMs();
    final last = t.segments.lastOrNull;
    if (last != null && last.end == null) {
      if (last.side == target) return t.toApi();
      last.end = math.max(now, last.start);
    }
    t.segments.add(Segment(target, now));
    return _save(t);
  }

  Map<String, dynamic> editTimer(String id, Map<String, dynamic> req) {
    final t = _timer(id);
    final sides = req['left_seconds'] != null || req['right_seconds'] != null;
    if (t.kind != 'breastfeed' && sides) throw badRequest('left_seconds / right_seconds can only be set on a breastfeed timer');
    if (t.kind == 'breastfeed' && req['seconds'] != null) throw badRequest('set left_seconds / right_seconds on a breastfeed timer');
    for (final k in ['left_seconds', 'right_seconds', 'seconds']) {
      final v = req[k];
      if (v != null && (v is! num || v < 0)) throw badRequest('$k must be a whole number of seconds');
      if (v is num && v > 12 * 3600) throw badRequest('a timer cannot be set to more than 12 hours');
    }
    final now = nowMs();
    final segs = [for (final s in t.segments) s.copy()];
    if (parseOptTimeMs(req['start']) case final start?) {
      if (start > now) throw badRequest('a timer cannot start in the future');
      setStart(segs, start, now);
    }
    for (final (side, key) in const [('left', 'left_seconds'), ('right', 'right_seconds'), (null, 'seconds')]) {
      if (req[key] case final num secs) setSide(segs, side, secs.round() * 1000, now);
    }
    t.segments = segs;
    return _save(t);
  }

  Map<String, dynamic> stopTimer(String id, Map<String, dynamic> req) {
    final eventId = req['event_id'] as String? ?? newId();
    final done = store.events[eventId];
    if (done != null && done['deleted'] != true) return done;
    final t = _timer(id);
    final now = nowMs();
    final segs = [for (final s in t.segments) s.copy()];
    final (start, end, details) = stopTimerSegments(t.kind, segs, parseOptTimeMs(req['end']), req, now);
    final json = eventJson(
      id: eventId,
      childId: t.childId,
      details: details,
      start: start,
      end: end,
      note: cleanNote(req['note']),
      createdBy: _userId,
      updatedBy: _userId,
      createdAt: fmt(now),
      updatedAt: now,
    );
    store.events[eventId] = json;
    store.markChanged('e:$eventId');
    t.deleted = true;
    _save(t);
    return json;
  }

  dynamic discardTimer(String id) {
    final t = _timer(id);
    t.deleted = true;
    _save(t);
    return null;
  }
}

/// A time-ordered UUID (version 7), like the server's ids.
String uuidV7() {
  final r = math.Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  var ms = nowMs();
  for (var i = 5; i >= 0; i--) {
    b[i] = ms % 256;
    ms ~/= 256;
  }
  b[6] = 0x70 | (b[6] & 0x0f);
  b[8] = 0x80 | (b[8] & 0x3f);
  final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
