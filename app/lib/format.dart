import 'package:intl/intl.dart';

import 'l10n/l10n.dart';
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
  if (seconds >= 86400) return l10n.durDaysHours(seconds ~/ 86400, (seconds % 86400) ~/ 3600);
  final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60, s = seconds % 60;
  if (h > 0) return l10n.durHoursMinutes(h, m.toString().padLeft(2, '0'));
  if (m > 0) return showSeconds ? l10n.durMinutesSeconds(m, s.toString().padLeft(2, '0')) : l10n.durMinutes(m);
  return showSeconds ? l10n.durSeconds(s) : (seconds > 0 ? l10n.durUnderMinute : l10n.durMinutes(0));
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
  if (seconds < 60) return l10n.justNow;
  if (seconds >= 86400 * 2) return l10n.daysAgo(seconds ~/ 86400);
  if (seconds >= 86400) return l10n.yesterday;
  return l10n.agoDuration(duration(seconds));
}

/// 24-hour clock: "07:05", "23:40".
String timeOfDay(DateTime t) => DateFormat.Hm().format(t);

String dayLabel(DateTime t) {
  final now = DateTime.now();
  final d = DateTime(t.year, t.month, t.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return l10n.today;
  if (diff == 1) return l10n.yesterday;
  if (diff < 7 && diff > 0) return capFirst(DateFormat.EEEE().format(t));
  return capFirst(DateFormat.yMMMEd().format(t));
}

/// "lundi" → "Lundi" (French and Spanish day and month names are lower case).
String capFirst(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');

/// Display name of a value saved as a key (sleep location, poop color, health kind, built-in
/// activity…) in the app's language; any other text is just capitalized ("tummy_time" → "Tummy time").
String cap(String? s) => s == null ? '' : (valueLabel(s) ?? _cap(s));

String? valueLabel(String key) {
  final t = l10n;
  return switch (key) {
    'crib' => t.locationCrib,
    'bassinet' => t.locationBassinet,
    'bed' => t.locationBed,
    'arms' => t.locationArms,
    'stroller' => t.locationStroller,
    'car' => t.locationCar,
    'yellow' => t.colorYellow,
    'green' => t.colorGreen,
    'brown' => t.colorBrown,
    'black' => t.colorBlack,
    'red' => t.colorRed,
    'gray' => t.colorGray,
    'runny' => t.consistencyRunny,
    'mushy' => t.consistencyMushy,
    'mucousy' => t.consistencyMucousy,
    'pebbles' => t.consistencyPebbles,
    'solid' => t.consistencySolid,
    'medicine' => t.healthMedicine,
    'temperature' => t.healthTemperature,
    'vaccine' => t.healthVaccine,
    'appointment' => t.healthAppointment,
    'symptom' => t.healthSymptom,
    'breast_milk' => t.milkBreastMilk,
    'formula' => t.milkFormula,
    'mixed' => t.milkMixed,
    'tummy_time' => t.activityTummyTime,
    'bath' => t.activityBath,
    'outdoor' => t.activityOutdoor,
    'play' => t.activityPlay,
    'read' => t.activityRead,
    'nail_trim' => t.activityNailTrim,
    'vitamin' => t.activityVitamin,
    'massage' => t.activityMassage,
    'skin_to_skin' => t.activitySkinToSkin,
    'swim' => t.activitySwim,
    'music' => t.activityMusic,
    'left' => t.left,
    'right' => t.right,
    'both' => t.both,
    _ => null,
  };
}

/// "Potty" / "Accident" / "Sat but dry" for a potty entry, null for a diaper.
String? pottyLabel(dynamic potty) => switch (potty) {
  'sat_dry' => l10n.pottySatDry,
  'success' => l10n.pottySuccess,
  'accident' => l10n.pottyAccident,
  _ => null,
};

/// "Wet", "Dirty" or "Wet + dirty" (as for diapers).
String wetDirty(Event e) => switch ((e['wet'] == true, e['dirty'] == true)) {
  (true, true) => l10n.wetAndDirty,
  (true, false) => l10n.wet,
  (false, true) => l10n.dirty,
  _ => '',
};

/// Title and one-line detail for an event, e.g. ("Bottle", "120 mL formula").
(String, String) describe(Event e, Units u) {
  String sides() {
    final l = toInt(e['left_seconds']) ?? 0, r = toInt(e['right_seconds']) ?? 0;
    return [if (l > 0) '${l10n.leftShort} ${duration(l)}', if (r > 0) '${l10n.rightShort} ${duration(r)}'].join(' · ');
  }

  switch (e.type) {
    case 'feed':
      final method = e['method'] as String?;
      final amount = toDouble(e['amount_ml']);
      final milk = switch (e['milk'] as String?) {
        final m? => cap(m).toLowerCase(),
        null => null,
      };
      switch (method) {
        case 'bottle':
          return (l10n.kindBottle, [u.volume(amount), ?milk].where((s) => s.isNotEmpty).join(' '));
        case 'solids':
          return (l10n.kindSolids, (e['foods'] as String?) ?? '');
        case 'combo':
          return (l10n.breastfeedPlusBottle, [sides(), if (amount != null) u.volume(amount)].where((s) => s.isNotEmpty).join(' · '));
        default:
          final end = e.endSide;
          return (l10n.kindBreastfeed, [sides(), if (end != null) l10n.endedSide(end == 'left' ? l10n.leftShort : l10n.rightShort)].where((s) => s.isNotEmpty).join(' · '));
      }
    case 'sleep':
      return (l10n.kindSleep, [duration(e.durationSeconds), if (e['location'] != null) cap(e['location'])].where((s) => s.isNotEmpty).join(' · '));
    case 'diaper' when e['potty'] != null:
      final parts = <String>[
        e['potty'] == 'success' ? l10n.inThePotty : pottyLabel(e['potty'])!,
        if (e['potty'] != 'sat_dry') wetDirty(e),
        if (e['color'] != null) cap(e['color']),
        if (e['consistency'] != null) cap(e['consistency']),
        if (e['rash'] == true) l10n.rash,
        if (e['blowout'] == true) l10n.blowout,
      ];
      return (l10n.kindPotty, parts.where((s) => s.isNotEmpty).join(' · '));
    case 'diaper':
      final parts = <String>[
        if (e['wet'] == true || e['dirty'] == true) wetDirty(e) else l10n.dry,
        if (e['color'] != null) cap(e['color']),
        if (e['consistency'] != null) cap(e['consistency']),
        if (e['rash'] == true) l10n.rash,
        if (e['blowout'] == true) l10n.blowout,
      ];
      return (l10n.kindDiaper, parts.join(' · '));
    case 'pump':
      final total = (toDouble(e['left_ml']) ?? 0) + (toDouble(e['right_ml']) ?? 0);
      return (l10n.kindPump, [if (total > 0) u.volume(total), if (e.durationSeconds != null) duration(e.durationSeconds)].join(' · '));
    case 'growth':
      return (
        l10n.kindGrowth,
        [
          u.weight(toDouble(e['weight_g'])),
          if (e['length_cm'] != null) l10n.lengthShort(u.length(toDouble(e['length_cm']))),
          if (e['head_cm'] != null) l10n.headShort(u.length(toDouble(e['head_cm']))),
        ].where((s) => s.isNotEmpty).join(' · '),
      );
    case 'health':
      final kind = e['kind'] as String?;
      if (kind == 'temperature') return (l10n.kindTemperature, u.temp(toDouble(e['temperature_c'])));
      final dose = [if (e['dose'] != null) Units._n(toDouble(e['dose']) ?? 0, 2), if (e['dose_unit'] != null) e['dose_unit']].join(' ');
      return (kind == null ? l10n.kindHealth : cap(kind), [if (e['name'] != null) e['name'] as String, if (dose.isNotEmpty) dose].join(' · '));
    case 'activity':
      return (e['kind'] == null ? l10n.kindActivity : cap(e['kind'] as String), duration(e.durationSeconds));
    case 'milestone':
      return (l10n.kindMilestone, (e['name'] as String?) ?? '');
    default:
      return (l10n.kindNote, '');
  }
}
