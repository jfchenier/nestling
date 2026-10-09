import 'package:web/web.dart' as web;

import 'persist.dart';

/// The browser's local storage (a few MB; a year of entries is well under that).
class WebPersist implements Persist {
  static const _prefix = 'nestling.';

  @override
  Future<String?> read(String key) async => web.window.localStorage.getItem('$_prefix$key');

  @override
  Future<void> write(String key, String value) async => web.window.localStorage.setItem('$_prefix$key', value);

  @override
  Future<void> delete(String key) async => web.window.localStorage.removeItem('$_prefix$key');
}

Future<Persist> openPersist() async {
  try {
    web.window.localStorage.length;
    return WebPersist();
  } catch (_) {
    return MemoryPersist();
  }
}
