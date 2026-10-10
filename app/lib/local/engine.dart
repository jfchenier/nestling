import 'dart:convert';
import 'dart:math' as math;

import 'package:cryptography/dart.dart';

import '../models.dart';
import 'domain.dart';
import 'nara_csv.dart';
import 'store.dart';

/// Answers the API's requests from the [LocalStore], with the server's rules, so the app works
/// the same without a connection. Writes are recorded as pending changes for the next sync.
///
/// Covers what logging needs: the account and families (read only), each child's summary,
/// events, timers and trends, and every event and timer write.
class LocalEngine {
  LocalEngine(this.store);
  final LocalStore store;

  /// Serverless mode: this device is the only copy, so families, children, photos and the
  /// account settings are handled here too.
  bool serverless = false;

  static final _routes = <(String, RegExp)>[
    ('GET', RegExp(r'^/me$')),
    ('GET', RegExp(r'^/families$')),
    ('GET', RegExp(r'^/children/([^/]+)$')),
    ('GET', RegExp(r'^/children/([^/]+)/(summary|trends|timers|events)$')),
    ('POST', RegExp(r'^/children/([^/]+)/(timers|events)$')),
    ('GET|PATCH|DELETE', RegExp(r'^/(events|timers)/([^/]+)$')),
    ('POST', RegExp(r'^/timers/([^/]+)/(pause|resume|switch|stop)$')),
    ('POST', RegExp(r'^/events/([^/]+)/continue$')),
  ];

  static final _serverlessRoutes = <(String, RegExp)>[
    ('PATCH', RegExp(r'^/me$')),
    ('POST', RegExp(r'^/families$')),
    ('GET|PATCH', RegExp(r'^/families/([^/]+)$')),
    ('GET|POST', RegExp(r'^/families/([^/]+)/children$')),
    ('PATCH|DELETE', RegExp(r'^/children/([^/]+)$')),
    ('PUT|DELETE', RegExp(r'^/children/([^/]+)/photo$')),
    ('POST', RegExp(r'^/families/([^/]+)/import/nara-csv$')),
  ];

