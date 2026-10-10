/// Nara Baby's CSV export read on the phone (serverless mode), with the same rules as the
/// server's `src/nara_csv.rs`; keep the two in step.
///
/// One row per record. Common columns: `Type`, `Profile Name`, `Start Date/time (Epoch)` (ms),
/// `Note`, `Time Zone`, `_profileKey`, `_activityKey`. Type-specific columns are prefixed with
/// `[<Type>] `. A `Profile` row carries the child's birth date and sex.
library;

import 'dart:math' as math;

import '../api/api.dart';
import 'domain.dart';

/// A Nara record converted to an event (details as the API writes them).
class NaraRecord {
  NaraRecord(this.sourceId, this.childKey, this.start, this.end, this.note, this.details);
  final String sourceId;
  String? childKey;
  final int start;
  int? end;
  final String? note;
  final Map<String, dynamic> details;
}

/// A Nara child profile found in the export.
class NaraProfile {
  String? name, birthDate, sex;
}

class NaraCsv {
  final records = <NaraRecord>[];

  /// Reason → count.
  final skipped = <String, int>{};

  /// Nara profile key → profile.
  final profiles = <String, NaraProfile>{};
  int rows = 0;
}

/// RFC 4180 CSV: quoted cells may hold commas, quotes (`""`) and line breaks.
List<List<String>> parseCsvRows(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      row.add(cell.toString());
      cell.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      if (row.length > 1 || row.first.isNotEmpty) rows.add(row);
      row = <String>[];
    } else {
      cell.write(c);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    if (row.length > 1 || row.first.isNotEmpty) rows.add(row);
  }
  return rows;
}

class _Row {
  _Row(this.cols, this.cells);
  final Map<String, int> cols;
  final List<String> cells;

  String? get(String col) {
    final i = cols[col];
    if (i == null || i >= cells.length) return null;
    final v = cells[i].trim();
    return v.isEmpty ? null : v;
  }

  double? num(String col) {
    final v = double.tryParse(get(col)?.replaceAll(',', '.') ?? '');
    return v != null && v.isFinite ? v : null;
  }

  int? secs(String col) {
    final v = num(col);
    return v != null && v > 0 ? v.round() : null;
  }

  /// `<col>` with its `<col> Unit` sibling.
  (double, String)? qty(String col) {
    final v = num(col);
    if (v == null || v <= 0) return null;
    return (v, (get('$col Unit') ?? '').toUpperCase());
  }

  bool has(String col) => cols.containsKey(col);
}

double _round(double x, int places) {
  final f = math.pow(10, places);
  return (x * f).round() / f;
}

double _ml((double, String) q) => switch (q.$2) {
  'OZ' || 'FLOZ' || 'FL OZ' || 'FL. OZ' => _round(q.$1 * 29.5735, 1),
  'L' => _round(q.$1 * 1000, 1),
  _ => _round(q.$1, 1),
};

double _g((double, String) q) => switch (q.$2) {
  'KG' => _round(q.$1 * 1000, 1),
  'LB' || 'LBS' => _round(q.$1 * 453.592, 1),
  'OZ' => _round(q.$1 * 28.3495, 1),
  _ => _round(q.$1, 1),
};

double _cm((double, String) q) => switch (q.$2) {
  'IN' || 'INCH' || 'INCHES' => _round(q.$1 * 2.54, 2),
  'MM' => _round(q.$1 / 10, 2),
  _ => _round(q.$1, 2),
};

double _c((double, String) q) => q.$2.startsWith('F') ? _round((q.$1 - 32) * 5 / 9, 2) : _round(q.$1, 2);

String? _side(String? v) => switch (v?.split('.').first.toUpperCase()) {
  'LEFT' || 'L' => 'left',
  'RIGHT' || 'R' => 'right',
  _ => null,
};

String? _color(String? v) => switch (v?.toUpperCase()) {
  'YELLOW' || 'MUSTARD' => 'yellow',
  'GREEN' => 'green',
  'BROWN' || 'TAN' => 'brown',
  'BLACK' => 'black',
  'RED' => 'red',
  'GRAY' || 'GREY' || 'WHITE' => 'gray',
  _ => null,
};

