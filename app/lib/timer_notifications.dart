import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'format.dart';
import 'models.dart';

/// Android: an ongoing notification for each running timer (breastfeed, sleep, pump) with a
/// live clock, so the timer stays visible with the app closed. Android runs the clock itself.
/// Kept in step with the server's timers by [sync]; elsewhere (web) it does nothing.
class TimerNotifications {
  TimerNotifications._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false, _asked = false;
  static final Set<int> _shown = {};

  static bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings('ic_notification')));
    _ready = true; // only once it worked, so a failure is retried on the next sync
  }

  static int _id(String kind) => switch (kind) {
    'breastfeed' => 1,
    'sleep' => 2,
    _ => 3,
  };

  /// Show one notification per running or paused timer of [childName], remove the others.
  static Future<void> sync(List<TimerModel> timers, String? childName) async {
    if (!_supported) return;
    try {
      await _init();
      if (timers.isNotEmpty && !_asked) {
        // Android 13+ asks once; the timers keep working without it.
        _asked = true;
        await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      }
      final keep = <int>{};
      for (final t in timers) {
        final id = _id(t.kind);
        keep.add(id);
        final what = switch (t.kind) {
          'breastfeed' => t.running ? 'Breastfeeding · ${t.side == 'right' ? 'right' : 'left'} side' : 'Breastfeed paused',
          'sleep' => t.running ? 'Sleeping' : 'Sleep paused',
          _ => t.running ? 'Pumping' : 'Pump paused',
        };
        final title = childName == null || t.kind == 'pump' ? what : '$childName · $what';
        final body = t.running
            ? 'Since ${timeOfDay(t.startedAt)} · tap to open'
            : '${duration(t.elapsed, showSeconds: true)} so far · tap to resume';
        await _plugin.show(
          id,
          title,
          body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'timers',
              'Running timers',
              channelDescription: 'Shows feeds, sleeps and pumping sessions while their timer runs',
              importance: Importance.low,
              priority: Priority.low,
              ongoing: true,
              autoCancel: false,
              onlyAlertOnce: true,
              silent: true,
              category: AndroidNotificationCategory.stopwatch,
              color: const Color(0xFF3D7A6A),
              // The clock counts up from "now minus the time already on the timer".
              usesChronometer: t.running,
              showWhen: t.running,
              when: t.running ? DateTime.now().millisecondsSinceEpoch - t.elapsed * 1000 : null,
            ),
          ),
        );
      }
      for (final id in _shown.difference(keep)) {
        await _plugin.cancel(id);
      }
      _shown
        ..clear()
        ..addAll(keep);
    } catch (e) {
      debugPrint('timer notifications: $e');
    }
  }
}
