/// The server's domain rules, ported to Dart so the app can keep working without it:
/// event validation (`src/model.rs`), timer segment math (`src/routes/timers.rs`) and daily
/// stats (`src/trends.rs`). Times are epoch milliseconds; days are the device's calendar days.
library;

import 'dart:math' as math;

import '../api/api.dart';

ApiException badRequest(String message) => ApiException('bad_request', message, 400);
ApiException notFound(String what) => ApiException('not_found', '$what not found', 404);
ApiException conflict(String message) => ApiException('conflict', message, 409);

const eventTypes = ['feed', 'sleep', 'diaper', 'pump', 'growth', 'health', 'activity', 'milestone', 'note'];

// ---- events ----

const _feedMethods = ['breast', 'bottle', 'combo', 'solids'];
const _milks = ['breast_milk', 'formula', 'mixed'];
const _sides = ['left', 'right', 'both'];
const _poopColors = ['yellow', 'green', 'brown', 'black', 'red', 'gray'];
const _poopConsistencies = ['runny', 'mushy', 'mucousy', 'pebbles', 'solid'];
const _healthKinds = ['medicine', 'temperature', 'vaccine', 'appointment', 'symptom'];

/// Field kinds per event type, in the order the server writes them.
const _fields = <String, Map<String, String>>{
  'feed': {
    'method': 'method',
    'left_seconds': 'secs',
    'right_seconds': 'secs',
    'start_side': 'side',
    'amount_ml': 'num',
    'milk': 'milk',
    'formula_name': 'str',
    'foods': 'str',
  },
  'sleep': {'location': 'str'},
  'diaper': {
    'wet': 'bool',
    'dirty': 'bool',
    'dry': 'bool',
    'rash': 'bool',
    'blowout': 'bool',
    'color': 'color',
    'consistency': 'consistency',
  },
  'pump': {'left_ml': 'num', 'right_ml': 'num', 'left_seconds': 'secs', 'right_seconds': 'secs'},
  'growth': {'weight_g': 'num', 'length_cm': 'num', 'head_cm': 'num'},
  'health': {'kind': 'health', 'name': 'str', 'dose': 'num', 'dose_unit': 'str', 'temperature_c': 'num'},
  'activity': {'kind': 'str'},
  'milestone': {'name': 'str'},
  'note': {},
};

const _required = {'feed': 'method', 'health': 'kind', 'activity': 'kind', 'milestone': 'name'};

/// The type-specific fields of [input] as the server would store them: known fields only, values
/// checked and normalized (amounts as doubles, seconds as ints, diaper flags always present).
Map<String, dynamic> normalizeDetails(Map<String, dynamic> input) {
  final type = input['type'];
  if (type is! String || !eventTypes.contains(type)) {
    throw badRequest('unknown variant `$type`, expected one of ${eventTypes.join(', ')}');
  }
  final out = <String, dynamic>{'type': type};
  for (final MapEntry(key: field, value: kind) in _fields[type]!.entries) {
    final v = input[field];
    if (v == null) {
      if (kind == 'bool') out[field] = false;
      if (_required[type] == field) throw badRequest('missing field `$field`');
      continue;
    }
    String enumOf(List<String> values) =>
        v is String && values.contains(v) ? v : throw badRequest('unknown variant `$v` for $field, expected one of ${values.join(', ')}');
    out[field] = switch (kind) {
      'bool' => v is bool ? v : throw badRequest('$field must be true or false'),
      'num' => v is num ? v.toDouble() : throw badRequest('$field must be a number'),
      'secs' => v is num && v >= 0 && v <= 0xFFFFFFFF ? v.round() : throw badRequest('$field must be a whole number of seconds'),
      'str' => v is String ? v : throw badRequest('$field must be text'),
      'method' => enumOf(_feedMethods),
      'milk' => enumOf(_milks),
      'side' => enumOf(_sides),
      'color' => enumOf(_poopColors),
      'consistency' => enumOf(_poopConsistencies),
      'health' => enumOf(_healthKinds),
      _ => v,
    };
  }
  return out;
}

