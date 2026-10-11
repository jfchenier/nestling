import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../local/server_backup.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Brings a server backup from Google Drive (see [ServerBackup]) back into [familyId], or into a
/// new family made like the one backed up. Asks which copy when there are several, and confirms
/// first. Returns false when this Google account has none.
Future<bool> restoreServerBackup(BuildContext context, {String? familyId}) async {
  final s = context.read<AppState>();
  final backup = s.serverBackup;
  final copies = await backup.copies();
  if (copies.isEmpty) return false;
  if (!context.mounted) return true;
  String when(ServerBackupCopy c) => '${DateFormat.yMMMd().format(c.savedAt)}, ${DateFormat.Hm().format(c.savedAt)}';
  final copy = copies.length == 1
      ? copies.first
      : await showDialog<ServerBackupCopy>(
          context: context,
          builder: (c) => SimpleDialog(
            title: Text(l10n.restoreWhich, style: serifStyle(22)),
            children: [
              for (final copy in copies)
                ListTile(
                  leading: const Icon(Icons.family_restroom_rounded),
                  title: Text(copy.name),
                  subtitle: Text(when(copy)),
                  onTap: () => Navigator.pop(c, copy),
                ),
            ],
          ),
        );
  if (copy == null || !context.mounted) return true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(l10n.restoreConfirmTitle, style: serifStyle(22)),
      content: Text(familyId == null ? l10n.restoreConfirmNew(when(copy), copy.name) : l10n.restoreConfirmInto(when(copy), copy.name)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l10n.restore)),
      ],
    ),
  );
  if (ok != true) return true;
  final res = await backup.restore(s.api!, copy, familyId: familyId);
  await s.load();
  final kid = s.families.where((f) => f.id == res.familyId).firstOrNull?.children.firstOrNull;
  if (kid != null && familyId == null) s.selectChild(kid.id);
  if (context.mounted) showMessage(context, l10n.restoreDone('${res.entries}', '${res.photos}'));
  return true;
}

/// Settings: bring a server backup from Google Drive back into this family.
class DriveRestoreTile extends StatefulWidget {
  const DriveRestoreTile({super.key});

  @override
  State<DriveRestoreTile> createState() => _DriveRestoreTileState();
}

class _DriveRestoreTileState extends State<DriveRestoreTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return ListTile(
      leading: const Icon(Icons.settings_backup_restore_rounded),
      title: Text(l10n.restoreFromDrive),
      subtitle: Text(ServerBackup.available ? l10n.restoreFromDriveHint : l10n.familyAndroidOnly),
      trailing: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
      enabled: ServerBackup.available && !_busy,
      onTap: () async {
        setState(() => _busy = true);
        final found = await guard(this.context, () => restoreServerBackup(this.context, familyId: s.familyId));
        if (!mounted) return;
        setState(() => _busy = false);
        if (found == false) showMessage(this.context, l10n.onboardingNoBackup);
      },
    );
  }
}
