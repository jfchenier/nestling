import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nestling/api/api.dart';
import 'package:nestling/api/local_api.dart';
import 'package:nestling/local/engine.dart';
import 'package:nestling/local/persist.dart';
import 'package:nestling/local/server_backup.dart';
import 'package:nestling/local/store.dart';

/// Google Drive's app folder, in memory.
class MemoryFiles implements BackupFiles {
  final Map<String, (String, List<int>)> files = {};
  var _next = 0;

  @override
  Future<Map<String, String>> list(String prefix) async => {
    for (final MapEntry(:key, :value) in files.entries)
      if (value.$1.startsWith(prefix)) value.$1: key,
  };

  @override
  Future<void> put(String name, List<int> bytes, String? id, {String contentType = ''}) async =>
      files[id ?? 'f${_next++}'] = (name, bytes);

  @override
  Future<List<int>> get(String id) async => files[id]!.$2;

  @override
  Future<void> delete(String id) async => files.remove(id);

  List<String> get names => [for (final f in files.values) f.$1]..sort();
}

/// A tiny JPEG-looking image (only the header is checked).
List<int> jpeg(int n) => [0xFF, 0xD8, 0xFF, 0xE0, n, n, n];

Future<(LocalStore, LocalApi)> serverlessPhone() async {
  final store = await LocalStore.open(MemoryPersist());
  store.me = {'id': LocalEngine.newId(), 'name': 'Sam', 'email': '', 'units': 'metric'};
  return (store, LocalApi(store));
}

