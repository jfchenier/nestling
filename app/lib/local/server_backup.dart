import 'dart:async';
import 'dart:convert';

import 'package:googleapis/drive/v3.dart' as drive;

import '../api/api.dart';
import '../l10n/l10n.dart';
import '../models.dart' show toInt;
import 'domain.dart';
import 'drive_backup.dart';
import 'store.dart';

/// Server mode: a daily copy of every family this account looks after in the caregiver's own
/// Google Drive (the app's private folder, like [DriveBackup]), in case the server is lost.
///
/// Per family: the CSV export (`server-<family>.csv`, the layout the import reads), a small JSON
/// with what the CSV leaves out (time zone, day hours, each child's medicines, reminders,
/// routines, book pages and profile picture) and the baby book's photos, one file each, sent once
/// (`server-<family>-photo-<entry>-<version>`; their full-size copies for printing as
/// `server-<family>-print-<entry>-<version>`; the book pages' photos as
/// `server-<family>-page-<child>-<key>-<version>`).
///
/// [restore] brings a copy back into a family on any server, or into serverless mode, through the
/// API: the CSV goes through the import (so restoring twice updates instead of duplicating), then
/// the children's settings and the photos are put back.
class ServerBackup implements Backup {
  ServerBackup(this.store, this.server, {this.files});
  final LocalStore store;

  /// A plain client for the server (not the app's offline copy), or null without a server.
  final Api Function()? server;

  /// Where the copies go; the app's Google Drive folder unless given (tests keep them in memory).
  final BackupFiles? files;

  static const _scopes = [drive.DriveApi.driveAppdataScope];
  static const _prefix = 'server-';

  static bool get available => DriveBackup.available;

  Map<String, dynamic> get _cfg => (store.serverless['server_drive'] ??= <String, dynamic>{}) as Map<String, dynamic>;

  @override
  String? get account => _cfg['account'];

  @override
  DateTime? get lastBackup => _cfg['last'] is int ? DateTime.fromMillisecondsSinceEpoch(_cfg['last']) : null;

  Future<BackupFiles> _drive({required bool interactive}) async {
    if (files case final f?) return f;
    final (api, email) = await DriveBackup.googleDrive(_scopes, interactive: interactive);
    _cfg['account'] = email;
    return _DriveFiles(api);
  }

  /// Saves every family this account can export. [interactive]: may ask to sign in.
  @override
  Future<void> backUp({bool interactive = true}) async {
    final d = await _drive(interactive: interactive);
    final api = server!();
    try {
      final families = ((await api.get('/families'))['families'] as List).cast<Map<String, dynamic>>();
      for (final f in families) {
        // Book viewers can't export (and only see part of the family anyway).
        if (f['role'] == 'book_viewer') continue;
        await _backUpFamily(d, api, f);
      }
    } finally {
      api.client.close();
    }
    _cfg['last'] = nowMs();
    store.save();
  }

  /// Backs up quietly once a day, once it has been set up (no sign-in prompt; skipped if needed).
  Future<void> backUpIfDue() async {
    if (!available || account == null || server == null) return;
    final last = lastBackup;
    if (last != null && DateTime.now().difference(last) < const Duration(hours: 20)) return;
    try {
      await backUp(interactive: false);
    } catch (_) {}
  }

  Future<void> _backUpFamily(BackupFiles d, Api api, Map<String, dynamic> f) async {
    final fid = f['id'] as String, base = '$_prefix$fid';
    final full = await api.get('/families/$fid/sync');
    final csv = await api.getBytes('/families/$fid/export.csv');
    final existing = await d.list(base);

    // Photos: sent once per version; the import knows entries by their source id.
    final keep = <String>{};
    final photos = <String, String>{}, prints = <String, String>{};
    for (final e in (full['events'] as List? ?? []).cast<Map<String, dynamic>>()) {
      final version = toInt(e['photo_version']);
      if (version == null || e['deleted'] == true) continue;
      final name = '$base-photo-${e['id']}-$version';
      if (!existing.containsKey(name)) await d.put(name, await api.getBytes('/events/${e['id']}/photo'), null);
      keep.add(name);
      photos[(e['source_id'] ?? e['id']) as String] = name;
      if (e['photo_print'] == true) {
        final print = '$base-print-${e['id']}-$version';
        if (!existing.containsKey(print)) await d.put(print, await api.getBytes('/events/${e['id']}/photo/print'), null);
        keep.add(print);
        prints[(e['source_id'] ?? e['id']) as String] = print;
      }
    }
    final children = <Map<String, dynamic>>[];
    for (final c in (full['children'] as List? ?? []).cast<Map<String, dynamic>>()) {
      final version = toInt(c['photo_version']);
      String? photo;
      if (version != null) {
        photo = '$base-child-${c['id']}-$version';
        if (!existing.containsKey(photo)) await d.put(photo, await api.getBytes('/children/${c['id']}/photo'), null);
        keep.add(photo);
      }
      // The book pages' photos (the family tree's faces), by key.
      final pages = <String, String>{};
      for (final MapEntry(:key, value: v) in ((c['book_photos'] as Map?) ?? const {}).entries) {
        final name = '$base-page-${c['id']}-$key-$v';
        if (!existing.containsKey(name)) await d.put(name, await api.getBytes('/children/${c['id']}/book-photos/$key'), null);
        keep.add(name);
        pages[key as String] = name;
      }
      children.add({
        for (final k in const ['id', 'name', 'birth_date', 'sex', 'medicines', 'reminders', 'routines', 'book']) k: c[k],
        'photo': photo,
        'book_photos': pages,
      });
    }

    await d.put('$base.csv', csv, existing['$base.csv'], contentType: 'text/csv');
    final manifest = {
      'v': 1,
      'saved_at': nowMs(),
      'family': {for (final k in const ['id', 'name', 'timezone', 'day_start', 'day_end']) k: f[k]},
      'children': children,
      'photos': photos,
      'prints': prints,
    };
    await d.put('$base.json', utf8.encode(jsonEncode(manifest)), existing['$base.json'], contentType: 'application/json');

    // Photos that were replaced or removed since.
    for (final MapEntry(key: name, value: id) in existing.entries) {
      if (const ['photo', 'print', 'child', 'page'].any((k) => name.startsWith('$base-$k-')) && !keep.contains(name)) {
        await d.delete(id);
      }
    }
  }

