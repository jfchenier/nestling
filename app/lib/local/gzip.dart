/// Compression for snapshots sent through Google Drive (gzip on phones; the web build, which has
/// no Drive sync, passes bytes through).
library;

export 'gzip_io.dart' if (dart.library.js_interop) 'gzip_web.dart';
