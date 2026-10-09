import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Opens the family event stream with the browser's EventSource. Emits the SSE event name
/// (`ready`, `change`, `resync`, `ping`); errors and closes when the connection drops.
Stream<String> familyStream(String server, String token, String familyId) {
  web.EventSource? source;
  late StreamController<String> controller;
  controller = StreamController<String>(
    onListen: () {
      final url = '$server/api/v1/families/$familyId/stream?access_token=${Uri.encodeQueryComponent(token)}';
      final es = web.EventSource(url);
      source = es;
      for (final name in ['ready', 'change', 'resync', 'ping']) {
        es.addEventListener(name, ((web.Event _) => controller.add(name)).toJS);
      }
      es.onerror = ((web.Event _) {
        es.close();
        if (!controller.isClosed) {
          controller.addError(StateError('stream disconnected'));
          controller.close();
        }
      }).toJS;
    },
    onCancel: () => source?.close(),
  );
  return controller.stream;
}