void _nonNegative(String field, dynamic v, double max) {
  if (v is! num) return;
  if (!v.isFinite || v < 0) throw badRequest('$field must be a positive number');
  if (v > max) throw badRequest('$field looks too large ($v)');
}

void _notBlank(String field, dynamic v) {
  if (v is! String || v.trim().isEmpty) throw badRequest('$field is required');
}

/// Same rules as `Details::validate` on the server.
void validateEvent(Map<String, dynamic> d, int start, int? end, String? note) {
  if (end != null) {
    if (end < start) throw badRequest('end must be after start');
    if (end - start > 7 * 24 * 3600 * 1000) throw badRequest('an event cannot last more than 7 days');
  }
  switch (d['type']) {
    case 'feed':
      _nonNegative('amount_ml', d['amount_ml'], 2000);
      if (d['milk'] != null && (d['method'] == 'breast' || d['method'] == 'solids')) {
        throw badRequest('milk only applies to bottle or combo feeds');
      }
      if (d['start_side'] == 'both') throw badRequest('start_side must be left or right');
    case 'sleep':
      if (end == null) throw badRequest('sleep needs an end time (use a sleep timer for a nap in progress)');
    case 'diaper':
      if (d['wet'] != true && d['dirty'] != true && d['dry'] != true) throw badRequest('a diaper must be wet, dirty or dry');
      if ((d['color'] != null || d['consistency'] != null) && d['dirty'] != true) {
        throw badRequest('color and consistency only apply to dirty diapers');
      }
    case 'pump':
      _nonNegative('left_ml', d['left_ml'], 1000);
      _nonNegative('right_ml', d['right_ml'], 1000);
    case 'growth':
      if (d['weight_g'] == null && d['length_cm'] == null && d['head_cm'] == null) {
        throw badRequest('growth needs weight_g, length_cm or head_cm');
      }
      _nonNegative('weight_g', d['weight_g'], 50000);
      _nonNegative('length_cm', d['length_cm'], 200);
      _nonNegative('head_cm', d['head_cm'], 80);
    case 'health':
      switch (d['kind']) {
        case 'temperature':
          final t = d['temperature_c'];
          if (t == null) throw badRequest('temperature_c is required');
          if (t < 25 || t > 45) throw badRequest('temperature_c $t is out of range (25-45 °C)');
        case 'medicine' || 'vaccine' || 'symptom':
          _notBlank('name', d['name']);
          _nonNegative('dose', d['dose'], 10000);
      }
    case 'activity':
      _notBlank('kind', d['kind']);
    case 'milestone':
      _notBlank('name', d['name']);
    case 'note':
      _notBlank('note', note);
  }
}

String? cleanNote(dynamic note) {
  if (note is! String) return null;
  final t = note.trim();
  return t.isEmpty ? null : t;
}

// ---- times ----

int nowMs() => DateTime.now().millisecondsSinceEpoch;

/// `"now"`, RFC 3339, or a local time without offset (the device's timezone).
int parseTimeMs(String s) {
  s = s.trim();
  if (s.toLowerCase() == 'now') return nowMs();
  final t = DateTime.tryParse(s);
  if (t == null) throw badRequest("invalid time '$s' (use 'now', '2026-10-08T11:30' or '2026-10-08T11:30:00-04:00')");
  return t.millisecondsSinceEpoch;
}

int? parseOptTimeMs(dynamic s) => s is String ? parseTimeMs(s) : null;

/// Local midnight (or [hour]) of a calendar day; DST gaps roll forward like the server.
int localMs(DateTime date, [int hour = 0]) => DateTime(date.year, date.month, date.day, hour).millisecondsSinceEpoch;

DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

