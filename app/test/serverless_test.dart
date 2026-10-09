import 'package:flutter_test/flutter_test.dart';
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

  @override
  Future<List<int>> post(String host, int port, List<int> body) async {
    final h = wifi.phones[host] ?? (throw StateError('unreachable'));
    return h(body, this.host);
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
