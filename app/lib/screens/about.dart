import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/l10n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// The app's version: set at build time (`--dart-define=NESTLING_VERSION=…`; release.yml and the
/// Docker image do), empty for a local build.
const appVersion = String.fromEnvironment('NESTLING_VERSION');

String appVersionLabel() => appVersion.isEmpty ? l10n.aboutDevBuild : appVersion;

const sourceCodeUrl = 'https://github.com/jfchenier/nestling';

/// Settings → About: name, versions (app and server), source code, license, open-source licenses.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  Future<Map<String, dynamic>?>? _server;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    if (!s.serverless) _server = AppState.setupStatus(s.server);
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            const SizedBox(height: 8),
            Center(child: Image.asset('assets/icon.png', width: 96, height: 96)),
            const SizedBox(height: 14),
            Text('Nestling', textAlign: TextAlign.center, style: serifStyle(28)),
            const SizedBox(height: 6),
            Text(l10n.aboutTagline, textAlign: TextAlign.center, style: TextStyle(color: pal.muted)),
            const SizedBox(height: 24),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.smartphone_rounded),
                    title: Text(l10n.aboutAppVersion),
                    subtitle: Text(appVersionLabel()),
                  ),
                  if (_server != null)
                    FutureBuilder<Map<String, dynamic>?>(
                      future: _server,
                      builder: (context, snap) => ListTile(
                        leading: const Icon(Icons.dns_outlined),
                        title: Text(l10n.aboutServerVersion),
                        subtitle: Text(switch (snap) {
                          AsyncSnapshot(connectionState: ConnectionState.waiting) => '…',
                          AsyncSnapshot(data: {'version': final String v}) => v,
                          _ => l10n.aboutUnavailable,
                        }),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.code_rounded),
                    title: Text(l10n.aboutSourceCode),
                    subtitle: const Text('github.com/jfchenier/nestling'),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: () => launchUrl(Uri.parse(sourceCodeUrl), mode: LaunchMode.externalApplication),
                  ),
                  ListTile(
                    leading: const Icon(Icons.gavel_rounded),
                    title: Text(l10n.aboutLicense),
                    subtitle: Text(l10n.aboutLicenseValue),
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(l10n.aboutOpenSource),
                    subtitle: Text(l10n.aboutOpenSourceHint),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'Nestling',
                      applicationVersion: appVersionLabel(),
                      applicationIcon: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Image.asset('assets/icon.png', width: 64, height: 64),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