String dateString(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ---- timers ----

class Segment {
  Segment(this.side, this.start, [this.end]);
  String? side;
  int start;
  int? end;

  Segment copy() => Segment(side, start, end);
}

const timerKinds = ['breastfeed', 'pump', 'sleep'];

String? checkSide(String kind, String? side) => switch (kind) {
  'sleep' => null,
  'breastfeed' => (side ?? 'left') == 'both'
      ? throw badRequest("a breastfeed timer runs on one side at a time; use 'switch' to change sides")
      : side ?? 'left',
  _ => side ?? 'both',
};

/// Seconds on each side (both-sided segments count for both) and in total.
(int, int, int) sideSeconds(List<Segment> segs, int now) {
  var left = 0, right = 0, total = 0;
  for (final s in segs) {
    final ms = (s.end ?? now) - s.start;
    total += ms;
    if (s.side == 'left' || s.side == 'both') left += ms;
    if (s.side == 'right' || s.side == 'both') right += ms;
  }
  return (left ~/ 1000, right ~/ 1000, total ~/ 1000);
}

/// Move the timer's start (see `set_start` on the server).
/// Start a new segment. A closed segment shorter than a second (paused or switched right after it
/// began; it would show as 0 s) is dropped first, unless it holds the timer's start. Port of timers.rs `push_segment`.
void pushSegment(List<Segment> segs, Segment seg) {
  if (segs.length > 1) {
    final last = segs.last;
    if (last.end != null && last.end! - last.start < 1000 && segs.take(segs.length - 1).any((s) => s.start <= last.start)) segs.removeLast();
  }
  segs.add(seg);
}

void setStart(List<Segment> segs, int start, int now) {
  segs.sort((a, b) => a.start.compareTo(b.start));
  if (segs.isEmpty) return;
  if (start <= segs.first.start) {
    segs.first.start = start;
    return;
  }
  segs.removeWhere((s) => (s.end ?? now) <= start);
  if (segs.isEmpty) throw badRequest("the start must be before the timer's last minute");
  segs.first.start = math.max(segs.first.start, start);
}

/// Make the time on [side] (null: the total) add up to [target] ms (see `set_side` on the server).
void setSide(List<Segment> segs, String? side, int target, int now) {
  int len(Segment s) => (s.end ?? now) - s.start;
  bool matches(Segment s) => side == null || s.side == side;
  var delta = target - segs.where(matches).fold<int>(0, (a, s) => a + len(s));
  for (final s in segs.reversed.where(matches)) {
    if (delta == 0) break;
    final change = math.max(delta, -len(s));
    if (s.end == null) {
      s.start -= change;
    } else {
      s.end = s.end! + change;
    }
    delta -= change;
  }
  if (delta > 0) {
    final last = segs.lastOrNull;
    if (last != null && last.end == null) {
      segs.insert(segs.length - 1, Segment(side, last.start - delta, last.start));
    } else {
      final at = last?.end ?? now;
      segs.add(Segment(side, at, at + delta));
    }
  }
  final ends = segs.map((s) => s.end).whereType<int>();
  final over = (ends.isEmpty ? now : ends.reduce(math.max)) - now;
  if (over > 0) {
    for (final s in segs.where((s) => s.end != null)) {
      s.start -= over;
      s.end = s.end! - over;
    }
  }
}

/// The timer kind a saved entry can be continued as (null: it can't be).
String? continuableKind(Map<String, dynamic> event) => switch (event['type']) {
  'feed' when event['method'] == 'breast' => 'breastfeed',
  'pump' => 'pump',
  'sleep' => 'sleep',
  _ => null,
};

/// Segments rebuilt from a saved breastfeed / pump / sleep entry (see `segments_from_event` on
/// the server): one after the other from its start, moved back if they would end after [now].
List<Segment> segmentsFromEvent(String kind, int start, int? end, Map<String, dynamic> details, int now) {
  int ms(dynamic s) => s is num ? s.round() * 1000 : 0;
  final List<(String?, int)> parts;
  switch (kind) {
    case 'breastfeed':
      final (left, right) = (ms(details['left_seconds']), ms(details['right_seconds']));
      final first = details['start_side'] as String? ?? (left == 0 && right > 0 ? 'right' : 'left');
      parts = first == 'left' ? [('left', left), ('right', right)] : [('right', right), ('left', left)];
    case 'pump':
      final (left, right) = (ms(details['left_seconds']), ms(details['right_seconds']));
      parts = left == right ? [('both', left)] : [('left', left), ('right', right)];
    default:
      parts = [(null, (end ?? start) - start)];
  }
  final segs = <Segment>[];
  var at = start;
  for (final (side, len) in parts.where((p) => p.$2 > 0)) {
    segs.add(Segment(side, at, at + len));
    at += len;
  }
  // Nothing timed: keep the start time with an empty segment.
  if (segs.isEmpty) segs.add(Segment(parts.first.$1, start, start));
  final over = at - now;
  if (over > 0) {
    for (final s in segs) {
      s.start -= over;
      s.end = s.end! - over;
    }
  }
  return segs;
}

/// Closes the timer at [end] (capped at now) and returns the event it becomes:
/// `(start, end, details)`.
(int, int, Map<String, dynamic>) stopTimerSegments(String kind, List<Segment> segs, int? requestedEnd, Map<String, dynamic> req, int now) {
  final end = math.min(requestedEnd ?? now, now);
  if (segs.isNotEmpty && segs.last.end == null) segs.last.end = now;
  final firstStart = segs.isEmpty ? null : segs.map((s) => s.start).reduce(math.min);
  segs.retainWhere((s) => s.start == firstStart || s.start < end);
  for (final s in segs) {
    if ((s.end ?? now) > end) s.end = math.max(end, s.start);
  }
  final start = segs.isEmpty ? now : segs.map((s) => s.start).reduce(math.min);
  if (end < start) throw badRequest('end must be after the timer started');
  final ends = segs.map((s) => s.end).whereType<int>();
  final eventEnd = math.max(ends.isEmpty ? end : ends.reduce(math.max), start);
  final (left, right, _) = sideSeconds(segs, now);
  int? opt(int s) => s > 0 ? s : null;
  final details = switch (kind) {
    'breastfeed' => <String, dynamic>{
      'type': 'feed',
      'method': 'breast',
      'left_seconds': opt(left) ?? 0,
      'right_seconds': opt(right) ?? 0,
      'start_side': segs.firstOrNull?.side,
    },
    'pump' => <String, dynamic>{
      'type': 'pump',
      'left_ml': req['left_ml'],
      'right_ml': req['right_ml'],
      'left_seconds': opt(left),
      'right_seconds': opt(right),
    },
    _ => <String, dynamic>{'type': 'sleep', 'location': req['location']},
  };
  final normalized = normalizeDetails(details);
  validateEvent(normalized, start, eventEnd, req['note'] as String?);
  return (start, eventEnd, normalized);
}

// ---- daily stats ----

/// When daytime starts and ends, in minutes after local midnight (the family's `day_start` /
/// `day_end`; `DayWindow` in `src/trends.rs`).
typedef DayWindow = ({int start, int end});

const defaultDay = (start: 6 * 60, end: 18 * 60);

/// "06:30" → 390; null unless a valid time of day (up to "24:00").
int? parseHhmm(dynamic s) {
  final m = s is String ? RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s) : null;
  if (m == null) return null;
  final h = int.parse(m[1]!), min = int.parse(m[2]!);
  return min < 60 && h * 60 + min <= 24 * 60 ? h * 60 + min : null;
}

