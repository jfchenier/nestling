import 'dart:async';

import '../api/api.dart';
import 'domain.dart';
import 'engine.dart';
import 'merge.dart';
import 'pairing.dart';
import 'store.dart';
import 'transport.dart';

/// Serverless mode: keeps paired phones in sync over the local network.
///
/// Each phone listens on [port]; the first phone shows a pairing code (QR) with the family key
/// and its addresses, the second scans it and the two exchange snapshots ([exportFamily] /
/// [mergeFamily]). After that, phones find each other through a UDP announcement (or their last
/// known address) and sync whenever something changes, every [every] while the app is open, and
/// when they see each other again after being apart.
class PeerSync {
  PeerSync(this.store, {PeerTransport? transport, this.onMerged}) : transport = transport ?? platformTransport();

  final LocalStore store;
  final PeerTransport transport;

  /// Data from another phone arrived.
  void Function()? onMerged;

  /// Sync state changed (for the UI).
  void Function()? onStatus;

  static const port = 47815;
  static Duration every = const Duration(seconds: 30);

  Map<String, dynamic> get _cfg => store.serverless;

  bool get available => transport.available;

  String get deviceId => _cfg['device_id'] ??= LocalEngine.newId();
  String? get familyId => _cfg['family_id'];
  FamilyKey? get key => _cfg['key'] is String ? FamilyKey.fromBase64(_cfg['key']) : null;
  bool get paired => key != null && familyId != null && peers.isNotEmpty;

  /// Other phones by device id: `{name, host, port, last_sync (ms), error}`.
  Map<String, dynamic> get peers => (_cfg['peers'] ??= <String, dynamic>{}) as Map<String, dynamic>;

  int? _port;
  Timer? _periodic, _debounce;
  bool _syncing = false, _again = false;
  String? _tag;

  bool get running => _port != null;

  /// When any paired phone last synced with this one.
  DateTime? get lastSync {
    final times = peers.values.map((p) => p['last_sync']).whereType<int>();
    return times.isEmpty ? null : DateTime.fromMillisecondsSinceEpoch(times.reduce((a, b) => a > b ? a : b));
  }

  Map<String, dynamic> get _me => {'device_id': deviceId, 'name': store.me?['name'] ?? '', 'port': _port ?? port};

  /// Starts listening, announcing and syncing (no-op until the family has a key).
  Future<void> start() async {
    if (!available || key == null || familyId == null) return;
    _port ??= await transport.listen(_handle, preferredPort: port);
    _tag ??= await key!.tag();
    await transport.announce('NESTLING1 $_tag $deviceId $_port', _onAnnouncement);
    _periodic ??= Timer.periodic(every, (_) => syncAll());
    unawaited(syncAll());
  }

  Future<void> stop() async {
    _periodic?.cancel();
    _periodic = null;
    _debounce?.cancel();
    _port = null;
    await transport.close();
  }

