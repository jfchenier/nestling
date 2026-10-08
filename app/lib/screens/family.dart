import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'child_form.dart';
import 'home.dart' show ChildAvatar;

/// Family, caregivers, babies, settings and Nara import.
class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final f = s.family!;
    final me = s.me!;
    return Scaffold(
      appBar: AppBar(title: const Text('Family')),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          children: [
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Palette.raised,
                  child: Icon(Icons.home_rounded, color: Palette.accentLight),
                ),
                title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${f.members.length} caregiver${f.members.length == 1 ? '' : 's'} · ${f.timezone.replaceAll('_', ' ')}'),
                trailing: const Icon(Icons.edit_outlined, size: 20),
                onTap: () => _editFamily(context, f),
              ),
            ),
            const SectionTitle('Babies'),
            Card(
              child: Column(
                children: [
                  for (final c in f.children)
                    ListTile(
                      leading: ChildAvatar(child: c, size: 40),
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: c.age == null ? null : Text(c.age!),
                      trailing: const Icon(Icons.edit_outlined, size: 20),
                      onTap: () => showChildForm(context, familyId: f.id, child: c),
                    ),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Palette.line,
                      child: Icon(Icons.add, color: Palette.ink),
                    ),
                    title: const Text('Add a baby'),
                    onTap: () => showChildForm(context, familyId: f.id),
                  ),
                ],
              ),
            ),
            const SectionTitle('Caregivers'),
            Card(
              child: Column(
                children: [
                  for (final m in f.members)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Palette.raised,
                        child: Text(
                          m.name.isEmpty ? '?' : m.name.characters.first.toUpperCase(),
                          style: const TextStyle(color: Palette.accentLight, fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(m.userId == me.id ? '${m.name} (you)' : m.name),
                      subtitle: Text('${m.email} · ${m.role}'),
                      trailing: (f.isOwner && m.userId != me.id)
                          ? IconButton(icon: const Icon(Icons.person_remove_outlined), onPressed: () => _remove(context, f, m))
                          : null,
                    ),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Palette.line,
                      child: Icon(Icons.person_add_alt_1_outlined, color: Palette.ink),
                    ),
                    title: const Text('Invite a caregiver'),
                    subtitle: const Text('Partner, grandparent, nanny…'),
                    onTap: () => _invite(context, f),
                  ),
                ],
              ),
            ),
            const SectionTitle('Settings'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Imperial units'),
                    subtitle: Text(s.units.imperial ? 'oz, lb, in, °F' : 'mL, kg, cm, °C'),
                    value: s.units.imperial,
                    onChanged: (v) => guard(context, () => s.setUnits(v)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.public),
                    title: const Text('Time zone'),
                    subtitle: Text(f.timezone.replaceAll('_', ' ')),
                    onTap: () => _editFamily(context, f),
                  ),
                  ListTile(
                    leading: const Icon(Icons.cloud_download_outlined),
                    title: const Text('Import from Nara'),
                    subtitle: const Text('Bring over your Nara Baby history'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NaraImportScreen())),
                  ),
                  ListTile(
                    leading: const Icon(Icons.group_add_outlined),
                    title: const Text('Join another family'),
                    onTap: () => _join(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: const Text('API token'),
                    subtitle: const Text('For Home Assistant or scripts'),
                    onTap: () => _token(context),
                  ),
                ],
              ),
            ),
            const SectionTitle('Account'),
            Card(
              child: Column(
                children: [
                  ListTile(leading: const Icon(Icons.person_outline), title: Text(me.name), subtitle: Text(me.email)),
                  ListTile(leading: const Icon(Icons.dns_outlined), title: const Text('Server'), subtitle: Text(s.server)),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Palette.danger),
                    title: const Text('Sign out', style: TextStyle(color: Palette.danger)),
                    onTap: s.signOut,
                  ),
                ],
              ),
            ),
            if (f.isOwner) ...[
              const SizedBox(height: 16),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Palette.danger),
                onPressed: () async {
                  if (!await confirm(
                    context,
                    'Delete ${f.name}?',
                    'This permanently deletes the family, its babies and everything logged.',
                  )) {
                    return;
                  }
                  if (context.mounted) await guard(context, () => s.act((api) => api.delete('/families/${f.id}'), families: true));
                },
                child: const Text('Delete family'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _invite(BuildContext context, Family f) async {
    final s = context.read<AppState>();
    final res = await guard(context, () => s.api!.post('/families/${f.id}/invites'));
    if (res == null || !context.mounted) return;
    final code = res['code'] as String;
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Invite code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'They create an account on this server, then enter this code under “Join a family”. '
              'It works once and expires in 7 days.',
            ),
            const SizedBox(height: 20),
            SelectableText(code, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: 4)),
            const SizedBox(height: 8),
            Text('Server: ${s.server}', style: const TextStyle(color: Palette.muted)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              showMessage(context, 'Code copied');
            },
            child: const Text('Copy'),
          ),
          FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Done')),
        ],
      ),
    );
  }

  Future<void> _remove(BuildContext context, Family f, Member m) async {
    if (!await confirm(context, 'Remove ${m.name}?', 'They will lose access to ${f.name}.', action: 'Remove')) return;
    if (!context.mounted) return;
    final s = context.read<AppState>();
    await guard(context, () => s.act((api) => api.delete('/families/${f.id}/members/${m.userId}'), families: true));
  }

  Future<void> _join(BuildContext context) async {
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Join a family'),
        content: TextField(
          controller: code,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Invite code'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Join')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final s = context.read<AppState>();
    await guard(context, () => s.act((api) => api.post('/invites/${code.text.trim().toUpperCase()}/accept'), families: true));
  }

  Future<void> _editFamily(BuildContext context, Family f) async {
    final name = TextEditingController(text: f.name);
    var tz = f.timezone;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Family'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TimezoneField(value: tz, onChanged: (v) => set(() => tz = v)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final s = context.read<AppState>();
    await guard(context, () => s.act((api) => api.patch('/families/${f.id}', {'name': name.text.trim(), 'timezone': tz}), families: true));
  }

  Future<void> _token(BuildContext context) async {
    final s = context.read<AppState>();
    final res = await guard(context, () => s.api!.post('/me/tokens', {'name': 'Home Assistant'}));
    if (res == null || !context.mounted) return;
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('New API token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Copy it now — it won’t be shown again. Use it as “Authorization: Bearer <token>”.'),
            const SizedBox(height: 12),
            SelectableText(res['token'], style: const TextStyle(fontFamily: 'monospace')),
            const SizedBox(height: 12),
            Text(
              'Summary sensor: ${s.server}/api/v1/children/${s.childId}/summary',
              style: const TextStyle(color: Palette.muted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: res['token'])),
            child: const Text('Copy'),
          ),
          FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Done')),
        ],
      ),
    );
  }
}

