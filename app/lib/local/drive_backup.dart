import 'dart:async';
import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import 'domain.dart';
import 'merge.dart';
import 'store.dart';

/// Serverless mode: a copy of the family's data in the caregiver's own Google Drive, in the
/// app's private folder there (not visible in Drive, only this app can read it). Restoring merges
/// it into the phone like a sync from another phone, so nothing newer is lost.
///
/// Needs a Google Cloud OAuth client for the Android app; its web client id is passed at build
/// time with `--dart-define=GOOGLE_SERVER_CLIENT_ID=…` (see app/README.md).
class DriveBackup {
  DriveBackup(this.store);
  final LocalStore store;

  static const _clientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  static const _scopes = [drive.DriveApi.driveAppdataScope];
  static const _fileName = 'nestling-backup.json';

  /// Only in Android builds made with a Google client id.
  static bool get available => !kIsWeb && defaultTargetPlatform == TargetPlatform.android && _clientId.isNotEmpty;

  static Future<void>? _init;

  Map<String, dynamic> get _cfg => (store.serverless['drive'] ??= <String, dynamic>{}) as Map<String, dynamic>;

  /// The Google account backups go to, once set up.
  String? get account => _cfg['account'];
  DateTime? get lastBackup => _cfg['last'] is int ? DateTime.fromMillisecondsSinceEpoch(_cfg['last']) : null;

  Future<drive.DriveApi> _api({required bool interactive}) async {
    final (api, email) = await googleDrive(_scopes, interactive: interactive);
    _cfg['account'] = email;
    return api;
  }

  /// Drive with [scopes] for the signed-in Google account. [interactive]: may ask the user to
  /// sign in or to allow access; otherwise fails if that would be needed.
  static Future<(drive.DriveApi, String)> googleDrive(List<String> scopes, {required bool interactive}) async {
    if (!available) throw UnsupportedError('Google Drive needs the Android app.');
    await (_init ??= GoogleSignIn.instance.initialize(serverClientId: _clientId));
    GoogleSignInAccount? user = await GoogleSignIn.instance.attemptLightweightAuthentication();
    if (user == null && interactive) user = await GoogleSignIn.instance.authenticate(scopeHint: scopes);
    if (user == null) throw StateError('Not signed in to Google.');
    var auth = await user.authorizationClient.authorizationForScopes(scopes);
    if (auth == null && interactive) auth = await user.authorizationClient.authorizeScopes(scopes);
    if (auth == null) throw StateError('Google Drive access wasn\'t granted.');
    return (drive.DriveApi(auth.authClient(scopes: scopes)), user.email);
  }

  Future<String?> _fileId(drive.DriveApi api) async {
    final list = await api.files.list(spaces: 'appDataFolder', q: "name = '$_fileName'", $fields: 'files(id)');
    return list.files?.firstOrNull?.id;
  }

  /// Saves every family on this phone to Drive. [interactive]: may ask to sign in.
  Future<void> backUp({bool interactive = true}) async {
    final api = await _api(interactive: interactive);
    final bytes = utf8.encode(
      jsonEncode({
        'v': 1,
        'saved_at': nowMs(),
        'me': store.me,
        'serverless': {'family_id': store.serverless['family_id'], 'key': store.serverless['key']},
        'families': [for (final f in store.families) exportFamily(store, f['id'])],
      }),
    );
    final media = drive.Media(Stream.value(bytes), bytes.length, contentType: 'application/json');
    final id = await _fileId(api);
    if (id == null) {
      await api.files.create(drive.File(name: _fileName, parents: ['appDataFolder']), uploadMedia: media);
    } else {
      await api.files.update(drive.File(), id, uploadMedia: media);
    }
    _cfg['last'] = nowMs();
    store.save();
  }

  /// Backs up quietly once a day (no sign-in prompt; skipped if that's needed).
  Future<void> backUpIfDue() async {
    if (!available || account == null) return;
    final last = lastBackup;
    if (last != null && DateTime.now().difference(last) < const Duration(hours: 20)) return;
    try {
      await backUp(interactive: false);
    } catch (_) {}
  }

  /// Brings the Drive copy into this phone. Returns false if there is none.
  Future<bool> restore() async {
    final api = await _api(interactive: true);
    final id = await _fileId(api);
    if (id == null) return false;
    final media = await api.files.get(id, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    // A new phone takes over the caregiver it was before (same name, same entries).
    if (store.families.isEmpty && j['me'] is Map) store.me = Map<String, dynamic>.from(j['me']);
    final cfg = j['serverless'];
    if (cfg is Map && store.serverless['key'] == null) {
      store.serverless['family_id'] = cfg['family_id'];
      store.serverless['key'] = cfg['key'];
    }
    for (final f in (j['families'] as List? ?? [])) {
      mergeFamily(store, f);
    }
    _cfg['last'] = nowMs();
    await store.flush();
    return true;
  }
}