String hhmm(int minutes) => '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// The family's day window (the default when unset or invalid).
DayWindow dayWindowOf(Map<String, dynamic>? family) {
  final start = parseHhmm(family?['day_start']), end = parseHhmm(family?['day_end']);
  return start != null && end != null && start < end ? (start: start, end: end) : defaultDay;
}

(int, int) _daytime(DateTime d, DayWindow w) => (
  DateTime(d.year, d.month, d.day, 0, w.start).millisecondsSinceEpoch,
  DateTime(d.year, d.month, d.day, 0, w.end).millisecondsSinceEpoch,
);

/// What the stats need from an event.
class TrendEvent {
  TrendEvent(this.start, this.end, this.details);
  final int start;
  final int? end;
  final Map<String, dynamic> details;
  String get type => details['type'];
}

int _overlap(int a0, int a1, int b0, int b1) => math.max(math.min(a1, b1) - math.max(a0, b0), 0);

double _num(dynamic v) => v is num ? v.toDouble() : 0;

class _Extra {
  int napSeconds = 0, naps = 0, bottles = 0;
  double bottleMl = 0;
}

(Map<String, dynamic>, _Extra) _windowStats(List<TrendEvent> events, DateTime date, int w0, int w1, List<(int, int)> daytimes, int now) {
  final feed = <String, num>{
    'count': 0,
    'breast_count': 0,
    'breast_seconds': 0,
    'breast_left_seconds': 0,
    'breast_right_seconds': 0,
    'day_breast_seconds': 0,
    'day_breast_left_seconds': 0,
    'day_breast_right_seconds': 0,
    'bottle_count': 0,
    'bottle_ml': 0.0,
    'breast_milk_ml': 0.0,
    'formula_ml': 0.0,
    'mixed_ml': 0.0,
    'solids_count': 0,
  };
  final sleep = <String, num>{'total_seconds': 0, 'day_seconds': 0, 'night_seconds': 0, 'nap_count': 0, 'longest_seconds': 0};
  final diaper = <String, num>{'count': 0, 'wet': 0, 'dirty': 0, 'day_count': 0, 'night_count': 0, 'day_wet': 0, 'day_dirty': 0};
  final pump = <String, num>{'count': 0, 'total_ml': 0.0, 'total_seconds': 0};
  final extra = _Extra();
  void add(Map<String, num> m, String k, num v) => m[k] = m[k]! + v;
  for (final ev in events) {
    final startsIn = ev.start >= w0 && ev.start < w1;
    final daytime = daytimes.any((d) => ev.start >= d.$1 && ev.start < d.$2);
    final d = ev.details;
    switch (ev.type) {
      case 'feed' when startsIn:
        add(feed, 'count', 1);
        final method = d['method'];
        if (method == 'breast' || method == 'combo') {
          final left = _num(d['left_seconds']).round(), right = _num(d['right_seconds']).round();
          add(feed, 'breast_count', 1);
          add(feed, 'breast_seconds', left + right);
          add(feed, 'breast_left_seconds', left);
          add(feed, 'breast_right_seconds', right);
          if (daytime) {
            add(feed, 'day_breast_seconds', left + right);
            add(feed, 'day_breast_left_seconds', left);
            add(feed, 'day_breast_right_seconds', right);
          }
        }
        if (method == 'bottle' || method == 'combo') {
          add(feed, 'bottle_count', 1);
          final ml = _num(d['amount_ml']);
          add(feed, 'bottle_ml', ml);
          switch (d['milk']) {
            case 'breast_milk':
              add(feed, 'breast_milk_ml', ml);
            case 'formula':
              add(feed, 'formula_ml', ml);
            case 'mixed':
              add(feed, 'mixed_ml', ml);
          }
          if (ml > 0) {
            extra.bottleMl += ml;
            extra.bottles++;
          }
        }
        if (method == 'solids') add(feed, 'solids_count', 1);
      case 'sleep':
        final end = math.min(ev.end ?? ev.start, math.max(now, ev.start));
        final total = _overlap(ev.start, end, w0, w1);
        final dayt = daytimes.fold<int>(0, (a, dt) => a + _overlap(ev.start, end, math.max(dt.$1, w0), math.min(dt.$2, w1)));
        add(sleep, 'total_seconds', total ~/ 1000);
        add(sleep, 'day_seconds', dayt ~/ 1000);
        add(sleep, 'night_seconds', (total - dayt) ~/ 1000);
        if (startsIn) {
          final dur = (end - ev.start) ~/ 1000;
          sleep['longest_seconds'] = math.max(sleep['longest_seconds']!, dur);
          if (daytime) {
            add(sleep, 'nap_count', 1);
            extra.napSeconds += dur;
            extra.naps++;
          }
        }
      case 'diaper' when startsIn:
        add(diaper, 'count', 1);
        if (d['wet'] == true) add(diaper, 'wet', 1);
        if (d['dirty'] == true) add(diaper, 'dirty', 1);
        add(diaper, daytime ? 'day_count' : 'night_count', 1);
        if (daytime && d['wet'] == true) add(diaper, 'day_wet', 1);
        if (daytime && d['dirty'] == true) add(diaper, 'day_dirty', 1);
      case 'pump' when startsIn:
        add(pump, 'count', 1);
        add(pump, 'total_ml', _num(d['left_ml']) + _num(d['right_ml']));
        add(pump, 'total_seconds', ev.end == null ? 0 : (ev.end! - ev.start) ~/ 1000);
    }
  }
  final day = <String, dynamic>{'date': dateString(date), 'complete': w1 <= now, 'feed': feed, 'sleep': sleep, 'diaper': diaper, 'pump': pump};
  return (day, extra);
}

