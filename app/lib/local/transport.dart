/// How paired phones reach each other: a small HTTP server and a UDP announcement on the local
/// network (Android, desktop). Browsers can't listen for connections, so the web app has none.
library;

export 'transport_io.dart' if (dart.library.js_interop) 'transport_web.dart';

/// Answers one request from another phone (encrypted bytes in, encrypted bytes out).
typedef PeerHandler = Future<List<int>> Function(List<int> body, String remoteHost);

abstract class PeerTransport {
  /// Whether this platform can sync with other phones directly.
  bool get available;

  /// Starts answering other phones; returns the port it listens on.
  Future<int> listen(PeerHandler handler, {required int preferredPort});

  /// Sends [body] to another phone and returns its answer.
  Future<List<int>> post(String host, int port, List<int> body);

  /// This phone's addresses on the local network.
  Future<List<String>> localAddresses();

  /// Announces [message] on the local network every few seconds, and reports others'.
  Future<void> announce(String message, void Function(String message, String host) onMessage);

  Future<void> close();
}
