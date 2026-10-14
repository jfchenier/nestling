/// Serverless mode: phones that are never open at the same time, or never on the same Wi-Fi,
/// sync through folders in Google Drive (see `drive_relay.dart`). Each phone writes to a folder of
/// its own and reads the other phones' folders, listed in the family record (`drive_folders`,
/// phone id → folder id). In its folder a phone keeps one file with the family as a snapshot,
/// encrypted with the family key; the others read it when it changed and merge it like a
/// snapshot from a paired phone ([mergeFamily]).
///
/// Photos on entries (the baby book) go up once each as files of their own
/// (`photo-<event id>-<version>.bin`, encrypted too) to the folder of the phone that has them, so
/// the snapshot that is written again after every change stays small.
library;

import 'dart:convert';

import 'dart:async';

import 'domain.dart';
import 'engine.dart';
import 'gzip.dart';
import 'merge.dart';
import 'pairing.dart';
import 'store.dart';

/// A file in a phone's folder.
class RelayFile {
  RelayFile(this.id, this.name, this.version);
  final String id, name;

  /// Changes whenever the file is written (Drive's `version`).
  final String version;
}

/// A phone's folder, as the relay needs it.
abstract class RelayFolder {
  Future<List<RelayFile>> list();
  Future<List<int>> read(String fileId);

  /// Writes [name] ([fileId] when it exists already); returns its id.
  Future<String> write(String name, List<int> bytes, {String? fileId});
}

class RelaySync {
  RelaySync(this.store);
  final LocalStore store;

  Map<String, dynamic> get _cfg => (store.serverless['relay'] ??= <String, dynamic>{}) as Map<String, dynamic>;

  /// Turned on for this phone (its Google account is set up).
  bool get on => _cfg['on'] == true;
  set on(bool v) => _cfg['on'] = v;

  DateTime? get lastSync => _cfg['last'] is int ? DateTime.fromMillisecondsSinceEpoch(_cfg['last']) : null;

  /// Why the last sync failed, if it did.
  String? get error => _cfg['error'];

  String get _deviceId => (store.serverless['device_id'] ??= LocalEngine.newId()) as String;
  String get fileName => 'nestling-$_deviceId.bin';

  FamilyKey? get _key => store.serverless['key'] is String ? FamilyKey.fromBase64(store.serverless['key']) : null;
  String? get familyId => store.serverless['family_id'];

  /// This phone's folder, where it writes.
  String? get folderId => _cfg['folder'];
  set folderId(String? id) => id == null ? _cfg.remove('folder') : _cfg['folder'] = id;

  /// Turned on before phones had folders of their own (one shared folder): needs turning on again.
  bool get needsSetup => on && folderId == null;

  /// The other phones' folders, from the family record.
  List<String> get otherFolders {
    final f = store.families.where((f) => f['id'] == familyId).firstOrNull;
    final all = (f?['drive_folders'] as Map?) ?? const {};
    return [
      for (final MapEntry(:key, :value) in all.entries)
        if (key != _deviceId && value is String && value != folderId) value,
    ];
  }

  Future<bool>? _running;

  /// Reads the other phones' files that changed since last time ([open] gives a folder by id),
  /// then writes this phone's file to [mine] if anything changed here. Returns whether data from
  /// another phone arrived. A sync already running is joined, not repeated.
  Future<bool> sync(RelayFolder mine, RelayFolder Function(String folderId) open) =>
      _running ??= _sync(mine, open).whenComplete(() => _running = null);

