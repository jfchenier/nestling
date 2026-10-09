import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestling/models.dart';
import 'package:nestling/timer_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('nestling/timer_notifications');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('running timer: chip shows the clock, started at now minus elapsed', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await TimerNotifications.sync([
      TimerModel({'kind': 'sleep', 'running': true, 'elapsed_seconds': 600, 'started_at': '2026-10-09T10:00:00Z'}),
    ], 'Léa');
    expect(calls.map((c) => c.method), ['requestPermission', 'show']);
    final args = calls.last.arguments as Map;
    expect(args['id'], 2);
    expect(args['title'], 'Léa · Sleeping');
    expect(args['running'], true);
    expect(args['chip'], isNull);
    expect((args['startedAt'] as int) - (now - 600 * 1000), lessThan(2000));
  });

  test('paused timer says so on the chip; stopped timers are cancelled', () async {
    await TimerNotifications.sync([
      TimerModel({'kind': 'pump', 'running': false, 'elapsed_seconds': 90}),
    ], 'Léa');
    // The sleep timer from the previous test has stopped.
    expect(calls.map((c) => '${c.method} ${(c.arguments as Map)['id']}'), ['show 3', 'cancel 2']);
    final args = calls.first.arguments as Map;
    expect(args['title'], 'Pump paused');
    expect(args['chip'], 'Paused');

    calls.clear();
    await TimerNotifications.sync(const [], 'Léa');
    expect(calls.map((c) => '${c.method} ${(c.arguments as Map)['id']}').toList(), ['cancel 3']);
  });
}
