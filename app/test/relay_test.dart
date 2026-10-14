import 'package:flutter_test/flutter_test.dart';
import 'package:nestling/local/engine.dart';
import 'package:nestling/local/merge.dart';
import 'package:nestling/local/pairing.dart';
import 'package:nestling/local/persist.dart';
import 'package:nestling/local/relay.dart';
import 'package:nestling/local/store.dart';

/// A phone's folder in memory, like its Drive folder.
class MemoryFolder implements RelayFolder {
  final files = <String, (String, List<int>, int)>{};
  int writes = 0, reads = 0;

  @override
  Future<List<RelayFile>> list() async => [for (final MapEntry(:key, :value) in files.entries) RelayFile(key, value.$1, '${value.$3}')];

  @override
  Future<List<int>> read(String fileId) async {
    reads++;
    return files[fileId]!.$2;
  }

  @override
  Future<String> write(String name, List<int> bytes, {String? fileId}) async {
    writes++;
    final id = fileId ?? 'file${files.length + 1}';
    files[id] = (name, bytes, (files[id]?.$3 ?? 0) + 1);
    return id;
  }
}

/// The folders in "Drive", by id.
final drive = <String, MemoryFolder>{};
RelayFolder open(String id) => drive[id] ?? (throw StateError('not found'));

/// [relay] turned on: a folder of its own.
MemoryFolder turnOn(RelaySync relay, String id) {
  relay
    ..on = true
    ..folderId = id;
  return drive[id] = MemoryFolder();
}

Future<(LocalStore, LocalEngine)> phone(String name) async {
  final store = await LocalStore.open(MemoryPersist());
  store.me = {'id': LocalEngine.newId(), 'name': name, 'email': '', 'units': 'metric'};
  return (store, LocalEngine(store)..serverless = true);
}