void main() {
  test('a server backup comes back on a phone without a server', () async {
    // What the backup leaves in Drive for one family: the CSV export, the JSON beside it and a
    // photo for a milestone that was itself imported (so the CSV knows it by its source id).
    final drive = MemoryFiles();
    const csv =
        '"Type","Profile Name","Start Date/time (Epoch)","Note","Time Zone","[Diaper] Type","[Milestone] Milestone","[Profile] Birth Date","[Profile] Sex","_profileKey","_activityKey"\n'
        '"Diaper","Mia","1791414000000",,"America/Toronto","Wet",,,,"c-old","e-1"\n'
        '"Milestone","Mia","1791500400000",,"America/Toronto",,"First smile",,,"c-old","t-smile"\n'
        '"Profile","Mia",,,,,,"2026-05-30","FEMALE","c-old",\n';
    await drive.put('server-F.csv', utf8.encode(csv), null);
    await drive.put('server-F-photo-e-2-7', jpeg(1), null);
    await drive.put('server-F-print-e-2-7', jpeg(9), null);
    await drive.put('server-F-child-c-old-3', jpeg(2), null);
    await drive.put(
      'server-F.json',
      utf8.encode(
        jsonEncode({
          'v': 1,
          'saved_at': 1791500000000,
          'family': {'id': 'F', 'name': 'Home', 'timezone': 'America/Toronto', 'day_start': '07:00', 'day_end': '19:00'},
          'children': [
            {
              'id': 'c-old',
              'name': 'Mia',
              'birth_date': '2026-05-30',
              'sex': 'female',
              'medicines': [
                {'name': 'Acetaminophen', 'every_hours': 4},
              ],
              'reminders': [],
              'book': {},
              'photo': 'server-F-child-c-old-3',
            },
          ],
          'photos': {'t-smile': 'server-F-photo-e-2-7'},
          'prints': {'t-smile': 'server-F-print-e-2-7'},
        }),
      ),
      null,
    );

    final (store, api) = await serverlessPhone();
    final backup = ServerBackup(store, null, files: drive);
    final copies = await backup.copies();
    expect(copies.map((c) => c.name), ['Home']);

    final res = await backup.restore(api, copies.single);
    expect((res.entries, res.photos), (2, 2));
    final family = await api.get('/families/${res.familyId}');
    expect((family['name'], family['timezone'], family['day_start']), ('Home', 'America/Toronto', '07:00'));
    final kids = (await api.get('/families/${res.familyId}/children'))['children'] as List;
    expect(kids.single['name'], 'Mia');
    expect(kids.single['medicines'].single['name'], 'Acetaminophen');
    expect(await api.getBytes('/children/${kids.single['id']}/photo'), jpeg(2));
    final events = (await api.get('/children/${kids.single['id']}/events'))['events'] as List;
    final smile = events.singleWhere((e) => e['type'] == 'milestone');
    expect(await api.getBytes('/events/${smile['id']}/photo'), jpeg(1));
    // The print copy stays on the phone.
    expect(await api.getBytes('/events/${smile['id']}/photo/print'), jpeg(9));

    // Again, into the same family: updated, not doubled.
    final again = await backup.restore(api, copies.single, familyId: res.familyId);
    expect(again.entries, 2);
    expect(((await api.get('/families/${res.familyId}/children'))['children'] as List).length, 1);
    expect(((await api.get('/children/${kids.single['id']}/events'))['events'] as List).length, 2);
  });

  // Against a real server: `NESTLING_TEST_SERVER=http://127.0.0.1:8080 flutter test test/server_backup_test.dart`
  // (a fresh server: the test registers its own accounts there).
  final url = Platform.environment['NESTLING_TEST_SERVER'];
  test('back up a server and restore it onto another server and a phone', () async {
    Future<Api> account(String email) async {
      final a = Api(url!);
      final res = await a.post('/auth/register', {'email': email, 'password': 'password123', 'name': 'Sam'});
      return a..token = res['token'];
    }

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final old = await account('old$stamp@example.com');
    final fam = await old.post('/families', {'name': 'Home', 'timezone': 'America/Toronto'});
    await old.patch('/families/${fam['id']}', {'day_start': '07:00', 'day_end': '19:00'});
    final mia = await old.post('/families/${fam['id']}/children', {'name': 'Mia', 'birth_date': '2026-05-30'});
    await old.patch('/children/${mia['id']}', {
      'medicines': [
        {'name': 'Acetaminophen', 'every_hours': 4},
      ],
    });
    await old.putBytes('/children/${mia['id']}/photo', jpeg(2), contentType: 'image/jpeg');
    await old.post('/children/${mia['id']}/events', {'type': 'diaper', 'wet': true, 'start': '2026-10-01T08:00'});
    final smile = await old.post('/children/${mia['id']}/events', {'type': 'milestone', 'name': 'First smile', 'start': '2026-10-02T09:00'});
    await old.putBytes('/events/${smile['id']}/photo', jpeg(1), contentType: 'image/jpeg');
    await old.putBytes('/events/${smile['id']}/photo/print', jpeg(9), contentType: 'image/jpeg');
    final version = (await old.get('/events/${smile['id']}'))['photo_version'];

    final drive = MemoryFiles();
    final (oldPhone, _) = await serverlessPhone();
    await ServerBackup(oldPhone, () => Api(url!, old.token), files: drive).backUp();
    expect(drive.names, [
      'server-${fam['id']}-child-${mia['id']}-${(await old.get('/children/${mia['id']}'))['photo_version']}',
      'server-${fam['id']}-photo-${smile['id']}-$version',
      'server-${fam['id']}-print-${smile['id']}-$version',
      'server-${fam['id']}.csv',
      'server-${fam['id']}.json',
    ]);

    // A new server (here: another account on the same one) after the old one was lost.
    final fresh = await account('new$stamp@example.com');
    final backup = ServerBackup(oldPhone, null, files: drive);
    final res = await backup.restore(fresh, (await backup.copies()).single);
    expect((res.entries, res.photos), (2, 2));
    final kids = (await fresh.get('/families/${res.familyId}/children'))['children'] as List;
    expect((kids.single['name'], kids.single['birth_date']), ('Mia', '2026-05-30'));
    expect(kids.single['medicines'].single['name'], 'Acetaminophen');
    expect(await fresh.getBytes('/children/${kids.single['id']}/photo'), jpeg(2));
    final family = await fresh.get('/families/${res.familyId}');
    expect((family['timezone'], family['day_start']), ('America/Toronto', '07:00'));
    final events = (await fresh.get('/children/${kids.single['id']}/events'))['events'] as List;
    expect(events.map((e) => e['type']).toSet(), {'diaper', 'milestone'});
    final restored = events.singleWhere((e) => e['type'] == 'milestone');
    expect(await fresh.getBytes('/events/${restored['id']}/photo'), jpeg(1));
    expect(await fresh.getBytes('/events/${restored['id']}/photo/print'), jpeg(9));

    // Restored into the family it came from (the old server still running): nothing doubles.
    final same = await backup.restore(old, (await backup.copies()).single, familyId: fam['id']);
    expect(same.entries, 2);
    expect(((await old.get('/children/${mia['id']}/events'))['events'] as List).length, 2);
    expect(((await old.get('/families/${fam['id']}/children'))['children'] as List).length, 1);

    // Backing up the new server and restoring again: the photo still finds its entry.
    final drive2 = MemoryFiles();
    await ServerBackup(oldPhone, () => Api(url!, fresh.token), files: drive2).backUp();
    final (phone, local) = await serverlessPhone();
    final onPhone = await ServerBackup(phone, null, files: drive2).restore(local, (await ServerBackup(phone, null, files: drive2).copies()).single);
    expect((onPhone.entries, onPhone.photos), (2, 2));
    final onPhoneSmile = phone.events.values.singleWhere((e) => e['type'] == 'milestone');
    expect(await local.getBytes('/events/${onPhoneSmile['id']}/photo/print'), jpeg(9));
  }, skip: url == null ? 'set NESTLING_TEST_SERVER to run against a server' : false);
}
