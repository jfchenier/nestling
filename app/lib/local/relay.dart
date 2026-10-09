/// Serverless mode: phones that are never open at the same time, or never on the same Wi-Fi,
/// sync through a shared folder (Google Drive, see `drive_relay.dart`). Each phone keeps one file
/// there with the family as a snapshot, encrypted with the family key; the others read it when it
/// changed and merge it like a snapshot from a paired phone ([mergeFamily]).
library;

import 'dart:async';

import 'domain.dart';
import 'engine.dart';
import 'gzip.dart';
import 'merge.dart';
import 'pairing.dart';
import 'store.dart';

/// A file in the shared folder.
class RelayFile {
  RelayFile(this.id, this.name, this.version);
  final String id, name;

  /// Changes whenever the file is written (Drive's `version`).
  final String version;
}

/// The shared folder, as the relay needs it.
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

  /// The family's shared folder (kept in the family record, so paired phones learn it).
  String? get folderId {
    final f = store.families.where((f) => f['id'] == familyId).firstOrNull;
    return f?['drive_folder'] as String?;
  }

  Future<bool>? _running;

  /// Reads the other phones' files that changed since last time, then writes this phone's file if
  /// anything changed here. Returns whether data from another phone arrived. A sync already
  /// running is joined, not repeated.
  Future<bool> sync(RelayFolder folder) => _running ??= _sync(folder).whenComplete(() => _running = null);

  Future<bool> _sync(RelayFolder folder) async {
    final key = _key, fam = familyId, dir = folderId;
    if (key == null || fam == null || dir == null) return false;
    var merged = false;
    try {
      final seen = (_cfg['seen'] ??= <String, dynamic>{}) as Map<String, dynamic>;
      final files = (_cfg['files'] ??= <String, dynamic>{}) as Map<String, dynamic>;
      for (final f in await folder.list()) {
        if (f.name == fileName) {
          files[dir] ??= f.id;
          continue;
        }
        if (!f.name.startsWith('nestling-') || seen[f.id] == f.version) continue;
        final bytes = await folder.read(f.id);
        Map<String, dynamic>? snap;
        try {
          snap = decodeSnapshot(gunzip(await key.decrypt(bytes)));
        } catch (_) {
          // Another family's key, or damaged: skip it until it changes.
        }
        if (snap != null && snap['family_id'] == fam && mergeFamily(store, snap)) merged = true;
        seen[f.id] = f.version;
      }
      // Ours: only when something changed here (or merged in) since the last upload, or the
      // folder changed.
      final uploaded = _cfg['uploaded'] as int? ?? -1;
      if (store.stamp != uploaded || _cfg['uploaded_replica'] != store.replica || files[dir] == null) {
        final stamp = store.stamp;
        final bytes = await key.encrypt(gzip(encodeSnapshot(exportFamily(store, fam))));
        files[dir] = await folder.write(fileName, bytes, fileId: files[dir] as String?);
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
}
