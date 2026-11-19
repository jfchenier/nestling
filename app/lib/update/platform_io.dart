import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Android: installing a downloaded APK (android/…/AppUpdate.kt).
const _channel = MethodChannel('nestling/update');

bool get canInstall => defaultTargetPlatform == TargetPlatform.android;

/// The web app reloads itself; a phone installs instead.
const canReload = false;

void reloadPage() {}

/// Android 8+ asks the user once to let Nestling install apps ("Install unknown apps").
Future<bool> mayInstall() async => await _channel.invokeMethod<bool>('canInstall') ?? false;

/// Opens that Android setting for Nestling.
Future<void> askToInstall() => _channel.invokeMethod<void>('allowInstall');

/// Downloads APKs live here (the cache folder the installer is allowed to read, see
/// res/xml/update_paths.xml).
Future<Directory> _folder() async => Directory('${(await getTemporaryDirectory()).path}/updates').create(recursive: true);

/// Downloads [url] to the updates folder as [name] and checks it against [sha256] when the release
/// lists one. A copy already downloaded and checked is used again.
Future<String> download(
  http.Client client,
  Uri url,
  String name, {
  String? sha256,
  required void Function(double progress) onProgress,
}) async {
  final file = File('${(await _folder()).path}/${name.replaceAll(RegExp(r'[/\\]'), '_')}');
  if (sha256 != null && await file.exists() && await _sha256(file.openRead()) == sha256) return file.path;
  final res = await client.send(http.Request('GET', url));
  if (res.statusCode != 200) throw HttpException('download answered ${res.statusCode}', uri: url);
  final total = res.contentLength ?? 0;
  final part = File('${file.path}.part');
  final out = part.openWrite();
  final digest = _DigestSink();
  final hash = crypto.sha256.startChunkedConversion(digest);
  var got = 0;
  try {
    await for (final chunk in res.stream) {
      out.add(chunk);
      hash.add(chunk);
      got += chunk.length;
      onProgress(total > 0 ? got / total : -1);
    }
  } finally {
    await out.close();
    hash.close();
  }
  if (sha256 != null && '${digest.value}' != sha256) {
    await part.delete();
    throw const FormatException('the downloaded file does not match the release checksum');
  }
  return (await part.rename(file.path)).path;
}

Future<String> _sha256(Stream<List<int>> data) async => '${await crypto.sha256.bind(data).first}';

class _DigestSink implements Sink<crypto.Digest> {
  crypto.Digest? value;

  @override
  void add(crypto.Digest data) => value = data;

  @override
  void close() {}
}

/// Hands the APK to Android's installer; false when installing apps isn't allowed (yet).
Future<bool> openInstaller(String path) async => await _channel.invokeMethod<bool>('install', {'path': path}) ?? false;

/// Removes downloaded APKs other than [keep] (e.g. the one just installed).
Future<void> cleanUp({String? keep}) async {
  try {
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    if (!await dir.exists()) return;
    await for (final f in dir.list()) {
      if (keep == null || !f.path.endsWith('/$keep')) await f.delete(recursive: true);
    }
  } catch (_) {}
}
