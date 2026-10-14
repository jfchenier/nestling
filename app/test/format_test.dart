import 'package:flutter_test/flutter_test.dart';
import 'package:nestling/format.dart';
import 'package:nestling/models.dart';

void main() {
  test('durations and clocks', () {
    expect(duration(45), '<1m');
    expect(duration(45, showSeconds: true), '45s');
    expect(duration(3900), '1h 05m');
    expect(duration(41 * 86400 + 11 * 3600 + 120), '41d 11h');
    expect(clock(65), '01:05');
    expect(clock(3725), '1:02:05');
    expect(ago(30), 'just now');
    expect(ago(3 * 86400), '3 days ago');
  });

  test('units convert both ways', () {
    const metric = Units(false), imperial = Units(true);
    expect(metric.volume(120), '120 mL');
    expect(imperial.volume(118.294), '4 oz');
    expect(imperial.weight(5850), '12 lb 14.4 oz');
    expect(metric.weight(5850), '5.85 kg');
    expect(imperial.temp(38.2), '100.8 °F');
    expect(imperial.volumeOut(4), closeTo(118.294, 0.01));
    expect(imperial.tempOut(100.4), closeTo(38, 0.01));
    expect(imperial.weightOut(imperial.weightIn(6400)), closeTo(6400, 0.001));
  });

  test('temperature unit apart from the other units', () {
    const metricF = Units(false, fahrenheit: true), imperialC = Units(true, fahrenheit: false);
    expect(metricF.temp(38.2), '100.8 °F');
    expect(metricF.volume(120), '120 mL');
    expect(imperialC.temp(38.2), '38.2 °C');
    expect(imperialC.volume(118.294), '4 oz');
    expect(metricF.tempOut(100.4), closeTo(38, 0.01));
  });

  test('12-hour and 24-hour times', () {
    final t = DateTime(2026, 10, 8, 14, 5);
    expect(timeOfDay(t), '14:05');
    expect(hhmmLabel('06:30'), '06:30');
    expect(hourMark(0), '00');
    use24h = false;
    addTearDown(() => use24h = true);
    expect(timeOfDay(t), '2:05 PM');
    expect(minutesOfDay(0), '12:00 AM');
    expect(hhmmLabel('18:00'), '6:00 PM');
    expect([hourMark(0), hourMark(9), hourMark(12), hourMark(24)], ['12a', '9a', '12p', '12a']);
  });

  test('times are sent with the local offset', () {
    final t = DateTime(2026, 10, 8, 14, 30);
    final s = formatTime(t);
    expect(s, startsWith('2026-10-08T14:30:00'));
    expect(DateTime.parse(s).toLocal(), t);
  });

  test('nursing end side and description', () {
    final e = Event({
      'id': '1',
      'child_id': 'c',
      'type': 'feed',
      'method': 'breast',
      'start': '2026-10-08T14:30:00-04:00',
      'left_seconds': 600,
      'right_seconds': 300,
      'start_side': 'left',
    });
    expect(e.endSide, 'right');
    expect(describe(e, const Units(false)), ('Breastfeed', 'L 10m · R 5m · ended R'));
    final diaper = Event({
      'id': '2',
      'child_id': 'c',
      'type': 'diaper',
      'start': '2026-10-08T14:30:00Z',
      'wet': true,
      'dirty': true,
      'color': 'yellow',
    });
    expect(describe(diaper, const Units(false)).$2, 'Wet + dirty · Yellow');
    final sized = Event({...diaper.json, 'wet_size': 'large', 'dirty_size': null});
    expect(describe(sized, const Units(false)).$2, 'Wet (large) · Dirty · Yellow');
    final potty = Event({...diaper.json, 'potty': 'success', 'dirty': false, 'color': null, 'wet_size': 'small'});
    expect(describe(potty, const Units(false)), ('Potty', 'In the potty · Wet (small)'));
  });

  test('timers tick locally from when they were received', () {
    final t = TimerModel({
      'id': 't',
      'child_id': 'c',
      'kind': 'pump',
      'running': true,
      'side': 'both',
      'elapsed_seconds': 60,
      'left_seconds': 60,
      'right_seconds': 60,
    });
    expect(t.elapsed, 60);
    expect(t.left, 60);
    expect(t.right, 60);
  });
}
