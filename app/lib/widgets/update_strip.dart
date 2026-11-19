import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../state.dart';
import '../theme.dart';

/// Home: a newer Nestling is out. Android: Update downloads and installs it (Not now hides this
/// version); web: the server was updated, Reload loads the new app. See lib/update/update.dart.
class UpdateStrip extends StatelessWidget {
  const UpdateStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final u = context.watch<AppState>().updates;
    final pal = context.pal;
    final release = u.available;
    final String title, status;
    final Widget? action;
    VoidCallback? later;
    if (release != null) {
      title = l10n.updateAvailable(release.version);
      final p = u.progress;
      status = switch (u) {
        _ when p != null => p < 0 ? l10n.updateDownloading : l10n.updateDownloadingPercent((p * 100).round()),
        _ when u.needsPermission => l10n.updatePermission,
        _ when u.error != null => l10n.updateFailed,
        _ => l10n.updateAvailableHint,
      };
      action = p != null
          ? SizedBox.square(dimension: 28, child: CircularProgressIndicator(value: p < 0 ? null : p, strokeWidth: 3))
          : FilledButton.tonal(onPressed: u.install, child: Text(l10n.updateInstall));
      if (p == null) later = u.dismiss;
    } else if (u.reloadOffered) {
      title = l10n.updateWebReady;
      status = l10n.updateWebReadyHint;
      action = FilledButton.tonal(onPressed: u.reload, child: Text(l10n.updateReload));
    } else {
      return const SizedBox.shrink();
    }
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: pal.surface,
        shape: shape.copyWith(side: BorderSide(color: pal.line)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              shape: shape,
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: pal.accentSoft, shape: BoxShape.circle),
                child: Icon(Icons.system_update_rounded, size: 20, color: pal.accent),
              ),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(status, style: TextStyle(color: pal.muted)),
              trailing: action,
            ),
            if (later != null)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 4),
                  child: TextButton(onPressed: later, child: Text(l10n.updateLater)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