  /// The family copies in this Google account, newest first. May ask to sign in.
  Future<List<ServerBackupCopy>> copies() async {
    final d = await _drive(interactive: true);
    final found = await d.list(_prefix);
    final out = <ServerBackupCopy>[];
    for (final MapEntry(key: name, value: id) in found.entries) {
      if (!name.endsWith('.json')) continue;
      final csv = found[name.replaceFirst(RegExp(r'\.json$'), '.csv')];
      if (csv == null) continue;
      final j = jsonDecode(utf8.decode(await d.get(id)));
      if (j is Map<String, dynamic>) out.add(ServerBackupCopy._(j, csv).._files.addAll(found));
    }
    out.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return out;
  }

  /// Brings [copy] back through [api]: into family [familyId], or a new family made like the one
  /// backed up. Children are matched by name (missing ones are added); medicines, reminders,
  /// routines, book pages and profile pictures are put back where the child has none.
  Future<RestoreResult> restore(Api api, ServerBackupCopy copy, {String? familyId}) async {
    final d = await _drive(interactive: true);
    final fam = copy.family;
    if (familyId == null) {
      final created = await api.post('/families', {'name': fam['name'] ?? l10n.onboardingOurFamily, 'timezone': ?fam['timezone']});
      familyId = created['id'] as String;
      if (fam['day_start'] != null && fam['day_end'] != null) {
        await api.patch('/families/$familyId', {'day_start': fam['day_start'], 'day_end': fam['day_end']});
      }
    }
    Future<List<Map<String, dynamic>>> kids() async =>
        ((await api.get('/families/$familyId/children'))['children'] as List).cast<Map<String, dynamic>>();

    // Which child each backed-up child goes to. An empty family lets the import make them (it
    // takes the CSV's names, birth dates and book pages, even without a birth date).
    final mapping = <String, String>{};
    final present = await kids();
    if (present.isNotEmpty) {
      String norm(Object? s) => '$s'.trim().toLowerCase();
      for (final c in copy.children) {
        final same = present.where((p) => norm(p['name']) == norm(c['name'])).firstOrNull;
        mapping[c['id']] = same?['id'] ?? (await api.post('/families/$familyId/children', {
          'name': c['name'],
          'birth_date': c['birth_date'],
          'sex': ?c['sex'],
        }))['id'];
      }
    }

    final csv = await d.get(copy._csvId);
    final res = await api.upload(
      '/families/$familyId/import/nara-csv',
      csv,
      query: {if (mapping.isNotEmpty) 'children': [for (final e in mapping.entries) '${e.key}:${e.value}'].join(',')},
    );
    for (final k in (res['nara_children'] as List? ?? [])) {
      if (k['child_id'] != null) mapping[k['key']] = k['child_id'];
    }

    // Children the import didn't touch (no entries) in a family that was empty.
    var after = await kids();
    for (final c in copy.children) {
      if (mapping.containsKey(c['id'])) continue;
      final same = after.where((p) => p['name'] == c['name']).firstOrNull;
      mapping[c['id']] = same?['id'] ?? (await api.post('/families/$familyId/children', {
        'name': c['name'],
        'birth_date': c['birth_date'],
        'sex': ?c['sex'],
      }))['id'];
    }
    after = await kids();

    var photos = 0;
    for (final c in copy.children) {
      final target = after.where((p) => p['id'] == mapping[c['id']]).firstOrNull;
      if (target == null) continue;
      bool empty(Object? v) => v == null || (v is List && v.isEmpty) || (v is Map && v.isEmpty);
      final patch = {
        for (final k in const ['medicines', 'reminders', 'routines', 'book'])
          if (empty(target[k]) && !empty(c[k])) k: c[k],
      };
      if (patch.isNotEmpty) await api.patch('/children/${target['id']}', patch);
      final photo = c['photo'], file = photo == null ? null : copy._files[photo];
      if (target['photo_version'] == null && file != null) {
        final bytes = await d.get(file);
        await api.putBytes('/children/${target['id']}/photo', bytes, contentType: _imageType(bytes));
        photos++;
      }
      final had = (target['book_photos'] as Map?) ?? const {};
      for (final MapEntry(:key, value: name) in ((c['book_photos'] as Map?) ?? const {}).entries) {
        final file = copy._files[name];
        if (had.containsKey(key) || file == null) continue;
        final bytes = await d.get(file);
        await api.putBytes('/children/${target['id']}/book-photos/$key', bytes, contentType: _imageType(bytes));
        photos++;
      }
    }

    final ids = (res['ids'] as Map?)?.cast<String, String>() ?? const {};
    for (final MapEntry(key: source, value: name) in copy.photos.entries) {
      final event = ids[source], file = copy._files[name];
      if (event == null || file == null) continue;
      final bytes = await d.get(file);
      await api.putBytes('/events/$event/photo', bytes, contentType: _imageType(bytes));
      photos++;
      // Its print copy goes after it (setting the photo drops the old one).
      if (copy._files[copy.prints[source]] case final print?) {
        final full = await d.get(print);
        await api.putBytes('/events/$event/photo/print', full, contentType: _imageType(full));
      }
    }
    return RestoreResult(
      familyId: familyId,
      entries: toInt(res['imported'])! + toInt(res['updated'])!,
      photos: photos,
    );
  }

