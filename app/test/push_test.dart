import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestling/api/api.dart';
import 'package:nestling/push.dart';

/// Answers `/push/config` and records what is posted.
class FakeApi extends Api {
  FakeApi(this.config) : super('http://nestling.test', 'token');
  final Map<String, dynamic> config;
  final posted = <(String, Object?)>[];

  @override
  Future<dynamic> send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    List<int>? raw,
    String? contentType,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (method == 'GET' && path == '/push/config') return config;
    posted.add((path, body));
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    for (final name in ['nestling/push', 'nestling/timer_notifications']) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
        calls.add(call);
        return call.method == 'register' ? 'fcm-token-1' : null;
      });
    }
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('registers the phone with the server\'s Firebase settings', () async {
    final api = FakeApi({
      'enabled': true,
      'android': {'app_id': '1:42:android:ab', 'api_key': 'k', 'project_id': 'p', 'sender_id': '42'},
    });
    await PushRegistration.register(api);
    final register = calls.firstWhere((c) => c.method == 'register');
    expect((register.arguments as Map)['app_id'], '1:42:android:ab');
    expect(api.posted.single.$1, '/me/push-devices');
    expect(api.posted.single.$2, {'token': 'fcm-token-1'});
  });

  test('nothing happens when the server has no notifications', () async {
    final api = FakeApi({'enabled': false});
    await PushRegistration.register(api);
    expect(calls, isEmpty);
    expect(api.posted, isEmpty);
  });
}
