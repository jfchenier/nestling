/// Single sign-on through the server's OpenID Connect provider (e.g. Pocket ID).
///
/// The app opens the server's `/auth/sso/start` in the browser with the challenge of a verifier
/// it keeps; the server sends the browser back with a one-time `sso_code` (or `sso_error`): to
/// the web app's own page, or to the Android app through `io.github.jfchenier.nestling://sso`.
/// The app then trades the code and its verifier for a session (`AppState.finishSso`).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'address_io.dart' if (dart.library.js_interop) 'address_web.dart' as address;

class Sso {
  static const _channel = MethodChannel('nestling/sso');

  /// The Android app's link (see `MainActivity.kt` and the manifest).
  static const appLink = 'io.github.jfchenier.nestling://sso';

  /// A random secret that stays on this device until the sign-in comes back.
  static String newVerifier() {
    final r = math.Random.secure();
    return base64Url.encode(List.generate(32, (_) => r.nextInt(256))).replaceAll('=', '');
  }

  /// base64url(SHA-256(verifier)), without padding: what the server checks the verifier against.
  static Future<String> challenge(String verifier) async {
    final hash = await Sha256().hash(utf8.encode(verifier));
    return base64Url.encode(hash.bytes).replaceAll('=', '');
  }

  /// Where the server sends the browser back.
  static String returnTo() => kIsWeb ? '${Uri.base.origin}${Uri.base.path}' : appLink;

  static Uri startUrl(String server, String provider, String returnTo, String challenge) =>
      Uri.parse('$server/api/v1/auth/sso/start').replace(queryParameters: {'provider': provider, 'return_to': returnTo, 'challenge': challenge});

  /// `{sso_code}` or `{sso_error}` when the app was opened by a sign-in coming back (the web page's
  /// address, or the link that started the Android app), else null. Clears the page's address.
  static Future<Map<String, String>?> pending() async {
    Map<String, String>? params;
    if (kIsWeb) {
      params = Uri.base.queryParameters;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final link = await _channel.invokeMethod<String>('initialLink');
        params = link == null ? null : Uri.parse(link).queryParameters;
      } on MissingPluginException {
        params = null;
      }
    }
    if (params == null || !(params.containsKey('sso_code') || params.containsKey('sso_error'))) return null;
    if (kIsWeb) address.clearQuery();
    return params;
  }

  /// Sign-ins coming back while the Android app is already open.
  static void listen(void Function(Map<String, String> params) onLink) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'link' && call.arguments is String) {
        final params = Uri.parse(call.arguments as String).queryParameters;
        if (params.containsKey('sso_code') || params.containsKey('sso_error')) onLink(params);
      }
    });
  }
}
