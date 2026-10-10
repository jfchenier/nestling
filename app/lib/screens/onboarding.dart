import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../l10n/l10n.dart';
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
  final _familyName = TextEditingController(text: l10n.onboardingOurFamily);
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
        actions: [TextButton(onPressed: s.signOut, child: Text(s.serverless ? l10n.onboardingBack : l10n.signOut))],
      ),
      body: SafeArea(
        child: Constrained(
          maxWidth: 480,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(l10n.onboardingHi(s.me?.name ?? ''), style: t.headlineMedium),
              const SizedBox(height: 8),
              if (family == null) ...[
                Text(
                  s.serverless
                      ? l10n.onboardingIntroServerless
                      : l10n.onboardingIntro,
                  style: t.bodyLarge?.copyWith(color: context.pal.muted),
                ),
                SectionTitle(l10n.onboardingStartFamily),
                TextField(
                  controller: _familyName,
                  decoration: InputDecoration(labelText: l10n.onboardingFamilyName),
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
                  child: Text(l10n.onboardingCreateFamily),
                ),
                if (s.serverless) ...[
                  SectionTitle(l10n.onboardingOrJoinPartner),
                  Text(
                    l10n.onboardingPairIntro,
                    style: TextStyle(color: context.pal.muted),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    onPressed: _busy ? null : () => _run(() => joinWithCode(context)),
                    label: Text(l10n.onboardingJoinWithCode),
                  ),
                  if (DriveBackup.available) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.restore_rounded),
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              if (!await s.drive.restore()) throw ApiException('drive', l10n.onboardingNoBackup);
                              await s.load();
                            }),
                      label: Text(l10n.onboardingRestoreDrive),
                    ),
                  ],
                ] else ...[
                SectionTitle(l10n.onboardingOrJoin),
                TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(labelText: l10n.onboardingInviteCode, hintText: 'K7M2QX9A'),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() => s.act((api) => api.post('/invites/${_code.text.trim().toUpperCase()}/accept'), families: true)),
                  child: Text(l10n.onboardingJoinFamily),
                ),
                ],
              ] else ...[
                Text(l10n.onboardingAddLittleOne(family.name), style: t.bodyLarge?.copyWith(color: context.pal.muted)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  onPressed: () => showChildForm(context, familyId: family.id),
                  label: Text(l10n.onboardingAddBaby),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
