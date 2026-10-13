import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'photo_cache.dart';

/// One file per photo, `<name>@<version>`, in the app's support directory.
class FilePhotoCache implements PhotoCache {
  FilePhotoCache(this.dir);
  final Directory dir;

  static String _safe(String name) => name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  File _file(String name, int version) => File('${dir.path}/${_safe(name)}@$version');

  @override
  Future<Uint8List?> read(String name, int version) async {
    final f = _file(name, version);
    return await f.exists() ? f.readAsBytes() : null;
  }

  @override
  Future<void> write(String name, int version, Uint8List bytes) async {
    await dir.create(recursive: true);
    final f = _file(name, version), tmp = File('${f.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(f.path);
    await _removeOthers(name, keep: version);
  }

  @override
  Future<void> remove(String name) => _removeOthers(name);

  Future<void> _removeOthers(String name, {int? keep}) async {
    final versions = await this.versions();
    final v = versions[_safe(name)];
    if (v != null && v != keep) await _delete(_file(name, v));
  }

  static Future<void> _delete(File f) async {
    try {
      await f.delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  @override
  Future<Map<String, int>> versions() async {
    final out = <String, int>{};
    if (!await dir.exists()) return out;
    await for (final f in dir.list()) {
      final m = RegExp(r'^(.+)@(\d+)$').firstMatch(f.uri.pathSegments.last);
      if (m != null) out[m.group(1)!] = int.parse(m.group(2)!);
    }
    return out;
  }

  @override
  Future<void> clear() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

Future<PhotoCache> openPhotoCache() async {
  try {
    return FilePhotoCache(Directory('${(await getApplicationSupportDirectory()).path}/nestling/photos'));
  } catch (_) {
    return MemoryPhotoCache();
  }
}
