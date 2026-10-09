import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nestling/api/api.dart';
import 'package:nestling/local/engine.dart';
import 'package:nestling/local/merge.dart';
import 'package:nestling/local/nara_csv.dart';
import 'package:nestling/local/persist.dart';
import 'package:nestling/local/store.dart';

// Same header as a real export (and as the server's test in src/nara_csv.rs); rows are made up.
const header =
    '"Type","Profile Name","Start Date/time","Start Date/time (Epoch)","Created By Caregiver","Last Updated By Caregiver","Note","Time Zone",'
    '"[Breastfeed] Begin Side","[Breastfeed] End Side","[Breastfeed] Left Duration (Seconds)","[Breastfeed] Right Duration (Seconds)",'
    '"[Bottle Feed] Type","[Bottle Feed] Breast Milk Volume","[Bottle Feed] Breast Milk Volume Unit","[Bottle Feed] Formula Name",'
    '"[Bottle Feed] Formula Volume","[Bottle Feed] Formula Volume Unit","[Bottle Feed] Volume","[Bottle Feed] Volume Unit",'
    '"[Diaper] Type","[Diaper] Detail","[Diaper] Dirty Color","[Diaper] Dirty Texture","[Medical] Medication","[Medical] Temperature",'
    '"[Medical] Temperature Unit","[Sleep] Duration (Seconds)","[Sleep] End Date/time","[Sleep] End Date/time (Epoch)","[Growth] Head Size",'
    '"[Growth] Head Size Unit","[Growth] Height","[Growth] Height Unit","[Growth] Weight","[Growth] Weight Unit","[Routine] Routine",'
    '"[Profile] Birth Date","[Profile] Birth Date (Adjusted)","[Profile] Sex","[Profile] Type","_familyKey","_profileKey","_activityKey"';

final columns = parseCsvRows(header).first;

/// A CSV line with the given columns set (quoted like Nara does), everything else empty.
String line(Map<String, String> cells) => [
  for (final h in columns) cells[h] == null ? '' : '"${cells[h]!.replaceAll('"', '""')}"',
].join(',');

String row(String type, String epoch, String key, [Map<String, String> extra = const {}]) => line({
  'Type': type,
  'Profile Name': 'Mia',
  'Start Date/time (Epoch)': epoch,
  'Time Zone': 'America/Toronto',
  '_familyKey': 'f-1',
  '_profileKey': 'c-1',
  '_activityKey': key,
  ...extra,
});

String sample() => '﻿$header\n${[
  row('Breastfeed', '1791412200000', 't-bf', {
    '[Breastfeed] Begin Side': 'LEFT',
    '[Breastfeed] End Side': 'RIGHT.nonTimer',
    '[Breastfeed] Left Duration (Seconds)': '600',
    '[Breastfeed] Right Duration (Seconds)': '300',
  }),
  row('Bottle Feed', '1791388800000', 't-bottle', {
    '[Bottle Feed] Type': 'Breast Milk',
    '[Bottle Feed] Breast Milk Volume': '60',
    '[Bottle Feed] Breast Milk Volume Unit': 'ML',
  }),
  row('Bottle Feed', '1787881500000', 't-bottle2', {'[Bottle Feed] Volume': '2', '[Bottle Feed] Volume Unit': 'OZ'}),
  row('Diaper', '1782994839301', 't-diaper', {
    'Note': 'Big one',
    '[Diaper] Type': 'Dirty Wet',
    '[Diaper] Detail': 'Blowout',
    '[Diaper] Dirty Color': 'YELLOW',
    '[Diaper] Dirty Texture': 'RUN',
  }),
  row('Medical', '1788717700000', 't-med', {
    '[Medical] Medication': 'Drops A\nDrops B',
    '[Medical] Temperature': '101.3',
    '[Medical] Temperature Unit': 'F',
  }),
  row('Medical', '1785868380000', 't-empty'),
  row('Sleep', '1783353600000', 't-sleep', {
    'Time Zone': 'US/Eastern',
    '[Sleep] Duration (Seconds)': '3000',
    '[Sleep] End Date/time (Epoch)': '1783356600000',
  }),
  row('Growth', '1785816000000', 't-growth', {
    '[Growth] Head Size': '38',
    '[Growth] Head Size Unit': 'CM',
    '[Growth] Height': '56',
    '[Growth] Height Unit': 'CM',
    '[Growth] Weight': '4.55',
    '[Growth] Weight Unit': 'KG',
  }),
  row('Routine', '1783606440000', 't-routine', {'[Routine] Routine': 'Tummy time'}),
  line({
    'Type': 'Breastfeed',
    'Profile Name': 'Mia',
    'Start Date/time (Epoch)': '1782428432492',
    '[Breastfeed] Begin Side': 'LEFT',
    '[Breastfeed] Left Duration (Seconds)': '1581',
    '[Breastfeed] Right Duration (Seconds)': '0',
    '_activityKey': 't-noprofile',
  }),
  line({
    'Type': 'Profile',
    'Profile Name': 'Mia',
    '[Profile] Birth Date': '2026-05-30',
    '[Profile] Sex': 'FEMALE',
    '[Profile] Type': 'CHILD',
    '_profileKey': 'c-1',
  }),
  row('Pump', '1783606440000', 't-pump'),
].join('\n')}\n';

