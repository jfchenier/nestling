import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nestling/api/api.dart';
import 'package:nestling/api/sync_api.dart';
import 'package:nestling/local/persist.dart';
import 'package:nestling/local/photo_cache.dart';
import 'package:nestling/local/store.dart';

/// A fake server that can be switched off, recording what it receives.
class FakeServer {
  bool up = true;

  /// Answer this status instead (a reverse proxy whose server is down).
  int? proxyStatus;
  final pushes = <Map<String, dynamic>>[];
  final events = <Map<String, dynamic>>[];
  final timers = <String, Map<String, dynamic>>{};
  final photos = <String, Uint8List>{};
  final prints = <String, Uint8List>{};
  int photoGets = 0;
  String pushStatus = 'applied';

  /// While set, logging requests wait for it (a slow connection).
  Completer<void>? gate;
  Map<String, dynamic>? pushCurrent;

  static const child = {'id': 'c1', 'family_id': 'f1', 'name': 'Léa'};

  late final client = MockClient((req) async {
    if (!up) throw http.ClientException('connection refused');
    if (proxyStatus != null) return http.Response('Bad Gateway', proxyStatus!);
    final path = req.url.path.replaceFirst('/api/v1', '');
    final body = !(req.headers['content-type'] ?? '').startsWith('application/json') || req.body.isEmpty ? null : jsonDecode(req.body);
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
      case ('PUT', ['events', final id, 'photo']):
        final e = events.where((e) => e['id'] == id).firstOrNull;
        if (e == null) return json({'error': {'code': 'not_found', 'message': 'event not found'}}, 404);
        photos[id] = req.bodyBytes;
        prints.remove(id);
        e['photo_version'] = 5000 + photos.length;
        e.remove('photo_print');
        return json(e);
      case ('PUT', ['events', final id, 'photo', 'print']):
        final e = events.where((e) => e['id'] == id).firstOrNull;
        if (e == null || !photos.containsKey(id)) return json({'error': {'code': 'not_found', 'message': 'photo not found'}}, 404);
        prints[id] = req.bodyBytes;
        e['photo_print'] = true;
        return json(e);
      case ('DELETE', ['events', final id, 'photo']):
        photos.remove(id);
        prints.remove(id);
        events.where((e) => e['id'] == id).firstOrNull?['photo_version'] = null;
        return http.Response('', 204);
      case ('GET', ['events', final id, 'photo']):
        photoGets++;
        final bytes = photos[id];
        return bytes == null ? json({'error': {'code': 'not_found', 'message': 'photo not found'}}, 404) : http.Response.bytes(bytes, 200);
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
        if (pushStatus == 'applied') {
          for (final r in body['events']) {
            events
              ..removeWhere((e) => e['id'] == r['id'])
              ..add({...r}..remove('changed_at'));
          }
        }
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
  late MemoryPersist persist;
  late SyncApi api;

  setUp(() async {
    server = FakeServer();
    persist = MemoryPersist();
    store = await LocalStore.open(persist);
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

  group('book photos', () {
    final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 1, 2, 3]);
    final big = Uint8List.fromList([0xFF, 0xD8, 0xFF, ...List.filled(64, 9)]);
    MemoryPhotoCache cache() => store.photoCache as MemoryPhotoCache;

    setUp(() => api.pull('f1'));

    test('online: sent at once and kept on the device', () async {
      final e = await api.post('/children/c1/events', {'type': 'milestone', 'name': 'First smile'});
      final res = await api.putBytes('/events/${e['id']}/photo', jpeg, contentType: 'image/jpeg');
      expect(server.photos[e['id']], jpeg);
      expect(res['photo_version'], 5001);
      expect(await store.photoCache.read('e-${e['id']}', 5001), jpeg);
      expect(api.pending, 0);
    });

    test('offline: kept here, shown, and sent after the entry on reconnection', () async {
      server.up = false;
      final e = await api.post('/children/c1/events', {'type': 'milestone', 'name': 'First smile'});
      final res = await api.putBytes('/events/${e['id']}/photo', jpeg, contentType: 'image/jpeg');
      expect(api.offline, isTrue);
      final local = res['photo_version'] as int;
      expect(await store.photoCache.read('e-${e['id']}', local), jpeg);
      expect(api.pending, 2, reason: 'the entry and its photo');
      final listed = await api.get('/children/c1/events', {'type': 'milestone'});
      expect(listed['events'].single['photo_version'], local);

      // Saved on the device: still there after the app restarts.
      await store.flush();
      expect((await LocalStore.open(persist)).photoUploads, {e['id']: local});

      server.up = true;
      api.offline = false;
      await api.sync();
      expect(api.pending, 0);
      expect(server.photos[e['id']], jpeg);
      expect(store.events[e['id']]!['photo_version'], 5001);
      expect(await store.photoCache.read('e-${e['id']}', 5001), jpeg, reason: 'kept under the server\'s version');
      expect(cache().data, hasLength(1));
    });

    test('a photo set on an entry the server has, while offline', () async {
      final e = await api.post('/children/c1/events', {'type': 'milestone', 'name': 'First smile'});
      await pumpEventQueue();
      server.up = false;
      await api.putBytes('/events/${e['id']}/photo', jpeg, contentType: 'image/jpeg');
      expect(api.offline, isTrue);
      expect(server.photos, isEmpty);
      // A pull meanwhile doesn't hide the photo waiting here.
      store.putEvent({...server.events.single});
      expect(store.events[e['id']]!['photo_version'], isNotNull);
      server.up = true;
      api.offline = false;
      await api.sync();
      expect(server.photos[e['id']], jpeg);
      expect(server.pushes, isEmpty, reason: 'only the photo was waiting');
    });

    test('removed offline: removed on the server on reconnection', () async {
      final e = await api.post('/children/c1/events', {'type': 'milestone', 'name': 'First smile'});
      await pumpEventQueue();
      await api.putBytes('/events/${e['id']}/photo', jpeg, contentType: 'image/jpeg');
      server.up = false;
      await api.delete('/events/${e['id']}/photo');
      expect(store.events[e['id']]!['photo_version'], isNull);
      expect(cache().data, isEmpty);
      server.up = true;
      api.offline = false;
      await api.sync();
      expect(server.photos, isEmpty);
      expect(api.pending, 0);
    });

    test('print copy: sent after the photo, not kept on the device', () async {
      final e = await api.post('/children/c1/events', {'type': 'milestone', 'name': 'First smile'});
      await api.putBytes('/events/${e['id']}/photo', jpeg, contentType: 'image/jpeg');
      final res = await api.putBytes('/events/${e['id']}/photo/print', big, contentType: 'image/jpeg');
      expect(server.prints[e['id']], big);
      expect(res['photo_print'], isTrue);
      expect(store.events[e['id']]!['photo_print'], isTrue);
      expect(cache().data.keys, ['e-${e['id']}']);
      expect(api.pending, 0);
    });

    test('print copy offline: waits for the entry and its photo, then is forgotten', () async {
      server.up = false;
      final e = await api.post('/children/c1/events', {'type': 'milestone', 'name': 'First smile'});
      await api.putBytes('/events/${e['id']}/photo', jpeg, contentType: 'image/jpeg');
      await api.putBytes('/events/${e['id']}/photo/print', big, contentType: 'image/jpeg');
      expect(api.pending, 3, reason: 'the entry, its photo and the print copy');
      await store.flush();
      expect((await LocalStore.open(persist)).printUploads.keys, [e['id']]);

      server.up = true;
      api.offline = false;
      await api.sync();
      expect(api.pending, 0);
      expect(server.photos[e['id']], jpeg);
      expect(server.prints[e['id']], big);
      expect(store.events[e['id']]!['photo_print'], isTrue);
      expect(cache().data.keys, ['e-${e['id']}'], reason: 'the print copy is forgotten once sent');
    });

    test('a new photo drops the print copy still waiting for the one before', () async {
      final e = await api.post('/children/c1/events', {'type': 'milestone', 'name': 'First smile'});
      await pumpEventQueue();
      server.up = false;
      await api.putBytes('/events/${e['id']}/photo', jpeg, contentType: 'image/jpeg');
      await api.putBytes('/events/${e['id']}/photo/print', big, contentType: 'image/jpeg');
      await api.delete('/events/${e['id']}/photo');
      expect(store.printUploads, isEmpty);
      expect(cache().data, isEmpty);
      server.up = true;
      api.offline = false;
      await api.sync();
      expect(server.prints, isEmpty);
      expect(api.pending, 0);
    });

    test('an entry deleted before its photo went up: the photo is dropped', () async {
      server.up = false;
      final e = await api.post('/children/c1/events', {'type': 'milestone', 'name': 'First smile'});
      await api.putBytes('/events/${e['id']}/photo', jpeg, contentType: 'image/jpeg');
      await api.delete('/events/${e['id']}');
      server.up = true;
      api.offline = false;
      await api.sync();
      expect(server.photos, isEmpty);
      expect(store.photoUploads, isEmpty);
      expect(api.pending, 0);
    });
  });
}
