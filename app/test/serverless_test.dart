import 'package:flutter_test/flutter_test.dart';
import 'package:nestling/api/api.dart';
import 'package:nestling/local/engine.dart';
import 'package:nestling/local/merge.dart';
import 'package:nestling/local/pairing.dart';
import 'package:nestling/local/peer_sync.dart';
import 'package:nestling/local/persist.dart';
import 'package:nestling/local/store.dart';
import 'package:nestling/local/transport.dart';

/// Phones on one pretend Wi-Fi: requests go straight to the other phone's handler.
class FakeWifi {
  final Map<String, PeerHandler> phones = {};
}

class FakeTransport implements PeerTransport {
  FakeTransport(this.wifi, this.host);
  final FakeWifi wifi;
  final String host;

  @override
  bool get available => true;

  @override
  Future<int> listen(PeerHandler handler, {required int preferredPort}) async {
    wifi.phones[host] = handler;
    return preferredPort;
  }

  /// Bytes sent and received, for checking that only changes travel.
  int traffic = 0;

  @override
  Future<List<int>> post(String host, int port, List<int> body) async {
    final h = wifi.phones[host] ?? (throw StateError('unreachable'));
    final answer = await h(body, this.host);
    traffic += body.length + answer.length;
    return answer;
  }

  @override
  Future<List<String>> localAddresses() async => [host];

  @override
  Future<void> announce(String message, void Function(String message, String host) onMessage) async {}

  @override
  Future<void> close() async => wifi.phones.remove(host);
}

Future<(LocalStore, LocalEngine)> phone(String name) async {
  final store = await LocalStore.open(MemoryPersist());
  store.me = {'id': LocalEngine.newId(), 'name': name, 'email': '', 'units': 'metric'};
  return (store, LocalEngine(store)..serverless = true);
}

