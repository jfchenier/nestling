/// Medicine schedules and reminders, kept on the child (`medicines` / `reminders` lists).
/// Port of src/schedule.rs: keep both in step.
library;

import 'dart:math' as math;

import 'domain.dart' show badRequest;

const reminderTypes = ['feed', 'sleep', 'diaper', 'pump'];
const _maxItems = 20;
const dayMs = 24 * 3600 * 1000;
const _maxTimes = 12;
const _earlyMs = 2 * 3600 * 1000;

/// The name doses are matched on.
String medicineKey(String name) => name.trim().split(RegExp(r'\s+')).join(' ').toLowerCase();

/// Checks and cleans a medicines list, as the server does (throws a 400).
List<Map<String, dynamic>> checkMedicines(Object? raw) {
  if (raw is! List) throw badRequest('medicines must be a list');
  if (raw.length > _maxItems) throw badRequest('at most $_maxItems medicines');
  final seen = <String>{};
  return [
    for (final m in raw)
      () {
        if (m is! Map) throw badRequest('a medicine must be an object');
        final name = (m['name'] is String ? m['name'] as String : '').trim().split(RegExp(r'\s+')).join(' ');
        if (name.isEmpty || name.runes.length > 80) throw badRequest('a medicine needs a name (up to 80 characters)');
        if (!seen.add(medicineKey(name))) throw badRequest('$name is listed twice');
        final every = m['every_hours'];
        if (every is! num || !every.isFinite || every < 0.5 || every > 168) throw badRequest('every_hours must be between 0.5 and 168');
        final max = m['max_per_day'];
        if (max != null && (max is! int || max < 1 || max > 24)) throw badRequest('max_per_day must be between 1 and 24');
        final dose = m['dose'];
        if (dose != null && (dose is! num || !dose.isFinite || dose < 0 || dose > 10000)) throw badRequest('dose must be a positive number');
        final unit = (m['dose_unit'] is String ? m['dose_unit'] as String : '').trim();
        final rawTimes = m['times'] ?? const [];
        if (rawTimes is! List) throw badRequest('times must be a list');
        if (rawTimes.length > _maxTimes) throw badRequest('at most $_maxTimes times a day');
        final times = <String>{
          for (final t in rawTimes)
            switch (t is String ? RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(t.trim()) : null) {
              final mt? when int.parse(mt[1]!) < 24 && int.parse(mt[2]!) < 60 => '${mt[1]!.padLeft(2, '0')}:${mt[2]}',
              _ => throw badRequest('times must be like "08:00"'),
            },
        }.toList()..sort();
        return <String, dynamic>{
          'name': name,
          'every_hours': every,
          'max_per_day': ?max,
          'dose': ?dose,
          if (unit.isNotEmpty) 'dose_unit': unit,
          'remind': m['remind'] == true,
          if (times.isNotEmpty) 'times': times,
        };
      }(),
  ];
}

List<Map<String, dynamic>> checkReminders(Object? raw) {
  if (raw is! List) throw badRequest('reminders must be a list');
  final out = <Map<String, dynamic>>[];
  for (final r in raw) {
    if (r is! Map || !reminderTypes.contains(r['type'])) throw badRequest("a reminder's type must be feed, sleep, diaper or pump");
    if (out.any((o) => o['type'] == r['type'])) throw badRequest('there is already a ${r['type']} reminder');
    final after = r['after_minutes'];
    if (after is! int || after < 15 || after > 24 * 60) throw badRequest('after_minutes must be between 15 and 1440');
    out.add({'type': r['type'], 'after_minutes': after});
  }
  return out;
}

/// Minutes after midnight of "HH:MM" times, sorted.
List<int> _minutes(List times) => {
  for (final t in times)
    if ('$t'.split(':') case [final h, final m] when int.tryParse(h) != null && int.tryParse(m) != null) int.parse(h) * 60 + int.parse(m),
}.toList()..sort();

/// How early a dose counts for a set time: 2 h, or half the shortest gap between the times.
int earlyMs(List<int> mins) {
  var early = _earlyMs;
  for (var i = 0; i < mins.length; i++) {
    final gap = i == 0 ? mins.first + 1440 - mins.last : mins[i] - mins[i - 1];
    early = math.min(early, gap * 30000);
  }
  return early;
}

/// Status of a medicine given at set times (device time zone): the current time is the last one
/// whose early window has opened; its dose is given if one was logged since then.
({int? lastAt, int? nextAt, int doses24h, bool limited, bool due}) _fixedStatus(List<int> mins, List<int> doses, int now) {
  final early = earlyMs(mins);
  final today = DateTime.fromMillisecondsSinceEpoch(now);
  final slots = [
    for (var d = -2; d <= 2; d++)
      for (final m in mins) DateTime(today.year, today.month, today.day + d, m ~/ 60, m % 60).millisecondsSinceEpoch,
  ]..sort();
  final recent = doses.where((t) => t > now - dayMs && t <= now).length;
  final lastAt = doses.firstOrNull;
  final i = slots.lastIndexWhere((s) => s - early <= now);
  if (i < 0) return (lastAt: lastAt, nextAt: slots.first, doses24h: recent, limited: false, due: false);
  final current = slots[i];
  if (doses.any((t) => t >= current - early && t <= now)) {
    return (lastAt: lastAt, nextAt: i + 1 < slots.length ? slots[i + 1] : null, doses24h: recent, limited: false, due: false);
  }
  return (lastAt: lastAt, nextAt: current, doses24h: recent, limited: false, due: true);
}

/// Where a medicine stands; [doses] are its dose times (ms), newest first.
({int? lastAt, int? nextAt, int doses24h, bool limited, bool due}) medicineStatus(Map<String, dynamic> m, List<int> doses, int now) {
  if (m['times'] case final List times when times.isNotEmpty) return _fixedStatus(_minutes(times), doses, now);
  if (doses.isEmpty) return (lastAt: null, nextAt: null, doses24h: 0, limited: false, due: true);
  final last = doses.first;
  final recent = [
    for (final t in doses)
      if (t > now - dayMs && t <= now) t,
  ];
  var next = last + ((m['every_hours'] as num) * 3600000).round();
  var limited = false;
  if (m['max_per_day'] case final int max when recent.length >= max) {
    final oldest = recent[max - 1];
    if (oldest + dayMs > next) {
      next = oldest + dayMs;
      limited = true;
    }
  }
  return (lastAt: last, nextAt: next, doses24h: recent.length, limited: limited, due: next <= now);
}

/// A medicine with its status, as the summary shows it.
Map<String, dynamic> medicineJson(Map<String, dynamic> m, List<int> doses, int now, String Function(int) fmt) {
  final st = medicineStatus(m, doses, now);
  return {
    ...m,
    'last_at': st.lastAt == null ? null : fmt(st.lastAt!),
    'next_at': st.nextAt == null ? null : fmt(st.nextAt!),
    'due': st.due,
    'doses_24h': st.doses24h,
    'limited': st.limited,
  };
}