  static String _imageType(List<int> b) => b.length > 3 && b[0] == 0x89 && b[1] == 0x50
      ? 'image/png'
      : b.length > 11 && b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50
      ? 'image/webp'
      : 'image/jpeg';
}

/// One family's copy in Drive.
class ServerBackupCopy {
  ServerBackupCopy._(this.json, this._csvId);
  final Map<String, dynamic> json;
  final String _csvId;

  /// Drive file ids by name, filled in by [ServerBackup.copies].
  final Map<String, String> _files = {};

  Map<String, dynamic> get family => (json['family'] as Map?)?.cast<String, dynamic>() ?? const {};
  String get name => family['name'] ?? '';
  DateTime get savedAt => DateTime.fromMillisecondsSinceEpoch(toInt(json['saved_at']) ?? 0);
  List<Map<String, dynamic>> get children => [for (final c in (json['children'] as List? ?? [])) (c as Map).cast<String, dynamic>()];
  Map<String, String> get photos => (json['photos'] as Map?)?.cast<String, String>() ?? const {};

  /// The photos' full-size copies for printing, like [photos] (older copies have none).
  Map<String, String> get prints => (json['prints'] as Map?)?.cast<String, String>() ?? const {};
}

class RestoreResult {
  RestoreResult({required this.familyId, required this.entries, required this.photos});
  final String familyId;
  final int entries;
  final int photos;
}

/// Files kept by name, for [ServerBackup].
abstract interface class BackupFiles {
  /// Files whose name starts with [prefix]: name → id.
  Future<Map<String, String>> list(String prefix);

  /// Creates [name], or replaces file [id]'s content.
  Future<void> put(String name, List<int> bytes, String? id, {String contentType});
  Future<List<int>> get(String id);
  Future<void> delete(String id);
}

/// The app's private folder in Google Drive.
class _DriveFiles implements BackupFiles {
  _DriveFiles(this.api);
  final drive.DriveApi api;

  /// The app folder's files whose name starts with [prefix]: name → id.
  @override
  Future<Map<String, String>> list(String prefix) async {
    final out = <String, String>{};
    String? page;
    do {
      final list = await api.files.list(
        spaces: 'appDataFolder',
        q: "name contains '$prefix'",
        $fields: 'nextPageToken,files(id,name)',
        pageSize: 1000,
        pageToken: page,
      );
      for (final f in list.files ?? <drive.File>[]) {
        if (f.name != null && f.id != null && f.name!.startsWith(prefix)) out[f.name!] = f.id!;
      }
      page = list.nextPageToken;
    } while (page != null);
    return out;
  }

  @override
  Future<void> put(String name, List<int> bytes, String? id, {String contentType = 'application/octet-stream'}) async {
    final media = drive.Media(Stream.value(bytes), bytes.length, contentType: contentType);
    if (id == null) {
      await api.files.create(drive.File(name: name, parents: ['appDataFolder']), uploadMedia: media);
    } else {
      await api.files.update(drive.File(), id, uploadMedia: media);
    }
  }

  @override
  Future<List<int>> get(String id) async {
    final media = await api.files.get(id, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return bytes;
  }

  @override
  Future<void> delete(String id) => api.files.delete(id);
}
