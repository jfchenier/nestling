import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'api/api.dart';
import 'timer_notifications.dart';

/// Android, server mode: notifications from the server when another caregiver starts, changes or
/// stops a timer, shown even while the app is closed (Firebase Cloud Messaging, see src/push.rs
/// and android/…/Push.kt). Only when the server is set up for it (`GET /push/config`).
class PushRegistration {
  PushRegistration._();

  static const _channel = MethodChannel('nestling/push');

  static bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Registers this phone with the server (again after each start, in case its token changed).
  static Future<void> register(Api api) async {
    if (!_supported) return;
    try {
      final config = await api.get('/push/config');
      final android = config['android'];
      if (config['enabled'] != true || android is! Map) return;
      await TimerNotifications.askPermission();
      final token = await _channel.invokeMethod<String>('register', {
        'app_id': android['app_id'],
        'api_key': android['api_key'],
        'project_id': android['project_id'],
        'sender_id': android['sender_id'],
      });
      if (token != null) await api.post('/me/push-devices', {'token': token});
    } catch (e) {
      // Older server, offline, or Firebase unavailable: the app works without notifications.
      debugPrint('push: $e');
    }
  }

  /// Signed out: this phone stops getting notifications (the server forgets it with the session).
  static Future<void> unregister() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('unregister');
    } catch (e) {
      debugPrint('push: $e');
    }
  }
}
