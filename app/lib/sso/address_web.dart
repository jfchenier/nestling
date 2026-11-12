import 'package:web/web.dart' as web;

/// Drops `?sso_code=…` from the page's address, so a reload or a bookmark doesn't keep it.
void clearQuery() {
  final loc = web.window.location;
  web.window.history.replaceState(null, '', '${loc.pathname}${loc.hash}');
}
