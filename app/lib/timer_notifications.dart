import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'format.dart';
import 'models.dart';

/// Android: an ongoing notification for each running timer (breastfeed, sleep, pump) with a
/// live clock, so the timer stays visible with the app closed. On Android 16+ it is a Live
/// Update: a chip in the status bar with the timer counting, like a phone call. Android runs the
/// clock itself; the notification is posted natively (android/…/TimerNotifications.kt).
/// Kept in step with the server's timers by [sync]; elsewhere (web) it does nothing.
class TimerNotifications {
  TimerNotifications._();

  static const _channel = MethodChannel('nestling/timer_notifications');
  static bool _asked = false;

  /// Starts with every id: notifications shown before this run (by the server's messages while
  /// the app was closed) are removed on the first [sync] if their timer is gone.
  static final Set<int> _shown = {1, 2, 3};

  static bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static int _id(String kind) => switch (kind) {
    'breastfeed' => 1,
    'sleep' => 2,
    _ => 3,
  };

  /// Android 13+ asks once; the timers keep working without it.
  static Future<void> askPermission() async {
    if (!_supported || _asked) return;
    _asked = true;
    try {
      await _channel.invokeMethod('requestPermission');
    } catch (e) {
      debugPrint('timer notifications: $e');
    }
  }

  /// Show one notification per running or paused timer of [childName], remove the others.
  static Future<void> sync(List<TimerModel> timers, String? childName) async {
    if (!_supported) return;
    try {
      if (timers.isNotEmpty) await askPermission();
      final keep = <int>{};
      for (final t in timers) {
        final id = _id(t.kind);
        keep.add(id);
        final what = switch (t.kind) {
          'breastfeed' =>
            t.running ? 'Breastfeeding · ${t.side == 'right' ? 'right' : 'left'} side' : 'Breastfeed paused',
          'sleep' => t.running ? 'Sleeping' : 'Sleep paused',
          _ => t.running ? 'Pumping' : 'Pump paused',
        };
        final title = childName == null || t.kind == 'pump' ? what : '$childName · $what';
        final body = t.running
            ? 'Since ${timeOfDay(t.startedAt)} · tap to open'
            : '${duration(t.elapsed, showSeconds: true)} so far · tap to resume';
        await _channel.invokeMethod('show', {
          'id': id,
          'title': title,
          'body': body,
          'running': t.running,
          // The clock counts up from "now minus the time already on the timer".
          'startedAt': DateTime.now().millisecondsSinceEpoch - t.elapsed * 1000,
          // Status-bar chip text; null lets a running timer's chip show its clock.
          'chip': t.running ? null : 'Paused',
        });
      }
      for (final id in _shown.difference(keep)) {
        await _channel.invokeMethod('cancel', {'id': id});
      }
      _shown
        ..clear()
        ..addAll(keep);
    } catch (e) {
      debugPrint('timer notifications: $e');
    }
  }
}
