/// Where the local store is saved: a file in the app's data folder (Android, desktop) or the
/// browser's local storage (web).
library;

export 'persist_io.dart' if (dart.library.js_interop) 'persist_web.dart';

/// A tiny key-value store for whole documents.
abstract class Persist {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Keeps everything in memory (tests, or when the platform store is unavailable).
class MemoryPersist implements Persist {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> delete(String key) async => data.remove(key);
}
