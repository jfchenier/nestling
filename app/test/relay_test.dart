import 'package:flutter_test/flutter_test.dart';
import 'package:nestling/local/engine.dart';
import 'package:nestling/local/merge.dart';
import 'package:nestling/local/pairing.dart';
import 'package:nestling/local/persist.dart';
import 'package:nestling/local/relay.dart';
import 'package:nestling/local/store.dart';

/// A shared folder in memory, like the family's Drive folder.
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

Future<(LocalStore, LocalEngine)> phone(String name) async {
  final store = await LocalStore.open(MemoryPersist());
  store.me = {'id': LocalEngine.newId(), 'name': name, 'email': '', 'units': 'metric'};
  return (store, LocalEngine(store)..serverless = true);
}

void main() {
  test('phones that are never open together catch up through the shared folder', () async {
    final folder = MemoryFolder();
    final (storeA, a) = await phone('Mom');
    final (storeB, b) = await phone('Dad');
    final fam = a.createFamily({'name': 'Home', 'timezone': 'UTC'});
    final child = a.createChild(fam['id'], {'name': 'Léa', 'birth_date': '2026-06-01'});
    storeA.families.single['drive_folder'] = 'folder1';
    storeA.serverless.addAll({'family_id': fam['id'], 'key': FamilyKey.generate().toBase64()});
    // Paired once (the family and its key went across), then apart.
    mergeFamily(storeB, exportFamily(storeA, fam['id']));
    storeB.serverless.addAll({'family_id': fam['id'], 'key': storeA.serverless['key']});
    final relayA = RelaySync(storeA), relayB = RelaySync(storeB);

    final diaper = a.createEvent(child['id'], {'type': 'diaper', 'wet': true});
    expect(await relayA.sync(folder), isFalse);
    expect(await relayB.sync(folder), isTrue);
    expect(storeB.events[diaper['id']]!['wet'], isTrue);

    final feed = b.createEvent(child['id'], {'type': 'feed', 'method': 'bottle', 'amount_ml': 120});
    await relayB.sync(folder);
    expect(await relayA.sync(folder), isTrue);
    expect(storeA.events[feed['id']]!['amount_ml'], 120.0);

    // Nothing new: nothing is downloaded or uploaded.
    await relayA.sync(folder);
    await relayB.sync(folder);
    folder.writes = folder.reads = 0;
    expect(await relayA.sync(folder), isFalse);
    expect(await relayB.sync(folder), isFalse);
    expect([folder.writes, folder.reads], [0, 0]);
    expect(folder.files, hasLength(2), reason: 'one file per phone');

    // A file this family can't read (another key) is skipped.
    folder.files['stray'] = ('nestling-someone.bin', [1, 2, 3], 1);
    expect(await relayA.sync(folder), isFalse);
    expect(relayA.error, isNull);
  });

  test('entry photos go through the folder once, as files of their own', () async {
    final folder = MemoryFolder();
    final (storeA, a) = await phone('Mom');
    final (storeB, b) = await phone('Dad');
    final fam = a.createFamily({'name': 'Home', 'timezone': 'UTC'});
    final child = a.createChild(fam['id'], {'name': 'Léa', 'birth_date': '2026-06-01'});
    storeA.families.single['drive_folder'] = 'folder1';
    storeA.serverless.addAll({'family_id': fam['id'], 'key': FamilyKey.generate().toBase64()});
    mergeFamily(storeB, exportFamily(storeA, fam['id']));
    storeB.serverless.addAll({'family_id': fam['id'], 'key': storeA.serverless['key']});
    final relayA = RelaySync(storeA), relayB = RelaySync(storeB);

    final smile = a.createEvent(child['id'], {'type': 'milestone', 'name': 'First smile'});
    final photo = List<int>.generate(3000, (i) => i % 251);
    final withPhoto = a.putEventPhoto(smile['id'], photo, 'image/jpeg');
    await relayA.sync(folder);
    final names = [for (final f in folder.files.values) f.$1];
    expect(names.where((n) => n.startsWith('photo-')), hasLength(1));
    // The snapshot itself doesn't carry the bytes.
    expect(exportFamily(storeA, fam['id'], photoData: false)['event_photos'][smile['id']].containsKey('data'), isFalse);

    expect(await relayB.sync(folder), isTrue);
    expect(storeB.events[smile['id']]!['photo_version'], withPhoto['photo_version']);
    expect(b.eventPhotoBytes(smile['id']), photo);

    // Already in the folder: not uploaded again by either phone.
    folder.writes = 0;
    await relayB.sync(folder);
    await relayA.sync(folder);
    expect(folder.writes, 0);

    // Removed on one phone, removed on the other.
    b.deleteEventPhoto(smile['id']);
    await relayB.sync(folder);
    await relayA.sync(folder);
    expect(storeA.events[smile['id']]!['photo_version'], isNull);
    expect(() => a.eventPhotoBytes(smile['id']), throwsA(anything));
  });
}
