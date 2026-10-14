import 'dart:async';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' show clientViaApiKey;

import '../api/api.dart';
import '../l10n/l10n.dart';
import 'drive_backup.dart';
import 'pairing.dart';
import 'relay.dart';
import 'store.dart';

/// The relay's folders in Google Drive: each phone that turns it on makes a folder
/// "Nestling – family name" in its own Drive and writes there; the folder is shared by link for
/// reading (its files are encrypted with the family key, so only the family can read them). The
/// folder ids travel to the other phones in the family record (`drive_folders`), so each phone
/// reads the others' folders.
///
/// Access is Google's per-app Drive permission (`drive.file`): the app reaches only the files it
/// made itself, so it writes to this account's folder with the signed-in account and reads the
/// other accounts' folders by link with an API key (`--dart-define=GOOGLE_API_KEY`, see
/// app/README.md). Neither needs Google's restricted full-Drive permission.
class DriveRelay {
  DriveRelay(this.store) : sync = RelaySync(store);
  final LocalStore store;
  final RelaySync sync;

  static const _scopes = [drive.DriveApi.driveFileScope];
  static const _apiKey = String.fromEnvironment('GOOGLE_API_KEY');
  static const _folderType = 'application/vnd.google-apps.folder';

  static bool get available => DriveBackup.available && _apiKey.isNotEmpty;

  /// Reads folders shared by link, without signing in.
  static final _byLink = drive.DriveApi(clientViaApiKey(_apiKey));

  bool get on => available && sync.on;
  String? get account => (store.serverless['relay'] as Map?)?['account'];

  Future<drive.DriveApi> _api({required bool interactive}) async {
    final (api, email) = await DriveBackup.googleDrive(_scopes, interactive: interactive);
    (store.serverless['relay'] ??= <String, dynamic>{})['account'] = email;
    return api;
  }

  /// Turns Drive sync on for [familyId] (may ask to sign in), creating this phone's folder if it
  /// has none it can reach, then syncs. Returns whether data arrived.
  Future<bool> enable(String familyId) async {
    final api = await _api(interactive: true);
    final f = store.families.firstWhere((f) => f['id'] == familyId);
    // The family key encrypts the files; pairing later hands the same key to the other phones.
    if (store.serverless['family_id'] != familyId || store.serverless['key'] == null) {
      store.serverless['family_id'] = familyId;
      store.serverless['key'] = FamilyKey.generate().toBase64();
    }
    final existing = sync.folderId;
    if (existing == null || !await _reachable(api, existing)) {
      final folder = await api.files.create(
        drive.File(name: 'Nestling – ${f['name']}', mimeType: _folderType),
        $fields: 'id',
      );
      await api.permissions.create(drive.Permission(type: 'anyone', role: 'reader'), folder.id!);
      sync.folderId = folder.id;
    }
    sync.on = true;
    await store.flush();
    return sync.sync(_DriveFolder(api, sync.folderId!), _readByLink);
  }

  Future<void> disable() async {
    sync.on = false;
    await store.flush();
  }

  static RelayFolder _readByLink(String id) => _DriveFolder(_byLink, id);

  Future<bool> _reachable(drive.DriveApi api, String id) async {
    try {
      final f = await api.files.get(id, $fields: 'id,trashed') as drive.File;
      return f.trashed != true;
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 404 || e.status == 403) return false;
      rethrow;
    }
  }

  /// Syncs quietly (no sign-in prompt). Returns whether data from another phone arrived.
  Future<bool> run() async {
    if (!on) return false;
    if (sync.needsSetup) throw ApiException('drive', l10n.syncDriveFolderUnreachable);
    final api = await _api(interactive: false);
    try {
      return await sync.sync(_DriveFolder(api, sync.folderId!), _readByLink);
    } on drive.DetailedApiRequestError catch (e) {
      if (e.status == 404) sync.folderId = null; // removed from Drive: turning sync on again makes a new one
      if (e.status == 404 || e.status == 403) {
        throw ApiException('drive', l10n.syncDriveFolderUnreachable);
      }
      rethrow;
    }
  }
}

class _DriveFolder implements RelayFolder {
  _DriveFolder(this.api, this.id);
  final drive.DriveApi api;
  final String id;

  @override
  Future<List<RelayFile>> list() async {
    final out = <RelayFile>[];
    String? page;
    do {
      final res = await api.files.list(
        q: "'$id' in parents and trashed = false",
        $fields: 'nextPageToken,files(id,name,version)',
        pageToken: page,
        spaces: 'drive',
        supportsAllDrives: true,
        includeItemsFromAllDrives: true,
      );
      for (final f in res.files ?? <drive.File>[]) {
        out.add(RelayFile(f.id!, f.name ?? '', f.version ?? ''));
      }
      page = res.nextPageToken;
    } while (page != null);
    return out;
  }

  @override
  Future<List<int>> read(String fileId) async {
    final media = await api.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia, supportsAllDrives: true) as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return bytes;
  }

  @override
  Future<String> write(String name, List<int> bytes, {String? fileId}) async {
    final media = drive.Media(Stream.value(bytes), bytes.length, contentType: 'application/octet-stream');
    if (fileId != null) {
      try {
        await api.files.update(drive.File(), fileId, uploadMedia: media, supportsAllDrives: true);
        return fileId;
      } on drive.DetailedApiRequestError catch (e) {
        if (e.status != 404) rethrow; // deleted in Drive: write it again
      }
    }
    final again = drive.Media(Stream.value(bytes), bytes.length, contentType: 'application/octet-stream');
    final f = await api.files.create(
      drive.File(name: name, parents: [id]),
      uploadMedia: again,
      $fields: 'id',
      supportsAllDrives: true,
    );
    return f.id!;
  }
}
