import 'dart:convert';

import 'package:http/http.dart' as http;

/// Error returned by the server (`{"error": {"code", "message"}}`) or a network failure.
class ApiException implements Exception {
  ApiException(this.code, this.message, [this.status = 0]);
  final String code;
  final String message;
  final int status;

  bool get unauthorized => status == 401;

  @override
  String toString() => message;
}

/// Thin JSON client for the Nestling API (`<server>/api/v1`).
class Api {
  Api(this.server, [this.token]);

  /// Server root, e.g. `http://192.168.1.10:8080` (no trailing slash, no `/api/v1`).
  final String server;
  String? token;
  final http.Client _client = http.Client();

  Uri uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse('$server/api/v1$path');
    return query == null || query.isEmpty ? base : base.replace(queryParameters: query);
  }

  Map<String, String> get headers => {'content-type': 'application/json', if (token != null) 'authorization': 'Bearer $token'};

  Future<dynamic> get(String path, [Map<String, String>? query]) => _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);
  Future<dynamic> patch(String path, Object body) => _send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// POST raw bytes (e.g. a CSV file) instead of JSON.
  Future<dynamic> upload(String path, List<int> bytes, {String contentType = 'text/csv', Map<String, String>? query}) =>
      _send('POST', path, query: query, raw: bytes, contentType: contentType, timeout: const Duration(minutes: 3));

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    List<int>? raw,
    String? contentType,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final req = http.Request(method, uri(path, query))..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);
    if (raw != null) {
      req.bodyBytes = raw;
      req.headers['content-type'] = contentType ?? 'application/octet-stream';
    }
    http.Response res;
    try {
      res = await http.Response.fromStream(await _client.send(req).timeout(timeout));
    } catch (e) {
      throw ApiException('network', 'Can\'t reach the server ($server). Check the address and your connection.');
    }
    final text = utf8.decode(res.bodyBytes);
    final data = text.isEmpty ? null : _tryJson(text);
    if (res.statusCode >= 400) {
      final err = data is Map ? data['error'] : null;
      throw ApiException(
        err is Map ? '${err['code']}' : 'http_${res.statusCode}',
        err is Map ? '${err['message']}' : 'Server error (${res.statusCode})',
        res.statusCode,
      );
    }
    return data;
  }

  static dynamic _tryJson(String text) {
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }

  /// Checks that [server] answers `/health` like a Nestling server.
  static Future<bool> ping(String server) async {
    try {
      final res = await http.get(Uri.parse('$server/health')).timeout(const Duration(seconds: 8));
      return res.statusCode == 200 && res.body.contains('"ok"');
    } catch (_) {
      return false;
    }
  }
}
