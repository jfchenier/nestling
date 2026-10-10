/// Medicine schedules and reminders, kept on the child (`medicines` / `reminders` lists).
/// Port of src/schedule.rs: keep both in step.
library;

import 'domain.dart' show badRequest;

const reminderTypes = ['feed', 'sleep', 'diaper', 'pump'];
const _maxItems = 20;
const dayMs = 24 * 3600 * 1000;

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
        return <String, dynamic>{
          'name': name,
          'every_hours': every,
          'max_per_day': ?max,
          'dose': ?dose,
          if (unit.isNotEmpty) 'dose_unit': unit,
          'remind': m['remind'] == true,
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

/// Where a medicine stands; [doses] are its dose times (ms), newest first.
({int? lastAt, int? nextAt, int doses24h, bool limited}) medicineStatus(Map<String, dynamic> m, List<int> doses, int now) {
  if (doses.isEmpty) return (lastAt: null, nextAt: null, doses24h: 0, limited: false);
  final last = doses.first;
  final recent = [for (final t in doses) if (t > now - dayMs && t <= now) t];
  var next = last + ((m['every_hours'] as num) * 3600000).round();
  var limited = false;
  if (m['max_per_day'] case final int max when recent.length >= max) {
    final oldest = recent[max - 1];
    if (oldest + dayMs > next) {
      next = oldest + dayMs;
      limited = true;
    }
  }
  return (lastAt: last, nextAt: next, doses24h: recent.length, limited: limited);
}

/// A medicine with its status, as the summary shows it.
Map<String, dynamic> medicineJson(Map<String, dynamic> m, List<int> doses, int now, String Function(int) fmt) {
  final st = medicineStatus(m, doses, now);
  return {
    ...m,
    'last_at': st.lastAt == null ? null : fmt(st.lastAt!),
    'next_at': st.nextAt == null ? null : fmt(st.nextAt!),
    'due': st.nextAt == null || st.nextAt! <= now,
    'doses_24h': st.doses24h,
    'limited': st.limited,
  };
}
