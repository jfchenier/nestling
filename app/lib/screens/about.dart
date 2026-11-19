import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/l10n.dart';
import '../format.dart';
import '../state.dart';
import '../theme.dart';
import '../update/update.dart';
import '../widgets/common.dart';

export '../update/update.dart' show appVersion;

String appVersionLabel() => appVersion.isEmpty ? l10n.aboutDevBuild : appVersion;

const sourceCodeUrl = 'https://github.com/jfchenier/nestling';

/// Settings → About: name, versions (app and server), updates (Android), source code, license,
/// open-source licenses.
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
            if (context.watch<AppState>().updates case final u when u.supported) ...[
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.update_rounded),
                      title: Text(l10n.updateCheckTitle),
                      subtitle: Text(l10n.updateCheckHint),
                      value: u.enabled,
                      onChanged: u.setEnabled,
                    ),
                    ListTile(
                      leading: const Icon(Icons.system_update_rounded),
                      title: Text(u.available == null ? l10n.updateCheckNow : l10n.updateAvailable(u.available!.version)),
                      subtitle: Text(switch (u) {
                        _ when u.checking => l10n.updateChecking,
                        _ when u.progress != null => l10n.updateDownloading,
                        _ when u.needsPermission => l10n.updatePermission,
                        _ when u.error != null => l10n.updateFailed,
                        _ when u.available != null => l10n.updateAvailableHint,
                        _ when u.latest != null => l10n.updateUpToDate,
                        _ => switch (u.lastCheck) {
                          final at? => l10n.updateLastChecked(ago(DateTime.now().difference(at).inSeconds)),
                          null => l10n.updateNeverChecked,
                        },
                      }),
                      trailing: u.checking || u.progress != null
                          ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : (u.available == null ? null : FilledButton.tonal(onPressed: u.install, child: Text(l10n.updateInstall))),
                      onTap: u.checking || u.progress != null ? null : (u.available == null ? () => u.check(force: true) : u.install),
                    ),
                  ],
                ),
              ),
            ],
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