  /// A change was made here: send it to the other phones shortly.
  void changed() {
    if (!running || peers.isEmpty) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), syncAll);
  }

  /// The code (shown as a QR) another phone scans to join [familyId].
  Future<String> pairingCode(String familyId) async {
    if (_cfg['family_id'] != familyId || key == null) {
      _cfg['family_id'] = familyId;
      _cfg['key'] = FamilyKey.generate().toBase64();
      _tag = null;
      await store.flush();
    }
    await start();
    final hosts = await transport.localAddresses();
    if (hosts.isEmpty) throw ApiException('pairing', 'Connect this phone to Wi-Fi first.');
    return PairingCode(familyId: familyId, key: key!, hosts: hosts, port: _port!, name: store.me?['name'] ?? '').toString();
  }

  /// Joins the family in [code] (scanned from the other phone) and brings its data over.
  Future<void> join(String code) async {
    final PairingCode pc;
    try {
      pc = PairingCode.parse(code);
    } on FormatException catch (e) {
      throw ApiException('pairing', e.message);
    }
    final before = Map<String, dynamic>.from(_cfg);
    _cfg['family_id'] = pc.familyId;
    _cfg['key'] = pc.key.toBase64();
    _tag = null;
    Object? lastError;
    for (final host in pc.hosts) {
      try {
        await _exchange(host, pc.port);
        lastError = null;
        break;
      } catch (e) {
        lastError = e;
      }
    }
    if (lastError != null || store.families.every((f) => f['id'] != pc.familyId)) {
      store.serverless = before;
      throw ApiException(
        'pairing',
        'Couldn\'t reach ${pc.name.isEmpty ? 'the other phone' : '${pc.name}\'s phone'}. '
        'Both phones need to be on the same Wi-Fi, with the pairing code still showing.',
      );
    }
    _addMeTo(pc.familyId);
    await start();
    await syncAll();
  }

  /// This phone's caregiver joins the family's list (synced like any change).
  void _addMeTo(String familyId) {
    final me = store.me;
    final f = store.families.firstWhere((f) => f['id'] == familyId);
    final members = (f['members'] as List? ?? []).toList();
    if (me == null || members.any((m) => m['user_id'] == me['id'])) return;
    f['members'] = [
      ...members,
      {'user_id': me['id'], 'name': me['name'], 'email': '', 'role': 'caregiver'},
    ];
    store.markChanged('f:$familyId');
  }

  Future<void>? _running;

  /// Syncs with every known phone. Called during a sync, it runs one more round afterwards and
  /// completes when that is done.
  Future<void> syncAll() {
    if (_syncing) {
      _again = true;
      return _running!;
    }
    return _running = _syncAll();
  }

  Future<void> _syncAll() async {
    _syncing = true;
    try {
      do {
        _again = false;
        for (final MapEntry(key: id, value: p) in peers.entries.toList()) {
          try {
            await _exchange(p['host'], p['port']);
            peers[id]?.remove('error');
          } catch (e) {
            peers[id]?['error'] = '$e';
          }
        }
      } while (_again);
    } finally {
      _syncing = false;
      store.save();
      onStatus?.call();
    }
  }

  Future<void> _exchange(String host, int port) async {
    final k = key!;
    final request = {'from': _me, 'snapshot': _snapshot()};
    final answer = decodeSnapshot(await k.decrypt(await transport.post(host, port, await k.encrypt(encodeSnapshot(request)))));
    _notePeer(answer['from'], host, synced: true);
    _merge(answer['snapshot']);
  }

  /// Another phone sent its snapshot: merge it and answer with ours.
  Future<List<int>> _handle(List<int> body, String remoteHost) async {
    final k = key ?? (throw StateError('not paired'));
    final request = decodeSnapshot(await k.decrypt(body));
    _notePeer(request['from'], remoteHost, synced: true);
    _merge(request['snapshot']);
    onStatus?.call();
    return k.encrypt(encodeSnapshot({'from': _me, 'snapshot': _snapshot()}));
  }

  Map<String, dynamic>? _snapshot() {
    final f = familyId;
    return f != null && store.families.any((x) => x['id'] == f) ? exportFamily(store, f) : null;
  }

  void _merge(dynamic snap) {
    if (snap is! Map<String, dynamic> || snap['family_id'] != familyId) return;
    if (mergeFamily(store, snap)) onMerged?.call();
  }

  void _notePeer(dynamic from, String host, {bool synced = false}) {
    if (from is! Map || from['device_id'] == null || from['device_id'] == deviceId || host.isEmpty) return;
    final p = (peers[from['device_id']] ??= <String, dynamic>{}) as Map<String, dynamic>;
    p['name'] = from['name'];
    p['host'] = host;
    p['port'] = from['port'] ?? port;
    if (synced) p['last_sync'] = nowMs();
  }

  void _onAnnouncement(String message, String host) {
    final parts = message.split(' ');
    if (parts.length != 4 || parts[0] != 'NESTLING1' || parts[1] != _tag || parts[2] == deviceId) return;
    final known = peers[parts[2]] as Map<String, dynamic>?;
    final port = int.tryParse(parts[3]) ?? PeerSync.port;
    final moved = known == null || known['host'] != host || known['port'] != port;
    final stale = (known?['last_sync'] as int? ?? 0) < nowMs() - 20000;
    if (known != null && (moved || stale)) {
      known['host'] = host;
      known['port'] = port;
      unawaited(syncAll());
    } else if (known == null) {
      // A family phone we haven't met (paired through a third one): introduce ourselves.
      peers[parts[2]] = {'name': '', 'host': host, 'port': port};
      unawaited(syncAll());
    }
  }
}
