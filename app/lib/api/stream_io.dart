import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Opens the family event stream. Emits the SSE event name (`ready`, `change`, `resync`)
/// for each message; the stream ends (or errors) when the connection drops.
Stream<String> familyStream(String server, String token, String familyId) {
  final client = http.Client();
  late StreamController<String> controller;
  controller = StreamController<String>(
    onListen: () async {
      try {
        final req = http.Request('GET', Uri.parse('$server/api/v1/families/$familyId/stream'))
          ..headers['authorization'] = 'Bearer $token'
          ..headers['accept'] = 'text/event-stream';
        final res = await client.send(req);
        if (res.statusCode != 200) throw StateError('stream returned ${res.statusCode}');
        var event = 'message';
        await for (final line in res.stream.transform(utf8.decoder).transform(const LineSplitter())) {
          if (line.startsWith('event:')) {
            event = line.substring(6).trim();
          } else if (line.isEmpty) {
            controller.add(event);
            event = 'message';
          }
        }
        await controller.close();
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
          await controller.close();
        }
      }
    },
    onCancel: () => client.close(),
  );
  return controller.stream;
}