/// The 24 hours up to [now] (rolling).
Map<String, dynamic> last24h(List<TrendEvent> events, int now, {DayWindow day = defaultDay}) {
  final today = dateOnly(DateTime.fromMillisecondsSinceEpoch(now));
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  final daytimes = [for (final d in [yesterday, today]) _daytime(d, day)];
  final (stats, _) = _windowStats(events, today, now - 24 * 3600 * 1000, now, daytimes, now);
  stats['complete'] = false;
  return stats;
}

/// Epoch ms covering [days] days from [from] (local midnight to midnight).
(int, int) rangeMs(DateTime from, int days) => (localMs(from), localMs(DateTime(from.year, from.month, from.day + days)));

/// Same output as `GET /children/{id}/trends`.
Map<String, dynamic> computeTrends(List<TrendEvent> events, DateTime from, int days, int now, {DayWindow day = defaultDay}) {
  final out = <Map<String, dynamic>>[];
  var napTotal = 0, napN = 0, bfTotal = 0, bfN = 0, bottleN = 0;
  var bottleTotal = 0.0;
  for (var i = 0; i < days; i++) {
    final date = DateTime(from.year, from.month, from.day + i);
    final next = DateTime(date.year, date.month, date.day + 1);
    final (stats, extra) = _windowStats(events, date, localMs(date), localMs(next), [_daytime(date, day)], now);
    napTotal += extra.napSeconds;
    napN += extra.naps;
    bfTotal += (stats['feed']['breast_seconds'] as num).toInt();
    bfN += (stats['feed']['breast_count'] as num).toInt();
    bottleTotal += extra.bottleMl;
    bottleN += extra.bottles;
    out.add(stats);
  }
  final complete = out.where((d) => d['complete'] == true).toList();
  final basis = complete.isEmpty ? out : complete;
  final n = math.max(basis.length, 1);
  double avg(num Function(Map<String, dynamic> d) f) => (basis.fold<double>(0, (a, d) => a + f(d)) / n * 10).round() / 10;

  final (r0, r1) = rangeMs(from, days);
  final feedStarts = [for (final e in events) if (e.type == 'feed' && e.start >= r0 && e.start < r1) e.start]..sort();
  final gaps = [for (var i = 1; i < feedStarts.length; i++) feedStarts[i] - feedStarts[i - 1]].where((g) => g > 0).toList();
  final sleeps = [
    for (final e in events)
      if (e.type == 'sleep' && e.start < r1 && (e.end ?? e.start) >= r0) (e.start, e.end ?? e.start),
  ]..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  final wakes = [for (var i = 1; i < sleeps.length; i++) sleeps[i].$1 - sleeps[i - 1].$2].where((g) => g > 0).toList();
  int? meanS(List<int> v) => v.isEmpty ? null : v.reduce((a, b) => a + b) ~/ v.length ~/ 1000;

  return {
    'timezone': DateTime.now().timeZoneName,
    'from': dateString(from),
    'to': dateString(DateTime(from.year, from.month, from.day + days - 1)),
    'days': out,
    'averages': {
      'days': basis.length,
      'feeds_per_day': avg((d) => d['feed']['count']),
      'breast_feeds_per_day': avg((d) => d['feed']['breast_count']),
      'bottle_feeds_per_day': avg((d) => d['feed']['bottle_count']),
      'solids_per_day': avg((d) => d['feed']['solids_count']),
      'breast_seconds_per_day': avg((d) => d['feed']['breast_seconds']),
      'breast_left_seconds_per_day': avg((d) => d['feed']['breast_left_seconds']),
      'breast_right_seconds_per_day': avg((d) => d['feed']['breast_right_seconds']),
      'day_breast_seconds_per_day': avg((d) => d['feed']['day_breast_seconds']),
      'day_breast_left_seconds_per_day': avg((d) => d['feed']['day_breast_left_seconds']),
      'day_breast_right_seconds_per_day': avg((d) => d['feed']['day_breast_right_seconds']),
      'night_breast_seconds_per_day': avg((d) => d['feed']['breast_seconds'] - d['feed']['day_breast_seconds']),
      'night_breast_left_seconds_per_day': avg((d) => d['feed']['breast_left_seconds'] - d['feed']['day_breast_left_seconds']),
      'night_breast_right_seconds_per_day': avg((d) => d['feed']['breast_right_seconds'] - d['feed']['day_breast_right_seconds']),
      'bottle_ml_per_day': avg((d) => d['feed']['bottle_ml']),
      'breast_milk_ml_per_day': avg((d) => d['feed']['breast_milk_ml']),
      'formula_ml_per_day': avg((d) => d['feed']['formula_ml']),
      'mixed_ml_per_day': avg((d) => d['feed']['mixed_ml']),
      'sleep_seconds_per_day': avg((d) => d['sleep']['total_seconds']),
      'day_sleep_seconds_per_day': avg((d) => d['sleep']['day_seconds']),
      'night_sleep_seconds_per_day': avg((d) => d['sleep']['night_seconds']),
      'naps_per_day': avg((d) => d['sleep']['nap_count']),
      'longest_sleep_seconds': avg((d) => d['sleep']['longest_seconds']),
      'diapers_per_day': avg((d) => d['diaper']['count']),
      'wet_per_day': avg((d) => d['diaper']['wet']),
      'dirty_per_day': avg((d) => d['diaper']['dirty']),
      'day_diapers_per_day': avg((d) => d['diaper']['day_count']),
      'day_wet_per_day': avg((d) => d['diaper']['day_wet']),
      'day_dirty_per_day': avg((d) => d['diaper']['day_dirty']),
      'night_diapers_per_day': avg((d) => d['diaper']['night_count']),
      'night_wet_per_day': avg((d) => d['diaper']['wet'] - d['diaper']['day_wet']),
      'night_dirty_per_day': avg((d) => d['diaper']['dirty'] - d['diaper']['day_dirty']),
      'pumps_per_day': avg((d) => d['pump']['count']),
      'pumped_ml_per_day': avg((d) => d['pump']['total_ml']),
      'pump_seconds_per_day': avg((d) => d['pump']['total_seconds']),
      'feed_interval_seconds': meanS(gaps),
      'wake_window_seconds': meanS(wakes),
      'avg_breastfeed_seconds': bfN > 0 ? bfTotal ~/ bfN : null,
      'avg_bottle_ml': bottleN > 0 ? (bottleTotal / bottleN * 10).round() / 10 : null,
      'avg_nap_seconds': napN > 0 ? napTotal ~/ napN : null,
    },
    'previous': null,
  };
}

/// [computeTrends] plus `previous`: the averages of the [days] days before [from] (`src/trends.rs`
/// `compute_with_previous`). [events] must cover both periods.
Map<String, dynamic> computeTrendsWithPrevious(List<TrendEvent> events, DateTime from, int days, int now, {DayWindow day = defaultDay}) {
  final t = computeTrends(events, from, days, now, day: day);
  final prevFrom = DateTime(from.year, from.month, from.day - days);
  final (p0, p1) = rangeMs(prevFrom, days);
  if (events.any((e) => e.start >= p0 && e.start < p1)) t['previous'] = computeTrends(events, prevFrom, days, now, day: day)['averages'];
  return t;
}
