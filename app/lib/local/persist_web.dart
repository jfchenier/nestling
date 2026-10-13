import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'idb.dart';
import 'persist.dart';

/// The browser's local storage (a few MB; a year of entries is well under that). The baby book's
/// photos (serverless mode) go to IndexedDB, which holds far more, when the browser has it.
class WebPersist implements Persist {
  WebPersist([this._db]);
  static const _prefix = 'nestling.';

  /// Documents too large for local storage.
  static const _large = {'event_photos', 'book_photos'};
  final web.IDBDatabase? _db;

  web.IDBObjectStore? _docs(String key, String mode) =>
      _large.contains(key) ? _db?.transaction(docStore.toJS, mode).objectStore(docStore) : null;

  @override
  Future<String?> read(String key) async {
    if (_docs(key, 'readonly') case final docs?) return (await idbResult(docs.get(key.toJS)) as JSString?)?.toDart;
    return web.window.localStorage.getItem('$_prefix$key');
  }

  @override
  Future<void> write(String key, String value) async {
    if (_docs(key, 'readwrite') case final docs?) {
      docs.put(value.toJS, key.toJS);
      return idbDone(docs.transaction);
    }
    web.window.localStorage.setItem('$_prefix$key', value);
  }

  @override
  Future<void> delete(String key) async {
    if (_docs(key, 'readwrite') case final docs?) {
      docs.delete(key.toJS);
      return idbDone(docs.transaction);
    }
    web.window.localStorage.removeItem('$_prefix$key');
  }
}

Future<Persist> openPersist() async {
  try {
    web.window.localStorage.length;
  } catch (_) {
    return MemoryPersist();
  }
  try {
    return WebPersist(await openIdb());
  } catch (_) {
    return WebPersist();
  }
}
