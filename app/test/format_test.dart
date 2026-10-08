import 'package:flutter_test/flutter_test.dart';
import 'package:nestling/format.dart';
import 'package:nestling/models.dart';

void main() {
  test('durations and clocks', () {
    expect(duration(45), '<1m');
    expect(duration(45, showSeconds: true), '45s');
    expect(duration(3900), '1h 05m');
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
    expect(describe(e, const Units(false)), ('Nursing', 'L 10m · R 5m · ended R'));
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
