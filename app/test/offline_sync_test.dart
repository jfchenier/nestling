import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nestling/api/api.dart';
import 'package:nestling/api/sync_api.dart';
import 'package:nestling/local/persist.dart';
import 'package:nestling/local/store.dart';

/// A fake server that can be switched off, recording what it receives.
class FakeServer {
  bool up = true;

  /// Answer this status instead (a reverse proxy whose server is down).
  int? proxyStatus;
  final pushes = <Map<String, dynamic>>[];
  final events = <Map<String, dynamic>>[];
  final timers = <String, Map<String, dynamic>>{};
  String pushStatus = 'applied';

  /// While set, logging requests wait for it (a slow connection).
  Completer<void>? gate;
  Map<String, dynamic>? pushCurrent;

  static const child = {'id': 'c1', 'family_id': 'f1', 'name': 'Léa'};

  late final client = MockClient((req) async {
    if (!up) throw http.ClientException('connection refused');
    if (proxyStatus != null) return http.Response('Bad Gateway', proxyStatus!);
    final path = req.url.path.replaceFirst('/api/v1', '');
    final body = req.body.isEmpty ? null : jsonDecode(req.body);
    http.Response json(Object? v, [int status = 200]) => http.Response(jsonEncode(v), status, headers: {'content-type': 'application/json'});
    if (gate != null && req.method != 'GET') await gate!.future;
    final seg = path.split('/').where((s) => s.isNotEmpty).toList();
    switch ((req.method, seg)) {
      case ('POST', ['children', 'c1', 'timers']):
        final t = <String, dynamic>{
          'id': body['id'],
          'child_id': 'c1',
          'kind': body['kind'],
          'started_at': '2026-10-09T10:00:00+00:00',
          'running': true,
          'segments': [{'side': null, 'start': '2026-10-09T10:00:00+00:00', 'end': null}],
        };
        timers[t['id']] = t;
        return json(t, 201);
      case ('POST', ['timers', final id, 'stop']):
        if (timers.remove(id) == null) return json({'error': {'code': 'not_found', 'message': 'timer not found'}}, 404);
        final e = <String, dynamic>{'id': body['event_id'], 'child_id': 'c1', 'type': 'sleep', 'start': '2026-10-09T10:00:00+00:00', 'end': '2026-10-09T10:30:00+00:00'};
        events.add(e);
        return json(e);
      case ('GET', ['events', final id]):
        final e = events.where((e) => e['id'] == id).firstOrNull;
        return e == null ? json({'error': {'code': 'not_found', 'message': 'event not found'}}, 404) : json(e);
      case ('GET', ['timers', final id]):
        final t = timers[id];
        return t == null ? json({'error': {'code': 'not_found', 'message': 'timer not found'}}, 404) : json(t);
    }
    switch ((req.method, path)) {
      case ('GET', '/health'):
        return http.Response('{"status":"ok"}', 200);
      case ('GET', '/me'):
        return json({'id': 'u1', 'name': 'Mom', 'email': 'mom@example.com', 'units': 'metric'});
      case ('GET', '/families'):
        return json({
          'families': [
            {
              'id': 'f1',
              'name': 'Home',
              'timezone': 'UTC',
              'children': [child],
            },
          ],
        });
      case ('POST', '/children/c1/events'):
        final e = <String, dynamic>{...body, 'child_id': 'c1', 'start': '2026-10-09T10:00:00+00:00', 'created_at': '2026-10-09T10:00:00+00:00', 'updated_at': '2026-10-09T10:00:00+00:00'};
        events.add(e);
        return json(e, 201);
      case ('POST', '/families/f1/sync'):
        pushes.add(body);
        Map<String, dynamic> res(r) => {'id': r['id'], 'status': pushStatus, if (pushStatus != 'applied') 'current': pushCurrent};
        return json({
          'events': [for (final r in body['events']) res(r)],
          'timers': [for (final r in body['timers']) {'id': r['id'], 'status': 'applied'}],
        });
      case ('GET', '/families/f1/sync'):
        return json({'cursor': 1000, 'full': req.url.queryParameters['since'] == null, 'children': [child], 'events': events, 'timers': timers.values.toList()});
    }
    return json({'error': {'code': 'not_found', 'message': 'no such endpoint'}}, 404);
  });
}

