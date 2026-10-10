import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/api.dart';
import '../format.dart';
import '../l10n/l10n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Serverless mode: show this phone's pairing code so another caregiver's phone can join, and
/// list the phones already paired.
class PairScreen extends StatefulWidget {
  const PairScreen({super.key});

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  String? _code, _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = context.read<AppState>();
    try {
      final code = await s.peers!.pairingCode(s.familyId!);
      if (mounted) setState(() => _code = code);
    } catch (e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = s.peers!;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pairingTitle)),
      body: Constrained(
        maxWidth: 480,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (!p.available)
              Text(l10n.pairingNeedsAndroid, style: t.bodyLarge)
            else ...[
              Text(l10n.pairingIntro, style: t.bodyLarge?.copyWith(color: context.pal.muted)),
              const SizedBox(height: 24),
              if (_error != null)
                Text(_error!, style: TextStyle(color: context.pal.danger))
              else if (_code == null)
                const Center(child: CircularProgressIndicator())
              else ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    // Dark on light in both themes: scanners read that best.
                    decoration: BoxDecoration(color: AppColors.light.surface, borderRadius: BorderRadius.circular(16)),
                    child: QrImageView(
                      data: _code!,
                      size: 240,
                      eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.light.ink),
                      dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.light.ink),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(l10n.pairingCopyCode),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _code!));
                    showMessage(context, l10n.pairingCodeCopied);
                  },
                ),
              ],
            ],
            SectionTitle(l10n.pairingPairedPhones),
            if (p.peers.isEmpty)
              Text(l10n.pairingNoneYet, style: TextStyle(color: context.pal.muted))
            else
              Card(
                child: Column(
                  children: [
                    for (final peer in p.peers.values)
                      ListTile(
                        leading: const Icon(Icons.smartphone_rounded),
                        title: Text((peer['name'] as String?)?.isNotEmpty == true ? peer['name'] : l10n.pairingPhone),
                        subtitle: Text(
                          peer['last_sync'] is int
                              ? (peer['error'] != null ? l10n.pairingUnreachable : l10n.familySyncedAgo)(
                                  ago(DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(peer['last_sync'])).inSeconds),
                                )
                              : l10n.pairingNotSynced,
                        ),
                      ),
                  ],
                ),
              ),
            if (p.peers.isNotEmpty) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(icon: const Icon(Icons.sync_rounded), label: Text(l10n.pairingSyncNow), onPressed: () => p.syncAll()),
            ],
          ],
        ),
      ),
    );
  }
}

/// Joins a family from another phone's pairing code: scan it, or paste it.
Future<void> joinWithCode(BuildContext context) async {
  final s = context.read<AppState>();
  if (!s.peers!.available) return showMessage(context, l10n.pairingNeedsAndroid);
  final scan = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => _JoinScreen(scan: scan)));
  if (code == null || !context.mounted) return;
  await guard(context, () async {
    await s.peers!.join(code);
    await s.load();
  });
}

class _JoinScreen extends StatefulWidget {
  const _JoinScreen({required this.scan});
  final bool scan;

  @override
  State<_JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<_JoinScreen> {
  final _text = TextEditingController();
  bool _done = false;

  void _found(String code) {
    if (_done || !code.startsWith('NESTLING1:')) return;
    _done = true;
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(l10n.pairingJoinTitle)),
    body: Constrained(
      maxWidth: 480,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l10n.pairingJoinIntro, style: TextStyle(color: context.pal.muted, fontSize: 15)),
          const SizedBox(height: 20),
          if (widget.scan)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 300,
                child: MobileScanner(
                  onDetect: (capture) {
                    for (final b in capture.barcodes) {
                      if (b.rawValue != null) _found(b.rawValue!);
                    }
                  },
                ),
              ),
            ),
          const SizedBox(height: 20),
          TextField(
            controller: _text,
            maxLines: 3,
            decoration: InputDecoration(labelText: l10n.pairingPasteCode, hintText: 'NESTLING1:…'),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => _found(_text.text.trim()), child: Text(l10n.familyJoinButton)),
        ],
      ),
    ),
  );
}