  /// Whether this request can be answered locally.
  static bool handles(String method, String path, {bool serverless = false}) => [
    ..._routes,
    if (serverless) ..._serverlessRoutes,
  ].any((r) => r.$1.split('|').contains(method) && r.$2.hasMatch(path));

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
      case ('POST', ['events', final id, 'continue']):
        return continueEvent(id, b);
    }
    if (serverless) {
      switch ((method, seg)) {
        case ('PATCH', ['me']):
          return updateMe(b);
        case ('POST', ['families']):
          return createFamily(b);
        case ('GET', ['families', final id]):
          return _family(id);
        case ('PATCH', ['families', final id]):
          return updateFamily(id, b);
        case ('GET', ['families', final id, 'children']):
          return {'children': _family(id)['children']};
        case ('POST', ['families', final id, 'children']):
          // Required for new babies, as on the server; the Nara import may still leave it unset.
          if (b['birth_date'] == null) throw badRequest('birth_date is required');
          return createChild(id, b);
        case ('PATCH', ['children', final id]):
          return updateChild(id, b);
        case ('DELETE', ['children', final id]):
          return deleteChild(id);
        case ('PUT', ['children', final id, 'photo']):
          return putPhoto(id, body as List<int>, query?['content_type'] ?? 'image/png');
        case ('DELETE', ['children', final id, 'photo']):
          return deletePhoto(id);
        case ('POST', ['families', final id, 'import', 'nara-csv']):
          return importNaraCsv(id, body is List<int> ? body : const [], q);
      }
    }
    throw notFound('endpoint');
  }

  Map<String, dynamic> _child(String id) => store.child(id) ?? (throw notFound('child'));

  // ---- serverless: account, families, children ----

  DayWindow _dayOf(Map<String, dynamic> child) => dayWindowOf(store.families.where((f) => f['id'] == child['family_id']).firstOrNull);

  Map<String, dynamic> _family(String id) => store.families.where((f) => f['id'] == id).firstOrNull ?? (throw notFound('family'));

  Map<String, dynamic> updateMe(Map<String, dynamic> req) {
    final me = store.me ?? (throw notFound('account'));
    if (req['units'] case final String units) {
      if (units != 'metric' && units != 'imperial') throw badRequest("units must be 'metric' or 'imperial'");
      me['units'] = units;
    }
    if (req['name'] case final String name when name.trim().isNotEmpty) {
      me['name'] = name.trim();
      for (final f in store.families) {
        for (final m in (f['members'] as List? ?? [])) {
          if (m['user_id'] == me['id']) m['name'] = me['name'];
        }
        store.markChanged('f:${f['id']}');
      }
    }
    store.save();
    return me;
  }

  void _checkTimezone(dynamic tz) {
    if (tz != null && (tz is! String || tz.trim().isEmpty)) throw badRequest('timezone must be an IANA name');
  }

  Map<String, dynamic> createFamily(Map<String, dynamic> req) {
    final name = (req['name'] as String? ?? '').trim();
    if (name.isEmpty) throw badRequest('name is required');
    _checkTimezone(req['timezone']);
    final me = store.me ?? (throw notFound('account'));
    final id = newId();
    final family = <String, dynamic>{
      'id': id,
      'name': name,
      'timezone': req['timezone'] ?? 'UTC',
      'day_start': hhmm(defaultDay.start),
      'day_end': hhmm(defaultDay.end),
      'created_at': fmt(nowMs()),
      'role': 'owner',
      'members': [
        {'user_id': me['id'], 'name': me['name'], 'email': me['email'] ?? '', 'role': 'owner'},
      ],
      'children': <dynamic>[],
    };
    store.families.add(family);
    store.markChanged('f:$id');
    return family;
  }

  Map<String, dynamic> updateFamily(String id, Map<String, dynamic> req) {
    final f = _family(id);
    if (req['name'] case final String name) {
      if (name.trim().isEmpty) throw badRequest('name cannot be empty');
      f['name'] = name.trim();
    }
    if (req.containsKey('timezone')) {
      _checkTimezone(req['timezone']);
      f['timezone'] = req['timezone'];
    }
    if (req.containsKey('day_start') || req.containsKey('day_end')) {
      final old = dayWindowOf(f);
      int time(String key, int fallback) {
        if (!req.containsKey(key)) return fallback;
        return parseHhmm(req[key]) ?? (throw badRequest("'${req[key]}' is not a time like '06:00'"));
      }

      final start = time('day_start', old.start), end = time('day_end', old.end);
      if (start >= end) throw badRequest('daytime must start before it ends');
      f['day_start'] = hhmm(start);
      f['day_end'] = hhmm(end);
    }
    store.markChanged('f:$id');
    return f;
  }

  static const _sexes = ['female', 'male', 'other'];

  void _checkChild(Map<String, dynamic> req) {
    if (req['sex'] != null && !_sexes.contains(req['sex'])) throw badRequest("sex must be 'female', 'male' or 'other'");
    if (req['birth_date'] != null && (req['birth_date'] is! String || DateTime.tryParse(req['birth_date']) == null)) {
      throw badRequest('birth_date must be a date (YYYY-MM-DD)');
    }
  }

  Map<String, dynamic> createChild(String familyId, Map<String, dynamic> req) {
    final f = _family(familyId);
    final name = (req['name'] as String? ?? '').trim();
    if (name.isEmpty) throw badRequest('name is required');
    _checkChild(req);
    final now = fmt(nowMs());
    final child = <String, dynamic>{
      'id': newId(),
      'family_id': familyId,
      'name': name,
      'birth_date': req['birth_date'],
      'sex': req['sex'],
      'created_at': now,
      'updated_at': now,
      'photo_version': null,
    };
    (f['children'] as List).add(child);
    store.markChanged('c:${child['id']}');
    return child;
  }

  Map<String, dynamic> updateChild(String id, Map<String, dynamic> req) {
    final c = _child(id);
    _checkChild(req);
    if (req['name'] case final String name) {
      if (name.trim().isEmpty) throw badRequest('name cannot be empty');
      c['name'] = name.trim();
    }
    for (final k in ['birth_date', 'sex']) {
      if (req.containsKey(k)) c[k] = req[k];
    }
    c['updated_at'] = fmt(nowMs());
    store.markChanged('c:$id');
    return c;
  }

  dynamic deleteChild(String id) {
    final c = _child(id);
    for (final f in store.families) {
      (f['children'] as List?)?.removeWhere((x) => x['id'] == id);
    }
    store.deletedChildren[id] = {'id': id, 'family_id': c['family_id'], 'deleted': true};
    store.markChanged('c:$id');
    return null;
  }

  Map<String, dynamic> putPhoto(String id, List<int> bytes, String contentType) {
    final c = _child(id);
    if (bytes.length > 5 * 1024 * 1024) throw badRequest('the photo is too large (5 MB at most)');
    final version = nowMs();
    store.photos[id] = {'version': version, 'type': contentType, 'data': base64Encode(bytes)};
    c['photo_version'] = version;
    store.markChanged('p:$id');
    store.markChanged('c:$id');
    return c;
  }

  dynamic deletePhoto(String id) {
    final c = _child(id);
    store.photos[id] = {'version': null};
    c['photo_version'] = null;
    store.markChanged('p:$id');
    store.markChanged('c:$id');
    return null;
  }

  /// A profile picture's bytes (serverless mode).
  List<int> photoBytes(String childId) {
    final data = store.photos[childId]?['data'];
    if (data is! String) throw notFound('photo');
    return base64Decode(data);
  }

  // ---- serverless: Nara import ----

  /// `POST /families/{id}/import/nara-csv`, like the server: preview with `dry_run=true`, put
  /// everything into `child_id` (or map `children=<nara key>:<child id>,…`), and match records
  /// on their Nara id so importing the same file again updates instead of duplicating. The event
  /// ids are derived from the family and the Nara id, so phones that import the same file agree.
  Map<String, dynamic> importNaraCsv(String familyId, List<int> bytes, Map<String, String> q) {
    final family = _family(familyId);
    final text = utf8.decode(bytes, allowMalformed: true);
    if (text.trim().isEmpty) throw badRequest('send the CSV file exported from the Nara app');
    final NaraCsv csv;
    try {
      csv = parseNaraCsv(text);
    } on FormatException catch (e) {
      throw badRequest(e.message);
    }
    final records = validNaraRecords(csv);
    final children = (family['children'] as List).cast<Map<String, dynamic>>();
    final wanted = <String, String>{
      for (final pair in (q['children'] ?? '').split(','))
        if (pair.split(':') case [final k, final v]) k.trim(): v.trim(),
    };
    final childId = q['child_id'];
    for (final target in [...wanted.values, ?childId]) {
      if (!children.any((c) => c['id'] == target)) throw badRequest("child '$target' is not in this family");
    }
    final naraChildren = <String, int>{};
    for (final r in records) {
      naraChildren[r.childKey ?? ''] = (naraChildren[r.childKey ?? ''] ?? 0) + 1;
    }
    final keys = naraChildren.keys.toList()..sort();
    final mapping = <String, String>{};
    final toCreate = <String>[];
    for (final key in keys) {
      if (wanted[key] ?? childId case final target?) {
        mapping[key] = target;
      } else if (children.length == 1 && keys.length == 1) {
        mapping[key] = children.first['id'];
      } else if (children.isEmpty) {
        toCreate.add(key);
      } else {
        final found = {for (final k in keys) csv.profiles[k]?.name == null ? k : '${csv.profiles[k]!.name} ($k)': naraChildren[k]};
        throw badRequest(
          'this family has several children; say where each Nara child goes with "children" (<nara child key>:<child id>) or "child_id". '
          'Nara children found (with event counts): ${jsonEncode(found)}',
        );
      }
    }
    final byType = <String, int>{};
    for (final r in records) {
      byType[r.details['type']] = (byType[r.details['type']] ?? 0) + 1;
    }
    final sortedByType = {for (final k in byType.keys.toList()..sort()) k: byType[k]};
    final sortedSkipped = {for (final k in csv.skipped.keys.toList()..sort()) k: csv.skipped[k]};
    List<Map<String, dynamic>> childrenOut() => [
      for (final k in keys)
        {'key': k, 'name': csv.profiles[k]?.name, 'birth_date': csv.profiles[k]?.birthDate, 'events': naraChildren[k], 'child_id': mapping[k]},
    ];
    if (q['dry_run'] == 'true') {
      final starts = records.map((r) => r.start);
      return {
        'dry_run': true,
        'tracks': csv.rows,
        'importable': records.length,
        'by_type': sortedByType,
        'skipped': sortedSkipped,
        'nara_children': childrenOut(),
        'children_to_create': toCreate.length,
        'first_ms': starts.isEmpty ? null : starts.reduce(math.min),
        'last_ms': starts.isEmpty ? null : starts.reduce(math.max),
      };
    }

    final created = <Map<String, dynamic>>[];
    for (final (i, key) in toCreate.indexed) {
      final p = csv.profiles[key];
      final name = p?.name ?? (toCreate.length == 1 ? 'Baby' : 'Baby ${i + 1}');
      final c = createChild(familyId, {'name': name, 'birth_date': p?.birthDate, 'sex': p?.sex});
      mapping[key] = c['id'];
      created.add({'id': c['id'], 'name': name, 'nara_child_key': key});
    }
    // Fill in a birth date / sex the existing child doesn't have yet.
    for (final MapEntry(:key, value: id) in mapping.entries) {
      final p = csv.profiles[key];
      final c = store.child(id);
      if (p == null || c == null) continue;
      final before = '${c['birth_date']}/${c['sex']}';
      c['birth_date'] ??= p.birthDate;
      c['sex'] ??= p.sex;
      if ('${c['birth_date']}/${c['sex']}' != before) store.markChanged('c:$id');
    }

    var inserted = 0, updated = 0;
    final now = nowMs();
    for (final r in records) {
      final id = naraEventId(familyId, r.sourceId);
      final old = store.events[id];
      old != null ? updated++ : inserted++;
      store.events[id] = eventJson(
        id: id,
        childId: mapping[r.childKey ?? '']!,
        details: normalizeDetails(r.details),
        start: r.start,
        end: r.end,
        note: cleanNote(r.note),
        createdBy: old?['created_by'] ?? _userId,
        updatedBy: _userId,
        createdAt: old?['created_at'] ?? fmt(now),
        updatedAt: now,
        source: 'nara',
      );
      store.markChanged('e:$id');
    }
    return {
      'tracks': csv.rows,
      'imported': inserted,
      'updated': updated,
      'by_type': sortedByType,
      'skipped': sortedSkipped,
      'nara_children': childrenOut(),
      'children_created': created,
    };
  }

  /// A stable event id for a Nara record in a family (UUID-shaped, from a SHA-256).
  static String naraEventId(String familyId, String sourceId) {
    final b = const DartSha256().hashSync(utf8.encode('nara\n$familyId\n$sourceId')).bytes.sublist(0, 16);
    b[6] = 0x80 | (b[6] & 0x0f);
    b[8] = 0x80 | (b[8] & 0x3f);
    final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

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
      'today': (computeTrends(events, today, 1, now, day: _dayOf(child))['days'] as List).first,
      'last_24h': last24h(events, now, day: _dayOf(child)),
    };
  }

  Map<String, dynamic> trends(String childId, Map<String, String> q) {
    final child = _child(childId);
    final days = int.tryParse(q['days'] ?? '') ?? 7;
    if (days < 1 || days > 90) throw badRequest('days must be between 1 and 90');
    final to = q['to'] == null ? dateOnly(DateTime.now()) : DateTime.tryParse(q['to']!) ?? (throw badRequest('invalid date'));
    final from = DateTime(to.year, to.month, to.day - days + 1);
    final (r0, r1) = rangeMs(DateTime(from.year, from.month, from.day - days), days * 2);
    return computeTrendsWithPrevious(_trendEvents(childId, r0, r1), from, days, nowMs(), day: _dayOf(child));
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

  /// A saved breastfeed / pump / sleep entry becomes a running timer again (see
  /// `continue_event` on the server).
  Map<String, dynamic> continueEvent(String eventId, Map<String, dynamic> req) {
    final id = req['timer_id'] as String? ?? newId();
    final same = store.timers[id];
    if (same != null && !same.deleted) return same.toApi();
    final e = _event(eventId);
    final kind = continuableKind(e) ?? (throw badRequest('only a breastfeed, pump or sleep entry can be continued'));
    final childId = e['child_id'] as String;
    final running = _timersOf(childId).where((t) => t.kind == kind).firstOrNull;
    if (running != null) throw conflict('a $kind timer is already running (${running.id})');
    final now = nowMs();
    final segs = segmentsFromEvent(kind, startOf(e), endOf(e), e, now);
    final side = checkSide(kind, req['side'] ?? segs.reversed.map((s) => s.side).whereType<String>().firstOrNull);
    segs.add(Segment(side, now));
    deleteEvent(eventId);
    final t = StoredTimer(id: id, childId: childId, kind: kind, segments: segs, createdBy: _userId, createdAt: now, updatedAt: now);
    store.timers[id] = t;
    return _save(t);
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
