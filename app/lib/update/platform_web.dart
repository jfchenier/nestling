import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

/// The web app comes from the server: nothing to install.
const canInstall = false;

const canReload = true;

/// Loads the page again, with the new app the server now serves.
void reloadPage() => web.window.location.reload();

Future<bool> mayInstall() async => false;

Future<void> askToInstall() async {}

Future<String> download(
  http.Client client,
  Uri url,
  String name, {
  String? sha256,
  required void Function(double progress) onProgress,
}) => throw UnsupportedError('no APK on the web');

Future<bool> openInstaller(String path) async => false;

Future<void> cleanUp({String? keep}) async {}