void main() {
  setUp(drive.clear);

  test('phones that are never open together catch up through their folders', () async {
    final (storeA, a) = await phone('Mom');
    final (storeB, b) = await phone('Dad');
    final fam = a.createFamily({'name': 'Home', 'timezone': 'UTC'});
    final child = a.createChild(fam['id'], {'name': 'Léa', 'birth_date': '2026-06-01'});
    storeA.serverless.addAll({'family_id': fam['id'], 'key': FamilyKey.generate().toBase64()});
    // Paired once (the family and its key went across), then apart.
    mergeFamily(storeB, exportFamily(storeA, fam['id']));
    storeB.serverless.addAll({'family_id': fam['id'], 'key': storeA.serverless['key']});
    final relayA = RelaySync(storeA), relayB = RelaySync(storeB);
    // Both turned Drive sync on after pairing: they find each other's folders at the next
    // Wi-Fi sync or pairing.
    final folderA = turnOn(relayA, 'folderA'), folderB = turnOn(relayB, 'folderB');
    expect(relayA.needsSetup, isFalse);

    final diaper = a.createEvent(child['id'], {'type': 'diaper', 'wet': true});
    expect(await relayA.sync(folderA, open), isFalse);
    expect(await relayB.sync(folderB, open), isFalse, reason: "B doesn't know A's folder yet");
    // Paired again (or any phone that knows both): from now on through Drive only.
    mergeFamily(storeA, exportFamily(storeB, fam['id']));
    mergeFamily(storeB, exportFamily(storeA, fam['id']));
    expect((storeB.families.single['drive_folders'] as Map).values.toSet(), {'folderA', 'folderB'});
    expect(relayB.otherFolders, ['folderA']);
    await relayA.sync(folderA, open);
    expect(storeB.events[diaper['id']]!['wet'], isTrue);

    final feed = b.createEvent(child['id'], {'type': 'feed', 'method': 'bottle', 'amount_ml': 120});
    await relayB.sync(folderB, open);
    expect(await relayA.sync(folderA, open), isTrue);
    expect(storeA.events[feed['id']]!['amount_ml'], 120.0);

    // Nothing new: nothing is downloaded or uploaded.
    await relayA.sync(folderA, open);
    await relayB.sync(folderB, open);
    folderA.writes = folderA.reads = folderB.writes = folderB.reads = 0;
    expect(await relayA.sync(folderA, open), isFalse);
    expect(await relayB.sync(folderB, open), isFalse);
    expect([folderA.writes, folderA.reads, folderB.writes, folderB.reads], [0, 0, 0, 0]);
    expect([folderA.files.length, folderB.files.length], [1, 1], reason: 'one file per phone, in its own folder');

    // A file this family can't read (another key) is skipped.
    folderB.files['stray'] = ('nestling-someone.bin', [1, 2, 3], 1);
    expect(await relayA.sync(folderA, open), isFalse);
    expect(relayA.error, isNull);

    // A folder that is gone (a phone that removed it) doesn't stop the others.
    (storeA.families.single['drive_folders'] as Map)['old-phone'] = 'gone';
    expect(await relayA.sync(folderA, open), isFalse);
    expect(relayA.error, isNull);
  });

  test('a phone that synced through the old shared folder needs turning on again', () async {
    final (store, _) = await phone('Mom');
    final relay = RelaySync(store)..on = true;
    expect(relay.needsSetup, isTrue);
    turnOn(relay, 'mine');
    expect(relay.needsSetup, isFalse);
  });

  test('entry photos go through the folders once, as files of their own', () async {
    final (storeA, a) = await phone('Mom');
    final (storeB, b) = await phone('Dad');
    final fam = a.createFamily({'name': 'Home', 'timezone': 'UTC'});
    final child = a.createChild(fam['id'], {'name': 'Léa', 'birth_date': '2026-06-01'});
    storeA.serverless.addAll({'family_id': fam['id'], 'key': FamilyKey.generate().toBase64()});
    final relayA = RelaySync(storeA), relayB = RelaySync(storeB);
    final folderA = turnOn(relayA, 'folderA'), folderB = turnOn(relayB, 'folderB');
    await relayA.sync(folderA, open); // lists A's folder in the family
    mergeFamily(storeB, exportFamily(storeA, fam['id']));
    storeB.serverless.addAll({'family_id': fam['id'], 'key': storeA.serverless['key']});
    await relayB.sync(folderB, open);
    mergeFamily(storeA, exportFamily(storeB, fam['id'])); // synced once on the same Wi-Fi: A learns B's folder

    final smile = a.createEvent(child['id'], {'type': 'milestone', 'name': 'First smile'});
    final photo = List<int>.generate(3000, (i) => i % 251);
    final withPhoto = a.putEventPhoto(smile['id'], photo, 'image/jpeg');
    await relayA.sync(folderA, open);
    final names = [for (final f in folderA.files.values) f.$1];
    expect(names.where((n) => n.startsWith('photo-')), hasLength(1));
    // The snapshot itself doesn't carry the bytes.
    expect(exportFamily(storeA, fam['id'], photoData: false)['event_photos'][smile['id']].containsKey('data'), isFalse);

    expect(await relayB.sync(folderB, open), isTrue);
    expect(storeB.events[smile['id']]!['photo_version'], withPhoto['photo_version']);
    expect(b.eventPhotoBytes(smile['id']), photo);

    // Already in the folder: not uploaded again by either phone.
    folderA.writes = folderB.writes = 0;
    await relayB.sync(folderB, open);
    await relayA.sync(folderA, open);
    expect([folderA.writes, folderB.writes], [0, 0]);

    // Removed on one phone, removed on the other.
    b.deleteEventPhoto(smile['id']);
    await relayB.sync(folderB, open);
    await relayA.sync(folderA, open);
    expect(storeA.events[smile['id']]!['photo_version'], isNull);
    expect(() => a.eventPhotoBytes(smile['id']), throwsA(anything));
  });
}
