import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../local/drive_backup.dart';
import 'child_form.dart';
import 'pairing.dart';

/// First run: create or join a family, then add a baby.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _familyName = TextEditingController(text: 'Our family');
  final _code = TextEditingController();
  String _tz = guessTimezone();
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    await guard(context, action);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final family = s.family;
    return Scaffold(
      appBar: AppBar(
        actions: [TextButton(onPressed: s.signOut, child: Text(s.serverless ? 'Back' : 'Sign out'))],
      ),
      body: SafeArea(
        child: Constrained(
          maxWidth: 480,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Hi ${s.me?.name ?? ''}!', style: t.headlineMedium),
              const SizedBox(height: 8),
              if (family == null) ...[
                Text(
                  s.serverless
                      ? 'Start a family to track your baby, or join the one on your partner\'s phone.'
                      : 'Start a family to track your baby, or join one with an invite code from your partner.',
                  style: t.bodyLarge?.copyWith(color: context.pal.muted),
                ),
                const SectionTitle('Start a family'),
                TextField(
                  controller: _familyName,
                  decoration: const InputDecoration(labelText: 'Family name'),
                ),
                const SizedBox(height: 12),
                TimezoneField(value: _tz, onChanged: (v) => setState(() => _tz = v)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => s.act((api) => api.post('/families', {'name': _familyName.text.trim(), 'timezone': _tz}), families: true),
                        ),
                  child: const Text('Create family'),
                ),
                if (s.serverless) ...[
                  const SectionTitle('Or join your partner\'s'),
                  Text(
                    'If another phone already tracks your baby, pair with it: everything comes over and stays in sync.',
                    style: TextStyle(color: context.pal.muted),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    onPressed: _busy ? null : () => _run(() => joinWithCode(context)),
                    label: const Text('Join with a pairing code'),
                  ),
                  if (DriveBackup.available) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.restore_rounded),
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              if (!await s.drive.restore()) throw ApiException('drive', 'No Nestling backup in this Google account.');
                              await s.load();
                            }),
                      label: const Text('Restore from Google Drive'),
                    ),
                  ],
                ] else ...[
                const SectionTitle('Or join one'),
                TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Invite code', hintText: 'K7M2QX9A'),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() => s.act((api) => api.post('/invites/${_code.text.trim().toUpperCase()}/accept'), families: true)),
                  child: const Text('Join family'),
                ),
                ],
              ] else ...[
                Text('Now add your little one to ${family.name}.', style: t.bodyLarge?.copyWith(color: context.pal.muted)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  onPressed: () => showChildForm(context, familyId: family.id),
                  label: const Text('Add a baby'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
