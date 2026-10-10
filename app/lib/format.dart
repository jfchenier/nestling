import 'package:intl/intl.dart';

import 'models.dart';

/// Display helpers. The API is metric-only; [Units] converts for imperial users.
class Units {
  const Units(this.imperial);
  final bool imperial;

  static const _mlPerOz = 29.5735;
  static const _gPerLb = 453.592;
  static const _cmPerIn = 2.54;

  String get volumeUnit => imperial ? 'oz' : 'mL';
  String get lengthUnit => imperial ? 'in' : 'cm';
  String get tempUnit => imperial ? '°F' : '°C';
  String get weightUnit => imperial ? 'lb' : 'kg';

  // Display value from metric (for form fields).
  double volumeIn(double ml) => imperial ? ml / _mlPerOz : ml;
  double lengthIn(double cm) => imperial ? cm / _cmPerIn : cm;
  double tempIn(double c) => imperial ? c * 9 / 5 + 32 : c;
  double weightIn(double g) => imperial ? g / _gPerLb : g / 1000;

  // Back to metric (for the API).
  double volumeOut(double v) => imperial ? v * _mlPerOz : v;
  double lengthOut(double v) => imperial ? v * _cmPerIn : v;
  double tempOut(double v) => imperial ? (v - 32) * 5 / 9 : v;
  double weightOut(double v) => imperial ? v * _gPerLb : v * 1000;

  String volume(num? ml) => ml == null ? '' : '${_n(volumeIn(ml.toDouble()), imperial ? 1 : 0)} $volumeUnit';
  String length(num? cm) => cm == null ? '' : '${_n(lengthIn(cm.toDouble()), 1)} $lengthUnit';
  String temp(num? c) => c == null ? '' : '${_n(tempIn(c.toDouble()), 1)} $tempUnit';
  String weight(num? g) {
    if (g == null) return '';
    if (!imperial) return '${_n(g / 1000, 2)} kg';
    final totalOz = g / (_gPerLb / 16);
    final lb = totalOz ~/ 16;
    final oz = totalOz - lb * 16;
    return '$lb lb ${_n(oz, 1)} oz';
  }

  static String _n(double v, int digits) {
    final s = v.toStringAsFixed(digits);
    return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
  }
}

/// "2d 5h", "1h 05m", "12m", "45s".
String duration(int? seconds, {bool showSeconds = false}) {
  if (seconds == null) return '';
  if (seconds >= 86400) return '${seconds ~/ 86400}d ${(seconds % 86400) ~/ 3600}h';
  final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60, s = seconds % 60;
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  if (m > 0) return showSeconds ? '${m}m ${s.toString().padLeft(2, '0')}s' : '${m}m';
  return showSeconds ? '${s}s' : (seconds > 0 ? '<1m' : '0m');
}

