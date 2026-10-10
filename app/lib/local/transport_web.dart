import '../l10n/l10n.dart';
import 'transport.dart';

/// Browsers can't accept connections or announce themselves on the network.
class WebTransport implements PeerTransport {
  @override
  bool get available => false;

  Never _no() => throw UnsupportedError(l10n.syncPhonesNeedAndroid);

  @override
  Future<int> listen(PeerHandler handler, {required int preferredPort}) async => _no();

  @override
  Future<List<int>> post(String host, int port, List<int> body) async => _no();

  @override
  Future<List<String>> localAddresses() async => const [];

  @override
  Future<void> announce(String message, void Function(String message, String host) onMessage) async {}

  @override
  Future<void> close() async {}
}

PeerTransport platformTransport() => WebTransport();