void main() {
  NaraRecord find(NaraCsv r, String id) => r.records.firstWhere((x) => x.sourceId == id);

  test('reads every type like the server does', () {
    final r = parseNaraCsv(sample());
    expect(r.rows, 12);
    final p = r.profiles['c-1']!;
    expect([p.name, p.birthDate, p.sex], ['Mia', '2026-05-30', 'female']);

    final bf = find(r, 't-bf');
    expect(bf.details, {'type': 'feed', 'method': 'breast', 'left_seconds': 600, 'right_seconds': 300, 'start_side': 'left'});
    expect(bf.end, 1791412200000 + 900000);
    expect(find(r, 't-bottle').details, {'type': 'feed', 'method': 'bottle', 'amount_ml': 60.0, 'milk': 'breast_milk'});
    expect(find(r, 't-bottle2').details['amount_ml'], 59.1);

    final d = find(r, 't-diaper');
    expect(d.details, {
      'type': 'diaper',
      'wet': true,
      'dirty': true,
      'dry': false,
      'rash': false,
      'blowout': true,
      'color': 'yellow',
      'consistency': 'runny',
    });
    expect([d.note, d.start], ['Big one', 1782994839301]);

    expect(find(r, 't-med').details['name'], 'Drops A, Drops B');
    expect(find(r, 't-med#temperature').details['temperature_c'], 38.5);
    expect(find(r, 't-sleep').end, 1783356600000);
    expect(find(r, 't-growth').details, {'type': 'growth', 'weight_g': 4550.0, 'length_cm': 56.0, 'head_cm': 38.0});
    expect(find(r, 't-routine').details['kind'], 'tummy_time');
    expect(find(r, 't-noprofile').childKey, 'c-1');
    expect(r.skipped['empty medical record'], 1);
    expect(find(r, 't-pump').details['type'], 'pump');
    expect(r.records.length, 11);
  });

  test('rejects a CSV that is not a Nara export', () {
    expect(() => parseNaraCsv('a,b\n1,2\n'), throwsFormatException);
  });

  test('imports on the phone: preview, import, and importing again updates', () async {
    final store = await LocalStore.open(MemoryPersist());
    store.me = {'id': LocalEngine.newId(), 'name': 'Mom', 'email': '', 'units': 'metric'};
    final engine = LocalEngine(store)..serverless = true;
    final fam = engine.createFamily({'name': 'Home', 'timezone': 'UTC'});
    final path = '/families/${fam['id']}/import/nara-csv';
    expect(LocalEngine.handles('POST', path, serverless: true), isTrue);
    expect(LocalEngine.handles('POST', path), isFalse);
    final bytes = utf8.encode(sample());

    final preview = engine.handle('POST', path, query: {'dry_run': 'true'}, body: bytes);
    expect(preview['importable'], 11);
    expect(preview['children_to_create'], 1);
    expect(preview['by_type'], {'activity': 1, 'diaper': 1, 'feed': 4, 'growth': 1, 'health': 2, 'pump': 1, 'sleep': 1});
    expect(store.events, isEmpty);

    // The family has no baby yet: Mia is created from the export's profile.
    final done = engine.handle('POST', path, query: {'dry_run': 'false'}, body: bytes);
    expect([done['imported'], done['updated']], [11, 0]);
    final mia = (store.families.single['children'] as List).single;
    expect([mia['name'], mia['birth_date'], mia['sex']], ['Mia', '2026-05-30', 'female']);
    expect(store.eventsOf(mia['id']).length, 11);
    expect(store.eventsOf(mia['id']).every((e) => e['source'] == 'nara'), isTrue);

    // Again, into the same baby: nothing duplicated.
    final again = engine.handle('POST', path, query: {'child_id': mia['id']}, body: bytes);
    expect([again['imported'], again['updated']], [0, 11]);
    expect(store.eventsOf(mia['id']).length, 11);

    // The ids depend only on the family and Nara's id, so another phone importing the same
    // file into the same family writes the same records; and they travel to paired phones.
    final id = LocalEngine.naraEventId(fam['id'], 't-bf');
    expect(store.events[id]?['left_seconds'], 600);
    expect(exportFamily(store, fam['id'])['events'], hasLength(11));
  });

  test('a family with several babies needs to say where the records go', () async {
    final store = await LocalStore.open(MemoryPersist());
    store.me = {'id': LocalEngine.newId(), 'name': 'Mom', 'email': '', 'units': 'metric'};
    final engine = LocalEngine(store)..serverless = true;
    final fam = engine.createFamily({'name': 'Home', 'timezone': 'UTC'});
    engine.createChild(fam['id'], {'name': 'A'});
    final b = engine.createChild(fam['id'], {'name': 'B'});
    final path = '/families/${fam['id']}/import/nara-csv';
    expect(
      () => engine.handle('POST', path, body: utf8.encode(sample())),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('several children'))),
    );
    final done = engine.handle('POST', path, query: {'child_id': b['id']}, body: utf8.encode(sample()));
    expect(done['imported'], 11);
    expect(store.eventsOf(b['id']).length, 11);
    expect(store.child(b['id'])!['birth_date'], '2026-05-30');
  });
}