void main() {
  late FakeServer server;
  late LocalStore store;
  late SyncApi api;

  setUp(() async {
    server = FakeServer();
    store = await LocalStore.open(MemoryPersist());
    api = SyncApi('http://nestling.test', 'token', store, server.client);
    SyncApi.retryEvery = const Duration(hours: 1);
    await api.get('/me');
    await api.get('/families');
  });

  tearDown(() => api.close());

  test('online writes go straight to the server, with an id chosen on the device', () async {
    final e = await api.post('/children/c1/events', {'type': 'diaper', 'wet': true});
    expect(server.events, hasLength(1));
    expect(e['id'], isA<String>());
    expect(store.events[e['id']], isNotNull, reason: 'mirrored locally');
    expect(api.pending, 0);
  });

  test('offline: logging keeps working and syncs on reconnection', () async {
    server.up = false;
    final diaper = await api.post('/children/c1/events', {'type': 'diaper', 'wet': true});
    expect(api.offline, isTrue);
    final timer = await api.post('/children/c1/timers', {'kind': 'sleep', 'start': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String()});
    expect(timer['running'], isTrue);
    final sleep = await api.post('/timers/${timer['id']}/stop', {});
    expect(sleep['type'], 'sleep');
    expect(sleep['duration_seconds'], greaterThanOrEqualTo(1799));
    expect(api.pending, 3);

    final summary = await api.get('/children/c1/summary');
    expect(summary['last']['diaper']['id'], diaper['id']);
    expect(summary['timers'], isEmpty);
    expect(summary['last_24h']['diaper']['count'], 1);
    final list = await api.get('/children/c1/events', {'limit': '10'});
    expect(list['events'], hasLength(2));

    // Not sent anywhere while offline.
    expect(server.pushes, isEmpty);

    server.up = true;
    api.offline = false;
    await api.sync();
    expect(api.pending, 0);
    final push = server.pushes.single;
    expect([for (final e in push['events']) e['type']], unorderedEquals(['diaper', 'sleep']));
    expect(push['events'].every((e) => e['changed_at'] is String), isTrue);
    expect(push['timers'].single, containsPair('deleted', true));
    expect(store.timers, isEmpty);
  });

  test('a change the server rejects is replaced by its copy, with a notice', () async {
    server.up = false;
    final e = await api.post('/children/c1/events', {'type': 'diaper', 'wet': true});
    await api.patch('/events/${e['id']}', {'dirty': true});
    expect(api.pending, 1);
    server
      ..up = true
      ..pushStatus = 'conflict'
      ..pushCurrent = {...e, 'dry': true};
    server.events.add(server.pushCurrent!);
    api.offline = false;
    await api.sync();
    expect(api.pending, 0);
    expect(store.events[e['id']]!['dry'], isTrue);
    expect(api.notices.single, contains('newer change was kept'));
  });

  test('a proxy answering 502 counts as offline', () async {
    server.proxyStatus = 502;
    final e = await api.post('/children/c1/events', {'type': 'diaper', 'dry': true});
    expect(api.offline, isTrue);
    expect(e['dry'], isTrue);
    expect(api.pending, 1);
  });

  test('requests that need the server say so when offline', () async {
    server.up = false;
    await expectLater(api.get('/admin/users'), throwsA(predicate((e) => '$e'.contains('offline'))));
  });

  group('online, with the family\'s data on the device', () {
    setUp(() => api.pull('f1'));

    test('a change shows at once and reaches the server in the background', () async {
      server.gate = Completer();
      final e = await api.post('/children/c1/events', {'type': 'diaper', 'wet': true});
      expect(server.events, isEmpty, reason: 'not waiting for the server');
      expect(api.pending, 0, reason: 'on its way, not waiting for a reconnection');
      final summary = await api.get('/children/c1/summary');
      expect(summary['last']['diaper']['id'], e['id']);

      server.gate!.complete();
      await pumpEventQueue();
      expect(server.events.single['id'], e['id']);
      expect(store.pendingCount, 0);
      expect(server.pushes, isEmpty, reason: 'sent as the request itself');
    });

    test('changes are sent in order', () async {
      server.gate = Completer();
      final t = await api.post('/children/c1/timers', {'kind': 'sleep'});
      final sleep = await api.post('/timers/${t['id']}/stop', {});
      expect(sleep['type'], 'sleep');
      expect((await api.get('/children/c1/summary'))['timers'], isEmpty);
      server.gate!.complete();
      await pumpEventQueue();
      expect(server.timers, isEmpty);
      expect(server.events.single['id'], sleep['id']);
      expect(store.pendingCount, 0);
      expect(api.notices, isEmpty);
    });

    test('a timer already stopped on another phone: the local change is undone, with a notice', () async {
      final t = await api.post('/children/c1/timers', {'kind': 'sleep'});
      await pumpEventQueue();
      expect(server.timers, contains(t['id']));
      server.timers.clear(); // Stopped elsewhere; this phone hasn't heard yet.

      final sleep = await api.post('/timers/${t['id']}/stop', {});
      expect(store.events, contains(sleep['id']));
      await pumpEventQueue();
      expect(store.events, isNot(contains(sleep['id'])), reason: 'no duplicate entry');
      expect(store.timers, isEmpty);
      expect(store.pendingCount, 0);
      expect(api.notices.single, contains('already stopped on another phone'));
    });

    test('server unreachable on the way: kept and synced on reconnection', () async {
      server.up = false;
      final e = await api.post('/children/c1/events', {'type': 'diaper', 'dry': true});
      await pumpEventQueue();
      expect(api.offline, isTrue);
      expect(api.pending, 1);
      server.up = true;
      api.offline = false;
      await api.sync();
      expect(api.pending, 0);
      expect(server.pushes.single['events'].single['id'], e['id']);
    });

    test('local validation errors are thrown right away', () async {
      await expectLater(api.post('/children/c1/events', {'type': 'nope'}), throwsA(isA<ApiException>()));
      expect(store.pendingCount, 0);
    });
  });
}