/// Stopwatch style: "1:05:09" or "05:09".
String clock(int seconds) {
  final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60, s = seconds % 60;
  final mm = m.toString().padLeft(2, '0'), ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// "2h 15m ago", "just now".
String ago(int? seconds) {
  if (seconds == null) return '—';
  if (seconds < 60) return 'just now';
  if (seconds >= 86400 * 2) return '${seconds ~/ 86400} days ago';
  if (seconds >= 86400) return 'Yesterday';
  return '${duration(seconds)} ago';
}

/// 24-hour clock: "07:05", "23:40".
String timeOfDay(DateTime t) => DateFormat.Hm().format(t);

String dayLabel(DateTime t) {
  final now = DateTime.now();
  final d = DateTime(t.year, t.month, t.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7 && diff > 0) return DateFormat.EEEE().format(t);
  return DateFormat.yMMMEd().format(t);
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
String cap(String? s) => s == null ? '' : _cap(s);

/// "Potty" / "Accident" / "Sat but dry" for a potty entry, null for a diaper.
String? pottyLabel(dynamic potty) => switch (potty) {
  'sat_dry' => 'Sat but dry',
  'success' => 'Potty',
  'accident' => 'Accident',
  _ => null,
};

/// "Wet", "Dirty" or "Wet + dirty" (as for diapers).
String wetDirty(Event e) => [if (e['wet'] == true) 'Wet', if (e['dirty'] == true) (e['wet'] == true ? 'dirty' : 'Dirty')].join(' + ');

/// Title and one-line detail for an event, e.g. ("Bottle", "120 mL formula").
(String, String) describe(Event e, Units u) {
  String sides() {
    final l = toInt(e['left_seconds']) ?? 0, r = toInt(e['right_seconds']) ?? 0;
    return [if (l > 0) 'L ${duration(l)}', if (r > 0) 'R ${duration(r)}'].join(' · ');
  }

  switch (e.type) {
    case 'feed':
      final method = e['method'] as String?;
      final amount = toDouble(e['amount_ml']);
      final milk = e['milk'] == 'breast_milk' ? 'breast milk' : e['milk'] as String?;
      switch (method) {
        case 'bottle':
          return ('Bottle', [u.volume(amount), ?milk].where((s) => s.isNotEmpty).join(' '));
        case 'solids':
          return ('Solids', (e['foods'] as String?) ?? '');
        case 'combo':
          return ('Breastfeed + bottle', [sides(), if (amount != null) u.volume(amount)].where((s) => s.isNotEmpty).join(' · '));
        default:
          final end = e.endSide;
          return ('Breastfeed', [sides(), if (end != null) 'ended ${end == 'left' ? 'L' : 'R'}'].where((s) => s.isNotEmpty).join(' · '));
      }
    case 'sleep':
      return ('Sleep', [duration(e.durationSeconds), if (e['location'] != null) cap(e['location'])].where((s) => s.isNotEmpty).join(' · '));
    case 'diaper' when e['potty'] != null:
      final parts = <String>[
        e['potty'] == 'success' ? 'In the potty' : pottyLabel(e['potty'])!,
        if (e['potty'] != 'sat_dry') wetDirty(e),
        if (e['color'] != null) cap(e['color']),
        if (e['consistency'] != null) cap(e['consistency']),
        if (e['rash'] == true) 'rash',
        if (e['blowout'] == true) 'blowout',
      ];
      return ('Potty', parts.where((s) => s.isNotEmpty).join(' · '));
    case 'diaper':
      final parts = <String>[
        if (e['wet'] == true && e['dirty'] == true)
          'Wet + dirty'
        else if (e['wet'] == true)
          'Wet'
        else if (e['dirty'] == true)
          'Dirty'
        else
          'Dry',
        if (e['color'] != null) cap(e['color']),
        if (e['consistency'] != null) cap(e['consistency']),
        if (e['rash'] == true) 'rash',
        if (e['blowout'] == true) 'blowout',
      ];
      return ('Diaper', parts.join(' · '));
    case 'pump':
      final total = (toDouble(e['left_ml']) ?? 0) + (toDouble(e['right_ml']) ?? 0);
      return ('Pump', [if (total > 0) u.volume(total), if (e.durationSeconds != null) duration(e.durationSeconds)].join(' · '));
    case 'growth':
      return (
        'Growth',
        [
          u.weight(toDouble(e['weight_g'])),
          if (e['length_cm'] != null) 'L ${u.length(toDouble(e['length_cm']))}',
          if (e['head_cm'] != null) 'Head ${u.length(toDouble(e['head_cm']))}',
        ].where((s) => s.isNotEmpty).join(' · '),
      );
    case 'health':
      final kind = e['kind'] as String?;
      if (kind == 'temperature') return ('Temperature', u.temp(toDouble(e['temperature_c'])));
      final dose = [if (e['dose'] != null) Units._n(toDouble(e['dose']) ?? 0, 2), if (e['dose_unit'] != null) e['dose_unit']].join(' ');
      return (cap(kind ?? 'Health'), [if (e['name'] != null) e['name'] as String, if (dose.isNotEmpty) dose].join(' · '));
    case 'activity':
      return (cap(e['kind'] as String? ?? 'Activity'), duration(e.durationSeconds));
    case 'milestone':
      return ('Milestone', (e['name'] as String?) ?? '');
    default:
      return ('Note', '');
  }
}
