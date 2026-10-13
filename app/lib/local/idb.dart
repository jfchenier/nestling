/// The app's IndexedDB database in the browser: `photos` (name → bytes), `versions` (name →
/// photo version) and `docs` (large documents of the local store).
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

const photoStore = 'photos', versionStore = 'versions', docStore = 'docs';

Future<web.IDBDatabase>? _db;

/// Opens the database once (throws where IndexedDB is unavailable, e.g. some private windows).
Future<web.IDBDatabase> openIdb() async {
  final db = _db ??= _open();
  try {
    return await db;
  } catch (_) {
    _db = null;
    rethrow;
  }
}

Future<web.IDBDatabase> _open() {
  final c = Completer<web.IDBDatabase>();
  final req = web.window.indexedDB.open('nestling', 1);
  req.onupgradeneeded = ((web.Event _) {
    final db = req.result as web.IDBDatabase;
    for (final name in [photoStore, versionStore, docStore]) {
      if (!db.objectStoreNames.contains(name)) db.createObjectStore(name);
    }
  }).toJS;
  req.onsuccess = ((web.Event _) => c.complete(req.result as web.IDBDatabase)).toJS;
  req.onerror = ((web.Event _) => c.completeError(StateError('IndexedDB: ${req.error?.message}'))).toJS;
  return c.future;
}

/// A request's result.
Future<JSAny?> idbResult(web.IDBRequest req) {
  final c = Completer<JSAny?>();
  req.onsuccess = ((web.Event _) => c.complete(req.result)).toJS;
  req.onerror = ((web.Event _) => c.completeError(StateError('IndexedDB: ${req.error?.message}'))).toJS;
  return c.future;
}

/// Waits for a write transaction to be stored.
Future<void> idbDone(web.IDBTransaction tx) {
  final c = Completer<void>();
  tx.oncomplete = ((web.Event _) => c.complete()).toJS;
  tx.onerror = ((web.Event _) => c.isCompleted ? null : c.completeError(StateError('IndexedDB: ${tx.error?.message}'))).toJS;
  tx.onabort = ((web.Event _) => c.isCompleted ? null : c.completeError(StateError('IndexedDB: ${tx.error?.message}'))).toJS;
  return c.future;
}