  Future<bool> _sync(RelayFolder mine, RelayFolder Function(String folderId) open) async {
    final key = _key, fam = familyId, dir = folderId;
    if (key == null || fam == null || dir == null) return false;
    var merged = false;
    try {
      _publish(fam, dir);
      final seen = (_cfg['seen'] ??= <String, dynamic>{}) as Map<String, dynamic>;
      final files = (_cfg['files'] ??= <String, dynamic>{}) as Map<String, dynamic>;
      final ours = await mine.list();
      final listings = <(RelayFolder, List<RelayFile>)>[(mine, ours)];
      for (final f in ours) {
        if (f.name == fileName) files[dir] ??= f.id;
      }
      for (final id in otherFolders) {
        final RelayFolder folder;
        final List<RelayFile> listing;
        try {
          folder = open(id);
          listing = await folder.list();
        } catch (_) {
          continue; // a phone that removed its folder, or that Drive won't show right now
        }
        listings.add((folder, listing));
        for (final f in listing) {
          if (!f.name.startsWith('nestling-') || seen[f.id] == f.version) continue;
          final List<int> bytes;
          try {
            bytes = await folder.read(f.id);
          } catch (_) {
            continue; // removed meanwhile, or Drive refused: next time
          }
          Map<String, dynamic>? snap;
          try {
            snap = decodeSnapshot(gunzip(await key.decrypt(bytes)));
          } catch (_) {
            // Another family's key, or damaged: skip it until it changes.
          }
          if (snap != null && snap['family_id'] == fam && mergeFamily(store, snap)) merged = true;
          seen[f.id] = f.version;
        }
      }
      if (await _photos(mine, listings, key, fam)) merged = true;
      // Ours: only when something changed here (or merged in) since the last upload, or the
      // folder changed.
      final uploaded = _cfg['uploaded'] as int? ?? -1;
      if (store.stamp != uploaded || _cfg['uploaded_replica'] != store.replica || files[dir] == null) {
        final stamp = store.stamp;
        final bytes = await key.encrypt(gzip(encodeSnapshot(exportFamily(store, fam, photoData: false))));
        files[dir] = await mine.write(fileName, bytes, fileId: files[dir] as String?);
        _cfg['uploaded'] = stamp;
        _cfg['uploaded_replica'] = store.replica;
      }
      _cfg['last'] = nowMs();
      _cfg.remove('error');
    } catch (e) {
      _cfg['error'] = '$e';
      rethrow;
    } finally {
      store.save();
    }
    return merged;
  }

  /// Lists this phone's folder in the family record, so the other phones read it.
  void _publish(String fam, String dir) {
    final f = store.families.firstWhere((f) => f['id'] == fam);
    final all = Map<String, dynamic>.from((f['drive_folders'] as Map?) ?? const {});
    if (all[_deviceId] == dir) return;
    all[_deviceId] = dir;
    f['drive_folders'] = all;
    store.markChanged('f:$fam');
  }

  static String photoFileName(String eventId, int version) => 'photo-$eventId-$version.bin';

  /// Fetches the entry photos this phone knows of but hasn't got yet, and uploads to [mine] the
  /// ones it has that no folder holds. Returns whether a photo arrived.
  Future<bool> _photos(RelayFolder mine, List<(RelayFolder, List<RelayFile>)> listings, FamilyKey key, String fam) async {
    final byName = {
      for (final (folder, listing) in listings)
        for (final f in listing) f.name: (folder, f),
    };
    final kids = store.childIdsOf(fam);
    var got = false;
    for (final MapEntry(key: id, value: p) in store.eventPhotos.entries.toList()) {
      final version = p['version'];
      if (version is! int || !kids.contains(store.events[id]?['child_id'])) continue;
      final found = byName[photoFileName(id, version)];
      if (p['data'] == null) {
        if (found == null) continue; // not uploaded yet by the phone that has it
        final (folder, file) = found;
        try {
          final bytes = await key.decrypt(await folder.read(file.id));
          if (store.eventPhotos[id]?['version'] != version) continue; // changed meanwhile
          store.eventPhotos[id] = {...p, 'data': base64Encode(bytes)};
          store.eventPhotosChanged();
          got = true;
        } catch (_) {
          // Damaged or another family's: try again next time.
        }
      } else if (found == null) {
        await mine.write(photoFileName(id, version), await key.encrypt(base64Decode(p['data'] as String)));
      }
    }
    return got;
  }
}
