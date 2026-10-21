import 'package:flutter_test/flutter_test.dart';
import 'package:nestling/api/api.dart';
import 'package:nestling/local/domain.dart';
import 'package:nestling/local/schedule.dart';

int ms(String local) => DateTime.parse(local).millisecondsSinceEpoch;

void main() {
  test('a milestone may name a baby tooth A-T, like the server', () {
    expect(normalizeDetails({'type': 'milestone', 'name': 'First tooth', 'tooth': 'O'})['tooth'], 'O');
    expect(() => normalizeDetails({'type': 'milestone', 'name': 'First tooth', 'tooth': 'Z'}), throwsA(isA<ApiException>()));
  });

  test('timer side and start edits match the server', () {
    Segment seg(String side, int start, [int? end]) => Segment(side, start, end);
    List<Segment> base() => [seg('left', 0, 60000), seg('right', 70000)];
    const now = 100000;

    var segs = base();
    setSide(segs, 'right', 300000, now);
    expect(sideSeconds(segs, now), (60, 300, 360));
    expect(segs[1].end, isNull);

    segs = base();
    setSide(segs, 'left', 0, now);
    expect(sideSeconds(segs, now), (0, 30, 30));

    segs = [seg('left', 0)];
    setSide(segs, 'right', 20000, now);
    expect(sideSeconds(segs, now), (100, 20, 120));
    expect(segs.last.side, 'left');

    segs = base();
    setStart(segs, -50000, now);
    expect(sideSeconds(segs, now), (110, 30, 140));
    segs = base();
    setStart(segs, 80000, now);
    expect(sideSeconds(segs, now), (0, 20, 20));
    expect(() => setStart([seg('left', 0, 60000)], 70000, now), throwsA(anything));
  });

  test('empty segments are dropped when a new one starts (same case as timers.rs)', () {
    final segs = [Segment('left', 0, 10), Segment('right', 10, 900)];
    pushSegment(segs, Segment('left', 2000));
    expect(segs.length, 2);
    expect((segs[0].end, segs[1].start), (10, 2000));
    // An empty first segment keeps the start time.
    final first = [Segment('left', 0, 0)];
    pushSegment(first, Segment('left', 20));
    expect(first.length, 2);
  });

  test('next medicine dose (same cases as schedule.rs)', () {
    const h = 3600000, now = 100 * h;
    Map<String, dynamic> med(num every, [int? max]) => {'name': 'Tylenol', 'every_hours': every, 'max_per_day': ?max};
    expect(medicineStatus(med(4), [], now).nextAt, null);
    var st = medicineStatus(med(4), [now - h, now - 6 * h], now);
    expect((st.lastAt, st.nextAt, st.doses24h, st.limited), (now - h, now + 3 * h, 2, false));
    final doses = [now - h, now - 6 * h, now - 12 * h, now - 20 * h, now - 30 * h];
    st = medicineStatus(med(4, 4), doses, now);
    expect((st.nextAt, st.doses24h, st.limited), (now + 4 * h, 4, true));
    st = medicineStatus(med(4, 5), doses, now);
    expect((st.nextAt, st.limited), (now + 3 * h, false));
    expect(() => checkMedicines([med(4, 4), {...med(6), 'name': '  tylenol '}]), throwsA(anything));
    expect(checkMedicines([{...med(24), 'name': ' Vitamin   D ', 'dose_unit': ' '}]).first, {'name': 'Vitamin D', 'every_hours': 24, 'remind': false});
    expect(() => checkReminders([{'type': 'bath', 'after_minutes': 180}]), throwsA(anything));
  });

  test('medicine at set times (same cases as schedule.rs, in local time)', () {
    const h = 3600000, day = 24 * h;
    final at8 = DateTime(2026, 7, 10, 8).millisecondsSinceEpoch;
    Map<String, dynamic> daily(List<String> times) => {'name': 'Vitamin D', 'every_hours': 24, 'times': times};
    final m = daily(['08:00']);
    // Nothing given: due from 08:00 (shown as "next at 08:00" from 06:00).
    var st = medicineStatus(m, [], at8 + h);
    expect((st.nextAt, st.due), (at8, true));
    st = medicineStatus(m, [], at8 - h);
    expect((st.nextAt, st.due), (at8, true));
    st = medicineStatus(m, [], at8 - 3 * h);
    expect((st.nextAt, st.due), (DateTime(2026, 7, 9, 8).millisecondsSinceEpoch, true));
    // Given at 07:00 or 21:00: counts for today's 08:00; the next is tomorrow's.
    for (final given in [at8 - h, at8 + 13 * h]) {
      st = medicineStatus(m, [given], given + 1);
      expect((st.nextAt, st.due, st.lastAt), (DateTime(2026, 7, 11, 8).millisecondsSinceEpoch, false, given));
    }
    // Yesterday's dose doesn't count for today.
    st = medicineStatus(m, [at8 - day + 3 * h], at8 + 1);
    expect((st.nextAt, st.due), (at8, true));
    // Close times: the window before a time is at most half the gap.
    expect(earlyMs([480, 540, 1200]), 30 * 60000);
    st = medicineStatus(daily(['20:00', '08:00', '09:00']), [at8 + 10 * 60000], at8 + 31 * 60000);
    expect((st.nextAt, st.due), (at8 + h, true));
    // Saved sorted, without duplicates; a bad time is refused.
    expect(checkMedicines([daily([' 20:00', '8:00', '08:00'])]).first['times'], ['08:00', '20:00']);
    expect(() => checkMedicines([daily(['24:00'])]), throwsA(anything));
    expect(checkMedicines([daily([])]).first.containsKey('times'), false);
  });

  test('routines every N days and on weekdays (same cases as schedule.rs, in local time)', () {
    const h = 3600000;
    int at(int day, [int hour = 19]) => DateTime(2026, 7, day, hour).millisecondsSinceEpoch;
    // 2026-07-11 is a Saturday. A bath every 2 days at 19:00.
    final bath = {'name': 'bath', 'every_hours': 48, 'times': ['19:00'], 'every_days': 2};
    var st = routineStatus(bath, [], at(11) + h);
    expect((st.nextAt, st.due), (at(11), true));
    for (final done in [at(11, 8), at(11) - h, at(11) + 2 * h]) {
      st = routineStatus(bath, [done], at(11) + 3 * h);
      expect((st.nextAt, st.due), (at(13), false));
    }
    st = routineStatus(bath, [at(10)], at(11) + h);
    expect((st.nextAt, st.due), (at(12), false));
    st = routineStatus(bath, [at(9)], at(11) + h);
    expect((st.nextAt, st.due), (at(11), true));
    // Mondays and Fridays (13th, 17th).
    final weekly = {...bath, 'every_days': null, 'weekdays': [1, 5]};
    st = routineStatus(weekly, [at(10)], at(11, 12));
    expect((st.nextAt, st.due), (at(13), false));
    st = routineStatus(weekly, [at(10)], at(13) + h);
    expect((st.nextAt, st.due), (at(13), true));
    st = routineStatus(weekly, [at(13) + 600000], at(13) + h);
    expect((st.nextAt, st.due), (at(17), false));
    // Validation, as the server does.
    expect(checkRoutines([{...bath, 'every_days': 1, 'weekdays': [5, 1, 1]}]).first, {
      'name': 'bath',
      'every_hours': 48,
      'remind': false,
      'times': ['19:00'],
      'weekdays': [1, 5],
    });
    expect(() => checkRoutines([{...bath, 'weekdays': [1]}]), throwsA(anything));
    expect(() => checkRoutines([{'name': 'bath', 'every_hours': 48, 'every_days': 2}]), throwsA(anything));
    expect(() => checkRoutines([bath, {...bath, 'name': 'Bath '}]), throwsA(anything));
    expect(checkRoutines([{...bath, 'every_days': null, 'weekdays': [1, 2, 3, 4, 5, 6, 7]}]).first.containsKey('weekdays'), false);
    expect(routineKey('Tummy  time'), routineKey('tummy_time'));
  });

  test('stopping a breastfeed timer makes a feed', () {
    final segs = [Segment('left', 0, 600000), Segment('right', 600000)];
    final (start, end, details) = stopTimerSegments('breastfeed', segs, null, {}, 900000);
    expect((start, end), (0, 900000));
    expect(details, {'type': 'feed', 'method': 'breast', 'left_seconds': 600, 'right_seconds': 300, 'start_side': 'left'});
  });

  test('validation and normalization', () {
    expect(() => validateEvent(normalizeDetails({'type': 'diaper'}), 0, null, null), throwsA(anything));
    expect(() => validateEvent(normalizeDetails({'type': 'sleep'}), 0, null, null), throwsA(anything));
    expect(() => normalizeDetails({'type': 'feed'}), throwsA(anything));
    final d = normalizeDetails({'type': 'feed', 'method': 'bottle', 'amount_ml': 120, 'bogus': 1});
    expect(d, {'type': 'feed', 'method': 'bottle', 'amount_ml': 120.0});
    expect(normalizeDetails({'type': 'diaper', 'wet': true})['dirty'], false);
  });

  test('potty (same rules as model.rs)', () {
    void check(Map<String, dynamic> d) => validateEvent(normalizeDetails({'type': 'diaper', ...d}), 0, null, null);
    check({'potty': 'sat_dry', 'dry': true});
    check({'potty': 'success', 'dirty': true, 'color': 'brown'});
    expect(() => check({'potty': 'sat_dry', 'wet': true}), throwsA(anything));
    expect(() => check({'potty': 'accident', 'dry': true}), throwsA(anything));
    check({'potty': 'accident', 'dirty': true, 'blowout': true, 'consistency': 'runny'});
    expect(() => normalizeDetails({'type': 'diaper', 'potty': 'maybe'}), throwsA(anything));
  });

  test('diaper sizes (same rules as model.rs)', () {
    void check(Map<String, dynamic> d) => validateEvent(normalizeDetails({'type': 'diaper', ...d}), 0, null, null);
    check({'wet': true, 'dirty': true, 'wet_size': 'small', 'dirty_size': 'large'});
    expect(() => check({'wet': true, 'dirty_size': 'medium'}), throwsA(anything));
    expect(() => check({'dry': true, 'wet_size': 'small'}), throwsA(anything));
    expect(() => normalizeDetails({'type': 'diaper', 'wet': true, 'wet_size': 'huge'}), throwsA(anything));
  });

  test('daily stats split sleep across midnight (same cases as trends.rs)', () {
    TrendEvent ev(String start, String? end, Map<String, dynamic> d) => TrendEvent(ms(start), end == null ? null : ms(end), d);
    final events = [
      ev('2026-10-01T22:00', '2026-10-02T04:00', {'type': 'sleep'}),
      ev('2026-10-02T13:00', '2026-10-02T14:30', {'type': 'sleep'}),
      ev('2026-10-02T08:00', null, {'type': 'feed', 'method': 'bottle', 'amount_ml': 120.0}),
      ev('2026-10-02T11:00', null, {'type': 'feed', 'method': 'breast', 'left_seconds': 600, 'right_seconds': 300}),
      ev('2026-10-02T23:00', null, {'type': 'diaper', 'wet': true, 'dirty': true}),
    ];
    final t = computeTrends(events, DateTime(2026, 10, 1), 2, ms('2026-10-05T00:00'));
    final days = t['days'] as List;
    expect(days[0]['sleep']['total_seconds'], 2 * 3600);
    expect(days[0]['sleep']['night_seconds'], 2 * 3600);
    expect(days[0]['sleep']['longest_seconds'], 6 * 3600);
    expect(days[1]['sleep']['total_seconds'], 4 * 3600 + 5400);
    expect(days[1]['sleep']['day_seconds'], 5400);
    expect(days[1]['sleep']['nap_count'], 1);
    expect(days[1]['feed']['count'], 2);
    expect(days[1]['feed']['bottle_ml'], 120.0);
    expect(days[1]['feed']['breast_seconds'], 900);
    expect(days[1]['diaper']['night_count'], 1);
    expect(t['averages']['feed_interval_seconds'], 3 * 3600);
    expect(t['averages']['wake_window_seconds'], 9 * 3600);
    expect(t['averages']['days'], 2);
  });

  test('feed sides, day/night and the previous period (same case as trends.rs)', () {
    TrendEvent ev(String start, Map<String, dynamic> d) => TrendEvent(ms(start), null, d);
    Map<String, dynamic> breast(int l, int r) => {'type': 'feed', 'method': 'breast', 'left_seconds': l, 'right_seconds': r};
    final events = [
      ev('2026-10-01T10:00', breast(100, 100)),
      ev('2026-10-02T10:00', breast(600, 300)),
      ev('2026-10-02T22:00', breast(60, 120)),
      ev('2026-10-02T12:00', {'type': 'feed', 'method': 'bottle', 'amount_ml': 90.0, 'milk': 'formula'}),
      ev('2026-10-02T20:00', {'type': 'diaper', 'wet': true, 'dirty': true}),
      // Potty trips are counted on their own, not as diapers.
      ev('2026-10-02T09:00', {'type': 'diaper', 'wet': true, 'potty': 'success'}),
      ev('2026-10-02T11:00', {'type': 'diaper', 'dry': true, 'potty': 'sat_dry'}),
      ev('2026-10-02T15:00', {'type': 'diaper', 'dirty': true, 'potty': 'accident'}),
    ];
    final now = ms('2026-10-05T00:00');
    final t = computeTrendsWithPrevious(events, DateTime(2026, 10, 2), 1, now);
    final a = t['averages'];
    expect((a['breast_left_seconds_per_day'], a['breast_right_seconds_per_day']), (660.0, 420.0));
    expect((a['day_breast_left_seconds_per_day'], a['day_breast_right_seconds_per_day']), (600.0, 300.0));
    expect((a['night_breast_left_seconds_per_day'], a['night_breast_right_seconds_per_day']), (60.0, 120.0));
    expect((a['breast_feeds_per_day'], a['bottle_feeds_per_day'], a['formula_ml_per_day']), (2.0, 1.0, 90.0));
    expect((a['night_diapers_per_day'], a['night_wet_per_day'], a['day_diapers_per_day']), (1.0, 1.0, 0.0));
    expect((a['diapers_per_day'], a['wet_per_day'], a['dirty_per_day']), (1.0, 1.0, 1.0));
    expect((a['potty_per_day'], a['potty_success_per_day'], a['potty_accidents_per_day']), (3.0, 1.0, 1.0));
    expect((t['previous']['feeds_per_day'], t['previous']['breast_seconds_per_day']), (1.0, 200.0));
    expect(computeTrendsWithPrevious(events, DateTime(2026, 10, 1), 1, now)['previous'], isNull);
  });

  test('custom daytime hours (same case as trends.rs)', () {
    final events = [
      TrendEvent(ms('2026-10-02T07:00'), null, {'type': 'diaper', 'wet': true}),
      TrendEvent(ms('2026-10-02T07:00'), ms('2026-10-02T09:00'), {'type': 'sleep'}),
    ];
    final day = dayWindowOf({'day_start': '08:00', 'day_end': '20:30'});
    expect(day, (start: 480, end: 1230));
    final d = (computeTrends(events, DateTime(2026, 10, 2), 1, ms('2026-10-05T00:00'), day: day)['days'] as List).first;
    expect((d['diaper']['day_count'], d['diaper']['night_count']), (0, 1));
    expect((d['sleep']['day_seconds'], d['sleep']['night_seconds'], d['sleep']['nap_count']), (3600, 3600, 0));
    expect(dayWindowOf({'day_start': '21:00', 'day_end': '20:00'}), defaultDay);
  });

  test('last 24 hours cross midnight', () {
    TrendEvent ev(String start, String? end, Map<String, dynamic> d) => TrendEvent(ms(start), end == null ? null : ms(end), d);
    final events = [
      ev('2026-10-01T20:00', null, {'type': 'diaper', 'wet': true}),
      ev('2026-10-01T22:00', '2026-10-02T04:00', {'type': 'sleep'}),
      ev('2026-10-01T08:00', null, {'type': 'diaper', 'dirty': true}),
      ev('2026-10-02T07:00', '2026-10-02T08:00', {'type': 'sleep'}),
    ];
    final d = last24h(events, ms('2026-10-02T10:00'));
    expect((d['diaper']['count'], d['diaper']['wet'], d['diaper']['dirty']), (1, 1, 0));
    expect(d['sleep']['total_seconds'], 7 * 3600);
    expect(d['sleep']['night_seconds'], 6 * 3600);
    expect(d['sleep']['nap_count'], 1);
  });
}
