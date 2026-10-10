import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../l10n/l10n.dart';
import 'transport.dart';

const _path = '/nestling/v1/sync';
const _beaconPort = 47816;
const _maxBody = 64 * 1024 * 1024;

class IoTransport implements PeerTransport {
  HttpServer? _server;
  RawDatagramSocket? _udp;
  Timer? _beacon;

  @override
  bool get available => true;

  @override
  Future<int> listen(PeerHandler handler, {required int preferredPort}) async {
    if (_server != null) return _server!.port;
    HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv4, preferredPort);
    } on SocketException {
      server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    _server = server;
    server.listen((req) async {
      try {
        if (req.method != 'POST' || req.uri.path != _path) {
          req.response.statusCode = HttpStatus.notFound;
        } else {
          final body = <int>[];
          await for (final chunk in req) {
            body.addAll(chunk);
            if (body.length > _maxBody) throw const FormatException('too large');
          }
          final answer = await handler(body, req.connectionInfo?.remoteAddress.address ?? '');
          req.response.headers.contentType = ContentType.binary;
          req.response.add(answer);
        }
      } catch (_) {
        req.response.statusCode = HttpStatus.forbidden;
      }
      await req.response.close();
    });
    return server.port;
  }

  @override
  Future<List<int>> post(String host, int port, List<int> body) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5)
      ..findProxy = (_) => 'DIRECT';
    try {
      final req = await client.post(host, port, _path);
      req.headers.contentType = ContentType.binary;
      req.add(body);
      final res = await req.close().timeout(const Duration(seconds: 30));
      final bytes = <int>[];
      await for (final chunk in res.timeout(const Duration(seconds: 30))) {
        bytes.addAll(chunk);
      }
      if (res.statusCode != 200) throw HttpException(l10n.syncOtherPhoneAnswered(res.statusCode));
      return bytes;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<List<String>> localAddresses() async {
    final out = <String>[];
    for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
      for (final a in i.addresses) {
        if (!a.isLoopback && !a.isLinkLocal) out.add(a.address);
      }
    }
    // Home networks first.
    out.sort((a, b) => (a.startsWith('192.168.') ? 0 : 1).compareTo(b.startsWith('192.168.') ? 0 : 1));
    return out;
  }

  @override
  Future<void> announce(String message, void Function(String message, String host) onMessage) async {
    _beacon?.cancel();
    _udp?.close();
    try {
      final udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _beaconPort, reuseAddress: true);
      udp.broadcastEnabled = true;
      udp.listen((e) {
        if (e != RawSocketEvent.read) return;
        final d = udp.receive();
        if (d == null) return;
        try {
          onMessage(utf8.decode(d.data), d.address.address);
        } catch (_) {}
      });
      _udp = udp;
      void send() {
        try {
          udp.send(utf8.encode(message), InternetAddress('255.255.255.255'), _beaconPort);
        } catch (_) {}
      }

      send();
      _beacon = Timer.periodic(const Duration(seconds: 5), (_) => send());
    } catch (_) {
      // No broadcast here (some networks block it): remembered addresses still work.
    }
  }

  @override
  Future<void> close() async {
    _beacon?.cancel();
    _udp?.close();
    _udp = null;
    await _server?.close(force: true);
    _server = null;
  }
}

PeerTransport platformTransport() => IoTransport();
