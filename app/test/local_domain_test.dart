import 'package:flutter_test/flutter_test.dart';
import 'package:nestling/local/domain.dart';

int ms(String local) => DateTime.parse(local).millisecondsSinceEpoch;

void main() {
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
    expect(() => check({'potty': 'accident', 'wet': true, 'blowout': true}), throwsA(anything));
    expect(() => normalizeDetails({'type': 'diaper', 'potty': 'maybe'}), throwsA(anything));
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
