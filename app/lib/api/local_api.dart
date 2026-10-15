import 'dart:typed_data';

import '../l10n/l10n.dart';
import '../local/engine.dart';
import 'api.dart';
import '../local/store.dart';
import '../models.dart' show toInt;
import 'sync_api.dart';

/// Serverless mode: the API answered entirely on this phone ([LocalEngine] with families,
/// children and photos). Paired phones are kept in sync by `PeerSync`.
class LocalApi extends SyncApi {
  LocalApi(LocalStore store) : super('', 'local', store) {
    engine.serverless = true;
  }

  /// A change was saved here (paired phones should hear about it), with the request path.
  void Function(String path)? onChanged;

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
    if (SyncApi.printPath(method, path) case final id?) return _keepPrint(id, raw ?? const []);
    // A new photo, or none: the print copy of the one before goes.
    if (SyncApi.photoPath(method, path) case final id?) await _forgetPrint(id);
    if (!LocalEngine.handles(method, path, serverless: true)) throw ApiException('server_only', l10n.localNeedsServer, 404);
    final res = engine.handle(method, path, query: {...?query, 'content_type': ?contentType}, body: raw ?? body);
    if (method != 'GET') onChanged?.call(path);
    return res;
  }

  /// The full-size copy of an entry's photo, for printing the book, stays on this phone (in
  /// [LocalStore.photoCache] as `p-<id>`, at the photo's version): it isn't sent to the other phones.
  Future<dynamic> _keepPrint(String id, List<int> bytes) async {
    final e = store.events[id];
    final version = toInt(e?['photo_version']);
    if (e == null || e['deleted'] == true || version == null) throw ApiException('not_found', 'photo not found', 404);
    await store.photoCache.write('p-$id', version, Uint8List.fromList(bytes));
    return e;
  }

  Future<void> _forgetPrint(String id) async {
    try {
      await store.photoCache.remove('p-$id');
    } catch (_) {}
  }

  @override
  Future<Uint8List> getBytes(String path) async {
    if (RegExp(r'^/events/([^/]+)/photo/print$').firstMatch(path) case final m?) {
      final version = toInt(store.events[m.group(1)!]?['photo_version']);
      final bytes = version == null ? null : await store.photoCache.read('p-${m.group(1)}', version);
      if (bytes == null) throw ApiException('not_found', 'photo not found', 404);
      return bytes;
    }
    if (RegExp(r'^/events/([^/]+)/photo$').firstMatch(path) case final m?) {
      return Uint8List.fromList(engine.eventPhotoBytes(m.group(1)!));
    }
    if (RegExp(r'^/children/([^/]+)/book-photos/([a-z0-9_]+)$').firstMatch(path) case final m?) {
      return Uint8List.fromList(engine.bookPhotoBytes(m.group(1)!, m.group(2)!));
    }
    final m = RegExp(r'^/children/([^/]+)/photo$').firstMatch(path);
    if (m == null) throw ApiException('server_only', l10n.localNeedsServer, 404);
    return Uint8List.fromList(engine.photoBytes(m.group(1)!));
  }

  /// Nothing to push or pull: there is no server.
  @override
  Future<void> sync() async {}

  @override
  Future<void> pullSoon(String? familyId) async {}

  @override
  void markOnline() {}
}