void main() {
  setUp(() => PeerSync.every = const Duration(hours: 1));

  test('adding a baby needs a birth date', () async {
    final (_, a) = await phone('Mom');
    final fam = a.createFamily({'name': 'Home', 'timezone': 'UTC'});
    expect(
      () => a.handle('POST', '/families/${fam['id']}/children', body: {'name': 'Léa'}),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('birth_date'))),
    );
    final c = a.handle('POST', '/families/${fam['id']}/children', body: {'name': 'Léa', 'birth_date': '2026-06-01'});
    expect(c['birth_date'], '2026-06-01');
    // A baby saved earlier without one can still be edited.
    final old = a.createChild(fam['id'], {'name': 'B'});
    expect(a.handle('PATCH', '/children/${old['id']}', body: {'name': 'Bea', 'birth_date': null})['name'], 'Bea');
  });

  test('a saved feed can be continued as a timer, like on the server', () async {
    final (store, a) = await phone('Mom');
    final fam = a.createFamily({'name': 'Home', 'timezone': 'UTC'});
    final c = a.createChild(fam['id'], {'name': 'Léa', 'birth_date': '2026-06-01'});
    final start = DateTime.now().subtract(const Duration(minutes: 30));
    final ev = a.handle('POST', '/children/${c['id']}/events', body: {
      'type': 'feed',
      'method': 'breast',
      'start': start.toIso8601String(),
      'end': start.add(const Duration(minutes: 20)).toIso8601String(),
      'left_seconds': 600,
      'right_seconds': 300,
      'start_side': 'left',
    });
    final t = a.handle('POST', '/events/${ev['id']}/continue', body: {});
    expect(t['kind'], 'breastfeed');
    expect(t['running'], isTrue);
    expect(t['side'], 'right', reason: 'goes on where it ended');
    expect(t['left_seconds'], 600);
    expect(t['right_seconds'], inInclusiveRange(300, 301));
    expect(DateTime.parse(t['started_at']).difference(start).inSeconds.abs(), lessThan(1));
    expect(() => a.handle('GET', '/events/${ev['id']}'), throwsA(isA<ApiException>()));
    expect(store.pending.keys, containsAll(['e:${ev['id']}', 't:${t['id']}']));
    // Saved again: the same start and start side, a bit more time.
    final again = a.handle('POST', '/timers/${t['id']}/stop', body: {});
    expect(again['start_side'], 'left');
    expect(again['right_seconds'], greaterThanOrEqualTo(300));
    // Only while no timer of that kind runs, and only for timed entries.
    a.handle('POST', '/children/${c['id']}/timers', body: {'kind': 'breastfeed'});
    expect(() => a.handle('POST', '/events/${again['id']}/continue', body: {}), throwsA(isA<ApiException>()));
    final bottle = a.handle('POST', '/children/${c['id']}/events', body: {'type': 'feed', 'method': 'bottle', 'amount_ml': 90});
    expect(() => a.handle('POST', '/events/${bottle['id']}/continue', body: {}), throwsA(isA<ApiException>()));
  });

  test('pairing brings the family over, and changes flow both ways', () async {
    final wifi = FakeWifi();
    final (storeA, a) = await phone('Mom');
    final (storeB, b) = await phone('Dad');
    final fam = a.createFamily({'name': 'Home', 'timezone': 'UTC'});
    final child = a.createChild(fam['id'], {'name': 'Léa', 'birth_date': '2026-06-01'});
    final diaper = a.createEvent(child['id'], {'type': 'diaper', 'wet': true});

    final syncA = PeerSync(storeA, transport: FakeTransport(wifi, '10.0.0.1'));
    final syncB = PeerSync(storeB, transport: FakeTransport(wifi, '10.0.0.2'));
    final code = await syncA.pairingCode(fam['id']);
    await syncB.join(code);

    expect(storeB.child(child['id'])!['name'], 'Léa');
    expect(storeB.events[diaper['id']]!['wet'], isTrue);
    expect([for (final m in storeA.families.single['members']) m['name']], unorderedEquals(['Mom', 'Dad']));
    expect(syncA.peers.values.single['name'], 'Dad');

    // Dad logs a feed; Mom edits the diaper; one round brings both to both phones.
    final feed = b.createEvent(child['id'], {'type': 'feed', 'method': 'bottle', 'amount_ml': 90});
    await Future<void>.delayed(const Duration(milliseconds: 5));
    a.updateEvent(diaper['id'], {'dirty': true});
    await syncB.syncAll();
    expect(storeA.events[feed['id']]!['amount_ml'], 90.0);
    expect(storeB.events[diaper['id']]!['dirty'], isTrue);

    // Concurrent edits: the later one wins on both phones; a deletion syncs as a tombstone.
    b.updateEvent(diaper['id'], {'dry': true});
    await Future<void>.delayed(const Duration(milliseconds: 5));
    a.deleteEvent(diaper['id']);
    await syncA.syncAll();
    expect(storeB.events[diaper['id']]!['deleted'], isTrue);
    expect(storeA.events[diaper['id']]!['deleted'], isTrue);

    // Both started a sleep timer while apart: the earlier start stays on both.
    final apart = Map.of(wifi.phones);
    wifi.phones.clear();
    final early = a.startTimer(child['id'], {'kind': 'sleep', 'start': DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String()});
    b.startTimer(child['id'], {'kind': 'sleep', 'start': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String()});
    await syncB.syncAll();
    expect(syncB.peers.values.single['error'], isNotNull, reason: 'out of reach');
    wifi.phones.addAll(apart);
    await syncB.syncAll();
    await syncA.syncAll();
    for (final s in [storeA, storeB]) {
      expect([for (final t in s.timersOf(child['id'])) t.id], [early['id']]);
    }
    await syncA.stop();
    await syncB.stop();
  });

  test('after the first sync only changes travel, also through a third phone', () async {
    final wifi = FakeWifi();
    final (storeA, a) = await phone('Mom');
    final (storeB, b) = await phone('Dad');
    final (storeC, _) = await phone('Grandma');
    final fam = a.createFamily({'name': 'Home', 'timezone': 'UTC'});
    final child = a.createChild(fam['id'], {'name': 'Léa', 'birth_date': '2026-06-01'});
    for (var i = 0; i < 300; i++) {
      a.createEvent(child['id'], {'type': 'diaper', 'wet': true, 'start': DateTime(2026, 7, 1).add(Duration(hours: i)).toIso8601String()});
    }
    final tA = FakeTransport(wifi, '10.0.0.1'), tB = FakeTransport(wifi, '10.0.0.2'), tC = FakeTransport(wifi, '10.0.0.3');
    final syncA = PeerSync(storeA, transport: tA), syncB = PeerSync(storeB, transport: tB), syncC = PeerSync(storeC, transport: tC);
    await syncB.join(await syncA.pairingCode(fam['id']));
    final full = tB.traffic;
    expect(storeB.eventsOf(child['id']).length, 300);

    // Nothing changed: a round is tiny (the family and baby only).
    tA.traffic = tB.traffic = 0;
    await syncB.syncAll();
    await syncA.syncAll();
    expect(tA.traffic + tB.traffic, lessThan(full ~/ 10));

    // One change goes across, and is not sent again afterwards.
    final feed = b.createEvent(child['id'], {'type': 'feed', 'method': 'bottle', 'amount_ml': 90});
    await syncB.syncAll();
    expect(storeA.events[feed['id']]!['amount_ml'], 90.0);
    tA.traffic = tB.traffic = 0;
    await syncA.syncAll();
    await syncB.syncAll();
    expect(tA.traffic + tB.traffic, lessThan(full ~/ 10));

    // Grandma pairs through Dad's phone and still gets Mom's history and new entries.
    await syncC.join(await syncB.pairingCode(fam['id']));
    expect(storeC.eventsOf(child['id']).length, 301);
    final sleep = a.createEvent(child['id'], {'type': 'sleep', 'start': '2026-10-01T13:00', 'end': '2026-10-01T14:00'});
    await syncA.syncAll();
    await syncB.syncAll();
    expect(storeC.events[sleep['id']], isNotNull);

    // When unsure what the other phone has, everything is sent again.
    syncA.peers.values.firstWhere((p) => p['name'] == 'Dad')['acked_replica'] = 'an older copy';
    tA.traffic = 0;
    await syncA.syncAll();
    expect(tA.traffic, greaterThan(full ~/ 2));
    for (final s in [syncA, syncB, syncC]) {
      await s.stop();
    }
  });

  test('real HTTP between two phones on this machine', () async {
    final (storeA, a) = await phone('Mom');
    final (storeB, _) = await phone('Dad');
    final fam = a.createFamily({'name': 'Home'});
    final c = a.createChild(fam['id'], {'name': 'B'});
    a.createEvent(c['id'], {'type': 'diaper', 'wet': true});
    final syncA = PeerSync(storeA, transport: platformTransport());
    final syncB = PeerSync(storeB, transport: platformTransport());
    final code = PairingCode.parse(await syncA.pairingCode(fam['id']));
    final local = PairingCode(familyId: code.familyId, key: code.key, hosts: ['127.0.0.1'], port: code.port, name: 'Mom');
    await syncB.join(local.toString());
    expect(storeB.eventsOf(c['id']), hasLength(1));
    await syncA.stop();
    await syncB.stop();
  });

  test('a wrong key is refused', () async {
    final wifi = FakeWifi();
    final (storeA, a) = await phone('Mom');
    final (storeB, _) = await phone('Stranger');
    final fam = a.createFamily({'name': 'Home'});
    final syncA = PeerSync(storeA, transport: FakeTransport(wifi, '10.0.0.1'));
    final code = await syncA.pairingCode(fam['id']);
    // Same family and address, different key.
    final forged = await PeerSync(await LocalStore.open(MemoryPersist()), transport: FakeTransport(FakeWifi(), 'x')).pairingCode('other');
    expect(forged, isNot(code));
    final syncB = PeerSync(storeB, transport: FakeTransport(wifi, '10.0.0.2'));
    storeB.serverless
      ..['family_id'] = fam['id']
      ..['key'] = (await LocalStore.open(MemoryPersist())).serverless['key'] ?? 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';
    storeB.serverless['peers'] = {
      'a': {'host': '10.0.0.1', 'port': PeerSync.port},
    };
    await syncB.syncAll();
    expect(storeB.families, isEmpty);
    expect(syncB.peers['a']['error'], isNotNull);
    await syncA.stop();
  });

  test('merging the same snapshot twice changes nothing', () async {
    final (storeA, a) = await phone('Mom');
    final (storeB, _) = await phone('Dad');
    final fam = a.createFamily({'name': 'Home'});
    final c = a.createChild(fam['id'], {'name': 'B'});
    a.createEvent(c['id'], {'type': 'diaper', 'wet': true});
    a.deleteChild(c['id']);
    final snap = exportFamily(storeA, fam['id']);
    expect(mergeFamily(storeB, snap), isTrue);
    expect(mergeFamily(storeB, snap), isFalse);
    expect(storeB.child(c['id']), isNull, reason: 'the deletion came along');
    expect(storeB.deletedChildren, contains(c['id']));
  });
}