/// Dry run first, then the real import.
class NaraImportScreen extends StatefulWidget {
  const NaraImportScreen({super.key});

  @override
  State<NaraImportScreen> createState() => _NaraImportScreenState();
}

class _NaraImportScreenState extends State<NaraImportScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  Map<String, dynamic>? _preview;
  Map<String, dynamic>? _done;

  Future<void> _run({required bool dryRun}) async {
    setState(() => _busy = true);
    final s = context.read<AppState>();
    final body = {'email': _email.text.trim(), 'password': _password.text, 'dry_run': dryRun, 'child_id': ?s.childId};
    final res = await guard(context, () => s.api!.post('/families/${s.familyId}/import/nara', body));
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res != null) dryRun ? _preview = res : _done = res;
    });
    if (!dryRun && res != null) await s.refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final child = context.watch<AppState>().child;
    return Scaffold(
      appBar: AppBar(title: const Text('Import from Nara')),
      body: Constrained(
        maxWidth: 480,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Sign in with your Nara account to copy your history into ${child?.name ?? 'this family'}. '
              'Your Nara password is used once and never stored. Running it again updates instead of duplicating.',
              style: t.bodyMedium?.copyWith(color: Palette.muted, height: 1.5),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Nara email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nara password'),
            ),
            const SizedBox(height: 20),
            if (_done != null)
              _Result(title: 'Import complete', data: _done!)
            else ...[
              OutlinedButton(
                onPressed: _busy ? null : () => _run(dryRun: true),
                child: Text(_preview == null ? 'Preview (nothing is saved)' : 'Preview again'),
              ),
              if (_preview != null) ...[
                const SizedBox(height: 16),
                _Result(title: 'Preview', data: _preview!),
                const SizedBox(height: 16),
                FilledButton(onPressed: _busy ? null : () => _run(dryRun: false), child: const Text('Import now')),
              ],
            ],
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.title, required this.data});
  final String title;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final byType = (data['by_type'] as Map?) ?? {};
    final skipped = (data['skipped'] as Map?) ?? {};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '${data['tracks']} Nara records · '
              '${data['importable'] ?? data['imported']} ${data['dry_run'] == true ? 'importable' : 'new'}'
              '${data['updated'] != null ? ' · ${data['updated']} updated' : ''}',
            ),
            if (byType.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final e in byType.entries) Chip(label: Text('${e.key}: ${e.value}'))]),
            ],
            if (skipped.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Skipped: ${skipped.entries.map((e) => '${e.key} (${e.value})').join(', ')}',
                style: const TextStyle(color: Palette.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
