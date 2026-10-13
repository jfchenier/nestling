import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'idb.dart';
import 'photo_cache.dart';

/// Photos in the browser's IndexedDB: the bytes in `photos`, their versions apart in `versions`
/// (so listing them doesn't read every photo).
class IdbPhotoCache implements PhotoCache {
  IdbPhotoCache(this._db);
  final web.IDBDatabase _db;

  web.IDBTransaction _tx(String mode) => _db.transaction([photoStore.toJS, versionStore.toJS].toJS, mode);

  @override
  Future<Uint8List?> read(String name, int version) async {
    final tx = _tx('readonly');
    final v = await idbResult(tx.objectStore(versionStore).get(name.toJS));
    if (v == null || (v as JSNumber).toDartInt != version) return null;
    final bytes = await idbResult(tx.objectStore(photoStore).get(name.toJS));
    return bytes == null ? null : (bytes as JSUint8Array).toDart;
  }

  @override
  Future<void> write(String name, int version, Uint8List bytes) async {
    final tx = _tx('readwrite');
    tx.objectStore(photoStore).put(bytes.toJS, name.toJS);
    tx.objectStore(versionStore).put(version.toJS, name.toJS);
    await idbDone(tx);
  }

  @override
  Future<void> remove(String name) async {
    final tx = _tx('readwrite');
    tx.objectStore(photoStore).delete(name.toJS);
    tx.objectStore(versionStore).delete(name.toJS);
    await idbDone(tx);
  }

  @override
  Future<Map<String, int>> versions() async {
    final tx = _tx('readonly');
    final store = tx.objectStore(versionStore);
    final keys = (await idbResult(store.getAllKeys()) as JSArray).toDart;
    final values = (await idbResult(store.getAll()) as JSArray).toDart;
    return {for (var i = 0; i < keys.length; i++) (keys[i] as JSString).toDart: (values[i] as JSNumber).toDartInt};
  }

  @override
  Future<void> clear() async {
    final tx = _tx('readwrite');
    tx.objectStore(photoStore).clear();
    tx.objectStore(versionStore).clear();
    await idbDone(tx);
  }
}

Future<PhotoCache> openPhotoCache() async {
  try {
    return IdbPhotoCache(await openIdb());
  } catch (_) {
    return MemoryPhotoCache();
  }
}
