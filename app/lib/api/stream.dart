/// Server-Sent Events from `/families/{id}/stream`.
///
/// The browser `http` client buffers whole responses, so the web build uses `EventSource`
/// (token in the query string) and other platforms read a streamed HTTP response.
library;

export 'stream_io.dart' if (dart.library.js_interop) 'stream_web.dart';
