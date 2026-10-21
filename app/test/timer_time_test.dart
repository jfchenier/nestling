import 'package:flutter_test/flutter_test.dart';
import 'package:nestling/local/engine.dart';
import 'package:nestling/local/persist.dart';
import 'package:nestling/local/store.dart';
import 'package:nestling/models.dart';

String ago(int ms) => formatTime(DateTime.now().subtract(Duration(milliseconds: ms)), millis: true);

void main() {
  test('timer times keep their milliseconds', () {
    final t = DateTime.utc(2026, 10, 8, 14, 30, 5, 250);
    expect(DateTime.parse(formatTime(t, millis: true)), t);
    expect(formatTime(t), isNot(contains('.')));
  });

  test('a timer counts from its segments, whatever copy of it is shown', () {
    // 1.6 s on the left, then 1.6 s so far on the right: 3 s in all, though each side shows 1 s.
    final json = {
      'running': true,
      'side': 'right',
      'elapsed_seconds': 0,
      'segments': [
        {'side': 'left', 'start': ago(3200), 'end': ago(1600)},
        {'side': 'right', 'start': ago(1600), 'end': null},
      ],
    };
    final t = TimerModel(json);
    expect((t.left, t.right, t.elapsed), (1, 1, 3));
    expect(t.untilNextSecond.inMilliseconds, inInclusiveRange(1, 1000));
  });

  test('pause, resume and switch take the time of the tap, like on the server', () async {
    final store = await LocalStore.open(MemoryPersist());
    store.me = {'id': LocalEngine.newId(), 'name': 'Mom', 'email': '', 'units': 'metric'};
    final a = LocalEngine(store)..serverless = true;
    final fam = a.createFamily({'name': 'Home', 'timezone': 'UTC'});
    final c = a.createChild(fam['id'], {'name': 'Léa', 'birth_date': '2026-06-01'});
    final t = a.handle('POST', '/children/${c['id']}/timers', body: {'kind': 'breastfeed', 'side': 'left', 'start': ago(60000)});
    var r = a.handle('POST', '/timers/${t['id']}/switch', body: {'side': 'right', 'at': ago(40000)});
    expect(r['left_seconds'], 20);
    r = a.handle('POST', '/timers/${t['id']}/pause', body: {'at': ago(30000)});
    expect(r['right_seconds'], 10);
    // Before the pause: resumed when it was paused. In the future: now.
    r = a.handle('POST', '/timers/${t['id']}/resume', body: {'at': ago(35000)});
    expect(r['segments'][2]['start'], r['segments'][1]['end']);
    r = a.handle('POST', '/timers/${t['id']}/pause', body: {'at': ago(-3600000)});
    expect(r['right_seconds'], inInclusiveRange(40, 41));
  });
}
