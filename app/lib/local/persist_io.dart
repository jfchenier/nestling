import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'persist.dart';

/// One file per key in the app's support directory, replaced atomically.
class FilePersist implements Persist {
  FilePersist(this.dir);
  final Directory dir;

  File _file(String key) => File('${dir.path}/$key.json');

  @override
  Future<String?> read(String key) async {
    final f = _file(key);
    return await f.exists() ? f.readAsString() : null;
  }

  @override
  Future<void> write(String key, String value) async {
    await dir.create(recursive: true);
    final tmp = File('${_file(key).path}.tmp');
    await tmp.writeAsString(value, flush: true);
    await tmp.rename(_file(key).path);
  }

  @override
  Future<void> delete(String key) async {
    final f = _file(key);
    if (await f.exists()) await f.delete();
  }
}

Future<Persist> openPersist() async {
  try {
    return FilePersist(Directory('${(await getApplicationSupportDirectory()).path}/nestling'));
  } catch (_) {
    return MemoryPersist();
  }
}
