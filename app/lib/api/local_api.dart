import 'dart:typed_data';

import '../local/engine.dart';
import 'api.dart';
import '../local/store.dart';
import 'sync_api.dart';

/// Serverless mode: the API answered entirely on this phone ([LocalEngine] with families,
/// children and photos). Paired phones are kept in sync by `PeerSync`.
class LocalApi extends SyncApi {
  LocalApi(LocalStore store) : super('', 'local', store) {
    engine.serverless = true;
  }

  /// A change was saved here (paired phones should hear about it).
  void Function()? onChanged;

  static const _needsServer = 'This needs a Nestling server. In serverless mode everything stays on your phones.';

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
    if (!LocalEngine.handles(method, path, serverless: true)) throw ApiException('server_only', _needsServer, 404);
    final res = engine.handle(method, path, query: {...?query, 'content_type': ?contentType}, body: raw ?? body);
    if (method != 'GET') onChanged?.call();
    return res;
  }

  @override
  Future<Uint8List> getBytes(String path) async {
    final m = RegExp(r'^/children/([^/]+)/photo$').firstMatch(path);
    if (m == null) throw ApiException('server_only', _needsServer, 404);
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
