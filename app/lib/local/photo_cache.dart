/// Where downloaded photos (the baby book's, profile pictures) are kept so they show offline, and
/// where photos taken offline wait for the server: files in the app's data folder (Android,
/// desktop) or the browser's IndexedDB (web; local storage holds a few MB at most).
library;

import 'dart:typed_data';

export 'photo_cache_io.dart' if (dart.library.js_interop) 'photo_cache_web.dart';

/// Photos by name (`e-<event id>`, `c-<child id>`), one version each.
abstract class PhotoCache {
  /// The photo [name] if the one kept is [version] (null: missing or another version).
  Future<Uint8List?> read(String name, int version);

  /// Keeps [bytes] as [name]'s photo at [version], replacing any other version.
  Future<void> write(String name, int version, Uint8List bytes);

  Future<void> remove(String name);

  /// Every photo kept: name → version.
  Future<Map<String, int>> versions();

  Future<void> clear();
}

/// Keeps photos in memory (tests, or when the platform storage is unavailable).
class MemoryPhotoCache implements PhotoCache {
  final Map<String, (int, Uint8List)> data = {};

  @override
  Future<Uint8List?> read(String name, int version) async => data[name]?.$1 == version ? data[name]!.$2 : null;

  @override
  Future<void> write(String name, int version, Uint8List bytes) async => data[name] = (version, bytes);

  @override
  Future<void> remove(String name) async => data.remove(name);

  @override
  Future<Map<String, int>> versions() async => {for (final MapEntry(:key, :value) in data.entries) key: value.$1};

  @override
  Future<void> clear() async => data.clear();
}