String? _consistency(String? v) {
  final s = v?.toUpperCase() ?? '';
  if (s.startsWith('RUN') || s.startsWith('WATER')) return 'runny';
  if (s.startsWith('MUSH') || s.startsWith('SOFT')) return 'mushy';
  if (s.startsWith('MUC')) return 'mucousy';
  if (s.startsWith('PEBBLE') || s.startsWith('HARD')) return 'pebbles';
  if (s.startsWith('SOLID') || s.startsWith('FIRM')) return 'solid';
  return null;
}

/// Nestling's own `[Diaper] Potty` column (`src/nara_csv.rs` `potty`).
String? _potty(String? v) {
  final s = v?.toLowerCase() ?? '';
  if (s.contains('accident')) return 'accident';
  if (s.contains('dry')) return 'sat_dry';
  if (s.contains('potty') || s.contains('success')) return 'success';
  return null;
}

/// `Tummy time` → `tummy_time`.
String _activityKind(String v) {
  final s = v.trim().toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '_').split('_').where((p) => p.isNotEmpty).join('_');
  return s.isEmpty ? 'activity' : s;
}

/// The epoch ms column, or the local date/time column. Without a timezone database on the
/// phone, the local column is read in the phone's timezone (Nara's exports have both).
int? _time(_Row row, String epochCol, String localCol) {
  final ms = row.num(epochCol);
  if (ms != null) return ms.toInt();
  final local = row.get(localCol);
  if (local == null || !RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$').hasMatch(local)) return null;
  return DateTime.tryParse(local.replaceFirst(' ', 'T'))?.millisecondsSinceEpoch;
}

(double?, String?) _bottle(_Row row) {
  final breast = row.qty('[Bottle Feed] Breast Milk Volume');
  final formula = row.qty('[Bottle Feed] Formula Volume');
  final total = row.qty('[Bottle Feed] Volume');
  final kind = (row.get('[Bottle Feed] Type') ?? '').toLowerCase();
  final milk = switch ((breast != null, formula != null)) {
    (true, true) => 'mixed',
    (true, false) => 'breast_milk',
    (false, true) => 'formula',
    _ when kind.contains('breast') && kind.contains('formula') => 'mixed',
    _ when kind.contains('breast') => 'breast_milk',
    _ when kind.contains('formula') => 'formula',
    _ => null,
  };
  final amount = breast == null && formula == null
      ? (total == null ? null : _ml(total))
      : _round((breast == null ? 0 : _ml(breast)) + (formula == null ? 0 : _ml(formula)), 1);
  return (amount, milk);
}

class _Skip implements Exception {
  _Skip(this.reason);
  final String reason;
}

Map<String, dynamic> _feed(String method, {int? left, int? right, String? side, double? amount, String? milk, String? formula, String? foods}) => {
  'type': 'feed',
  'method': method,
  'left_seconds': ?left,
  'right_seconds': ?right,
  'start_side': ?side,
  'amount_ml': ?amount,
  'milk': ?milk,
  'formula_name': ?formula,
  'foods': ?foods,
};

/// One row → one or more records (a medical row with a medicine and a temperature gives two).
List<(String, Map<String, dynamic>, int, int?)> _convert(_Row row) {
  final type = row.get('Type') ?? (throw _Skip('missing Type'));
  final start = _time(row, 'Start Date/time (Epoch)', 'Start Date/time') ?? (throw _Skip('missing start time'));
  final id = row.get('_activityKey') ?? (throw _Skip('missing _activityKey'));
  List<(String, Map<String, dynamic>, int, int?)> one(Map<String, dynamic> d, [int? end]) => [(id, d, start, end)];
  int? endAfter(int? secs) => secs != null && secs > 0 ? start + secs * 1000 : null;

  switch (type.toLowerCase()) {
    case 'breastfeed' || 'combo feed':
      final left = row.secs('[Breastfeed] Left Duration (Seconds)');
      final right = row.secs('[Breastfeed] Right Duration (Seconds)');
      final side = _side(row.get('[Breastfeed] Begin Side'));
      final end = endAfter((left ?? 0) + (right ?? 0));
      if (type.toLowerCase() == 'breastfeed') return one(_feed('breast', left: left, right: right, side: side), end);
      final (amount, milk) = _bottle(row);
      return one(_feed('combo', left: left, right: right, side: side, amount: amount, milk: milk, formula: row.get('[Bottle Feed] Formula Name')), end);
    case 'bottle feed':
      final (amount, milk) = _bottle(row);
      return one(_feed('bottle', amount: amount, milk: milk, formula: row.get('[Bottle Feed] Formula Name')));
    case 'solids' || 'solid' || 'solid food':
      return one(_feed('solids', foods: row.get('[Solids] Food') ?? row.get('[Solids] Foods')));
    case 'diaper':
      final kind = (row.get('[Diaper] Type') ?? '').toLowerCase();
      final detail = (row.get('[Diaper] Detail') ?? '').toLowerCase();
      final dirty = kind.contains('dirty') || kind.contains('poo');
      final potty = _potty(row.get('[Diaper] Potty'));
      final d = <String, dynamic>{
        'type': 'diaper',
        'wet': kind.contains('wet') || kind.contains('pee'),
        'dirty': dirty,
        'dry': kind.contains('dry'),
        'rash': detail.contains('rash'),
        'blowout': dirty && detail.contains('blowout'),
        if (dirty) 'color': ?_color(row.get('[Diaper] Dirty Color')),
        if (dirty) 'consistency': ?_consistency(row.get('[Diaper] Dirty Texture')),
        'potty': ?potty,
      };
      if (d['wet'] != true && !dirty && d['dry'] != true) throw _Skip('empty diaper');
      return one(d);
    case 'sleep':
      final end = _time(row, '[Sleep] End Date/time (Epoch)', '[Sleep] End Date/time') ?? endAfter(row.secs('[Sleep] Duration (Seconds)'));
      if (end == null || end < start) throw _Skip('sleep without an end');
      return one({'type': 'sleep', 'location': ?row.get('[Sleep] Location')}, end);
    case 'growth':
      final w = row.qty('[Growth] Weight'), h = row.qty('[Growth] Height'), head = row.qty('[Growth] Head Size');
      if (w == null && h == null && head == null) throw _Skip('empty growth');
      return one({
        'type': 'growth',
        if (w != null) 'weight_g': _g(w),
        if (h != null) 'length_cm': _cm(h),
        if (head != null) 'head_cm': _cm(head),
      });
    case 'medical':
      final out = <(String, Map<String, dynamic>, int, int?)>[];
      // Keep the plain key for the first record so re-imports match.
      String key(String suffix) => out.isEmpty ? id : '$id#$suffix';
      if (row.get('[Medical] Medication') case final meds?) {
        final dose = row.num('[Medical] Dose');
        out.add((
          id,
          {
            'type': 'health',
            'kind': 'medicine',
            'name': meds.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).join(', '),
            if (dose != null && dose > 0) 'dose': dose,
            'dose_unit': ?row.get('[Medical] Dose Unit'),
          },
          start,
          null,
        ));
      }
      if (row.qty('[Medical] Temperature') case final t?) {
        out.add((key('temperature'), {'type': 'health', 'kind': 'temperature', 'temperature_c': _c(t)}, start, null));
      }
      for (final (col, kind) in const [('[Medical] Vaccine', 'vaccine'), ('[Medical] Symptom', 'symptom'), ('[Medical] Appointment', 'appointment')]) {
        if (row.get(col) case final name?) out.add((key(kind), {'type': 'health', 'kind': kind, 'name': name}, start, null));
      }
      if (out.isEmpty) throw _Skip('empty medical record');
      return out;
    case 'pump':
      final ls = row.secs('[Pump] Left Duration (Seconds)'), rs = row.secs('[Pump] Right Duration (Seconds)');
      final lv = row.qty('[Pump] Left Volume'), rv = row.qty('[Pump] Right Volume');
      return one({
        'type': 'pump',
        if (lv != null) 'left_ml': _ml(lv),
        if (rv != null) 'right_ml': _ml(rv),
        'left_seconds': ?ls,
        'right_seconds': ?rs,
      }, endAfter(math.max(ls ?? 0, rs ?? 0)));
    case 'note':
      if (row.get('Note') == null) throw _Skip('empty note');
      return one({'type': 'note'});
    case 'routine' || 'activity':
      return one({'type': 'activity', 'kind': _activityKind(row.get('[Routine] Routine') ?? '')});
    case 'milestone' || 'baby first' || 'baby firsts':
      final name = row.get('[Milestone] Milestone') ?? row.get('[Baby First] Name') ?? row.get('Note') ?? (throw _Skip('milestone without a name'));
      return one({'type': 'milestone', 'name': name});
    default:
      throw _Skip('unsupported type: ${type.toLowerCase()}');
  }
}

/// Parses a Nara CSV export. Throws [FormatException] for anything else.
NaraCsv parseNaraCsv(String text) {
  if (text.startsWith('﻿')) text = text.substring(1);
  final all = parseCsvRows(text);
  if (all.isEmpty) throw const FormatException('the file is empty');
  final cols = {for (final (i, h) in all.first.indexed) h.trim(): i};
  if (!cols.containsKey('Type') || !cols.containsKey('_activityKey')) {
    throw const FormatException('this doesn\'t look like a Nara export (expected "Type" and "_activityKey" columns)');
  }
  final out = NaraCsv();
  for (final cells in all.skip(1)) {
    out.rows++;
    final row = _Row(cols, cells);
    final profileKey = row.get('_profileKey');
    if (profileKey != null && row.get('Profile Name') != null) {
      out.profiles.putIfAbsent(profileKey, NaraProfile.new).name ??= row.get('Profile Name');
    }
    if (row.get('Type')?.toLowerCase() == 'profile') {
      if (profileKey != null) {
        final p = out.profiles.putIfAbsent(profileKey, NaraProfile.new);
        final birth = row.get('[Profile] Birth Date');
        p.birthDate = birth != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(birth) ? birth : null;
        p.sex = switch (row.get('[Profile] Sex')?.toUpperCase()) {
          null => null,
          'FEMALE' || 'F' || 'GIRL' => 'female',
          'MALE' || 'M' || 'BOY' => 'male',
          _ => 'other',
        };
      }
      continue;
    }
    try {
      final items = _convert(row);
      // Nestling's own export states every end exactly; trust it over durations.
      final exactEnd = row.has('End Date/time (Epoch)');
      final end = exactEnd ? _time(row, 'End Date/time (Epoch)', 'End Date/time') : null;
      for (final (sourceId, details, start, itemEnd) in items) {
        final keepEnd = !exactEnd || (details['type'] == 'sleep' && end == null);
        out.records.add(NaraRecord(sourceId, profileKey, start, keepEnd ? itemEnd : end, row.get('Note'), details));
      }
    } on _Skip catch (s) {
      out.skipped[s.reason] = (out.skipped[s.reason] ?? 0) + 1;
    }
  }
  // A record without a profile key belongs to the only child when there is just one.
  if (out.profiles.length == 1) {
    final key = out.profiles.keys.first;
    for (final r in out.records) {
      r.childKey ??= key;
    }
  }
  return out;
}

/// Records our own validation accepts; the others are counted in [NaraCsv.skipped].
List<NaraRecord> validNaraRecords(NaraCsv csv) => [
  for (final r in csv.records)
    if (_valid(csv, r)) r,
];

bool _valid(NaraCsv csv, NaraRecord r) {
  try {
    validateEvent(normalizeDetails(r.details), r.start, r.end, r.note);
    return true;
  } on ApiException catch (e) {
    final reason = 'invalid: ${e.message}';
    csv.skipped[reason] = (csv.skipped[reason] ?? 0) + 1;
    return false;
  }
}
