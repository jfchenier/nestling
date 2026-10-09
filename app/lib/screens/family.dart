import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../local/drive_backup.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'child_form.dart';
import 'home.dart' show ChildAvatar;
import 'pairing.dart';
import 'users.dart';

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
                leading: CircleAvatar(
                  backgroundColor: context.pal.raised,
                  child: Icon(Icons.home_rounded, color: context.pal.accent),
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
                    leading: CircleAvatar(
                      backgroundColor: context.pal.line,
                      child: Icon(Icons.add, color: context.pal.ink),
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
                        backgroundColor: context.pal.raised,
                        child: Text(
                          m.name.isEmpty ? '?' : m.name.characters.first.toUpperCase(),
                          style: TextStyle(color: context.pal.accent, fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(m.userId == me.id ? '${m.name} (you)' : m.name),
                      subtitle: Text(m.email.isEmpty ? m.role : '${m.email} · ${m.role}'),
                      trailing: (f.isOwner && m.userId != me.id && !s.serverless)
                          ? IconButton(icon: const Icon(Icons.person_remove_outlined), onPressed: () => _remove(context, f, m))
                          : null,
                    ),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: context.pal.line,
                      child: Icon(s.serverless ? Icons.qr_code_rounded : Icons.person_add_alt_1_outlined, color: context.pal.ink),
                    ),
                    title: Text(s.serverless ? 'Pair a phone' : 'Invite a caregiver'),
                    subtitle: Text(s.serverless ? 'Your partner\'s phone syncs with this one over Wi-Fi' : 'Partner, grandparent, nanny…'),
                    onTap: () => s.serverless
                        ? Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PairScreen()))
                        : _invite(context, f),
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
                    title: const Text('Appearance'),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_outlined)),
                          ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                          ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
                        ],
                        selected: {s.themeMode},
                        showSelectedIcon: false,
                        onSelectionChanged: (v) => s.setThemeMode(v.first),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.public),
                    title: const Text('Time zone'),
                    subtitle: Text(f.timezone.replaceAll('_', ' ')),
                    onTap: () => _editFamily(context, f),
                  ),
                  if (s.serverless) DriveBackupTile(drive: s.drive),
                  if (!s.serverless) ListTile(
                    leading: const Icon(Icons.cloud_download_outlined),
                    title: const Text('Import from Nara'),
                    subtitle: const Text('Bring over your Nara Baby history'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NaraImportScreen())),
                  ),
                  if (!s.serverless) ListTile(
                    leading: const Icon(Icons.file_download_outlined),
                    title: const Text('Export data'),
                    subtitle: const Text('Everything for this family as a CSV file'),
                    onTap: () => _export(context, f),
                  ),
                  if (!s.serverless) ListTile(
                    leading: const Icon(Icons.group_add_outlined),
                    title: const Text('Join another family'),
                    onTap: () => _join(context),
                  ),
                  if (!s.serverless) ListTile(
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
                  ListTile(leading: const Icon(Icons.person_outline), title: Text(me.name), subtitle: me.email.isEmpty ? null : Text(me.email)),
                  ListTile(
                    leading: Icon(s.serverless ? Icons.smartphone_rounded : Icons.dns_outlined),
                    title: Text(s.serverless ? 'Without a server' : 'Server'),
                    subtitle: Text(s.serverless ? 'Saved on this phone and the phones paired with it' : s.server),
                  ),
                  if (!s.serverless) ListTile(
                    leading: const Icon(Icons.password_rounded),
                    title: const Text('Change password'),
                    onTap: () => _changePassword(context),
                  ),
                  if (me.isAdmin)
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      title: const Text('Users'),
                      subtitle: const Text('Create and manage accounts on this server'),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UsersScreen())),
                    ),
                  ListTile(
                    leading: Icon(Icons.logout, color: context.pal.danger),
                    title: Text(s.serverless ? 'Remove from this phone' : 'Sign out', style: TextStyle(color: context.pal.danger)),
                    onTap: () async {
                      if (s.serverless) {
                        if (!await confirm(
                          context,
                          'Remove Nestling\'s data from this phone?',
                          'Everything logged here is erased from this phone. Paired phones and your Google Drive backup keep their copy.',
                          action: 'Remove',
                        )) {
                          return;
                        }
                        return s.signOut();
                      }
                      final n = s.pendingChanges;
                      if (n > 0 &&
                          !await confirm(
                            context,
                            'Sign out anyway?',
                            '$n change${n == 1 ? '' : 's'} made offline ${n == 1 ? 'hasn\'t' : 'haven\'t'} reached the server yet and will be lost.',
                            action: 'Sign out',
                          )) {
                        return;
                      }
                      await s.signOut();
                    },
                  ),
                ],
              ),
            ),
            if (f.isOwner && !s.serverless) ...[
              const SizedBox(height: 16),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: context.pal.danger),
                onPressed: () async {
                  if (!await confirmByTyping(
                    context,
                    'Delete ${f.name}?',
                    'This permanently deletes the family, its babies and everything logged, for every caregiver. '
                        'It can\'t be undone.',
                    expected: f.name,
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
            Text('Server: ${s.server}', style: TextStyle(color: context.pal.muted)),
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
              style: TextStyle(color: context.pal.muted, fontSize: 12),
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

enum _Source { csv, account }

/// Bring history over from Nara: the app's CSV export (preferred) or the Nara account.
/// Always previews first; importing again updates instead of duplicating.
class _NaraImportScreenState extends State<NaraImportScreen> {
  _Source _source = _Source.csv;
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _fileName;
  List<int>? _fileBytes;
  bool _busy = false;
  Map<String, dynamic>? _preview;
  Map<String, dynamic>? _done;

  Future<void> _pickFile() async {
    final files = await guard(context, () => FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['csv']));
    if (files == null || files.isEmpty || !mounted) return;
    final bytes = await guard(context, () => files.first.xFile.readAsBytes());
    if (bytes == null || !mounted) return;
    setState(() {
      _fileName = files.first.name;
      _fileBytes = bytes;
      _preview = _done = null;
    });
    await _run(dryRun: true);
  }

  Future<void> _run({required bool dryRun}) async {
    setState(() => _busy = true);
    final s = context.read<AppState>();
    final res = await guard(context, () {
      if (_source == _Source.csv) {
        return s.api!.upload('/families/${s.familyId}/import/nara-csv', _fileBytes!, query: {'dry_run': '$dryRun', 'child_id': ?s.childId});
      }
      final body = {'email': _email.text.trim(), 'password': _password.text, 'dry_run': dryRun, 'child_id': ?s.childId};
      return s.api!.post('/families/${s.familyId}/import/nara', body);
    });
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
    final muted = t.bodyMedium?.copyWith(color: context.pal.muted, height: 1.5);
    final canPreview = _source == _Source.csv ? _fileBytes != null : _email.text.isNotEmpty && _password.text.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Import from Nara')),
      body: Constrained(
        maxWidth: 480,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<_Source>(
              segments: const [
                ButtonSegment(value: _Source.csv, label: Text('Export file'), icon: Icon(Icons.description_outlined)),
                ButtonSegment(value: _Source.account, label: Text('Nara account'), icon: Icon(Icons.login_rounded)),
              ],
              selected: {_source},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() {
                _source = v.first;
                _preview = _done = null;
              }),
            ),
            const SizedBox(height: 20),
            if (_source == _Source.csv) ...[
              Text(
                'Export your data from the Nara app (it gives you a .csv file), then pick that file here. '
                'Everything goes into ${child?.name ?? 'this baby'}; importing the same file again updates instead of duplicating.',
                style: muted,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickFile,
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(_fileName == null ? 'Choose the CSV file' : 'Choose another file'),
              ),
              if (_fileName != null && _fileBytes != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '$_fileName · ${(_fileBytes!.length / 1024).toStringAsFixed(0)} KB',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.pal.muted),
                  ),
                ),
            ] else ...[
              Text(
                'Sign in with your Nara account to copy your history into ${child?.name ?? 'this baby'}. '
                'Your Nara password is used once and never stored.',
                style: muted,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Nara email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Nara password'),
              ),
              const SizedBox(height: 16),
              if (_done == null)
                OutlinedButton(
                  onPressed: _busy || !canPreview ? null : () => _run(dryRun: true),
                  child: Text(_preview == null ? 'Preview (nothing is saved)' : 'Preview again'),
                ),
            ],
            const SizedBox(height: 16),
            if (_done != null)
              _Result(title: 'Import complete', data: _done!)
            else if (_preview != null) ...[
              _Result(title: 'Ready to import', data: _preview!),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy || (_preview!['importable'] ?? 0) == 0 ? null : () => _run(dryRun: false),
                child: Text('Import ${_preview!['importable']} records into ${child?.name ?? 'this baby'}'),
              ),
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

  static const _labels = {
    'feed': 'Feeds',
    'sleep': 'Sleep',
    'diaper': 'Diapers',
    'pump': 'Pump',
    'growth': 'Growth',
    'health': 'Health',
    'activity': 'Routine',
    'milestone': 'Firsts',
    'note': 'Notes',
  };

  @override
  Widget build(BuildContext context) {
    final byType = (data['by_type'] as Map?) ?? {};
    final skipped = (data['skipped'] as Map?) ?? {};
    final kids = (data['nara_children'] as List?) ?? [];
    final first = data['first_ms'], last = data['last_ms'];
    final dates = DateFormat.yMMMd();
    final summary = data['dry_run'] == true ? '${data['importable']} records' : '${data['imported']} new · ${data['updated']} updated';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: serifStyle(22)),
            const SizedBox(height: 4),
            Text(summary, style: const TextStyle(fontWeight: FontWeight.w600)),
            for (final k in kids)
              if (k is Map && k['name'] != null)
                Text(
                  [
                    'Nara profile: ${k['name']}',
                    if (k['birth_date'] != null) 'born ${dates.format(DateTime.parse(k['birth_date']))}',
                  ].join(' · '),
                  style: TextStyle(color: context.pal.muted),
                ),
            if (first is int && last is int)
              Text(
                '${dates.format(DateTime.fromMillisecondsSinceEpoch(first))} – ${dates.format(DateTime.fromMillisecondsSinceEpoch(last))}',
                style: TextStyle(color: context.pal.muted),
              ),
            if (byType.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in byType.entries)
                    Chip(avatar: BlobIcon(Kind.of(e.key), size: 22), label: Text('${_labels[e.key] ?? e.key} ${e.value}')),
                ],
              ),
            ],
            if (skipped.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Skipped: ${skipped.entries.map((e) => '${e.key} (${e.value})').join(', ')}',
                style: TextStyle(color: context.pal.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Your own password (needs the current one; other devices are signed out).
Future<void> _changePassword(BuildContext context) async {
  final current = TextEditingController(), next = TextEditingController();
  final form = GlobalKey<FormState>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Change password', style: serifStyle(22)),
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: current,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Current password'),
              validator: (v) => (v ?? '').isEmpty ? 'Enter your current password' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password', helperText: 'Other devices will be signed out'),
              validator: (v) => (v ?? '').length < 8 ? 'At least 8 characters' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        FilledButton(onPressed: () => form.currentState!.validate() ? Navigator.pop(c, true) : null, child: const Text('Save')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final s = context.read<AppState>();
  final res = await guard(context, () => s.api!.patch('/me', {'password': next.text, 'current_password': current.text}));
  if (res != null && context.mounted) showMessage(context, 'Password changed');
}

/// Download the family's data as CSV (same layout as the import reads, so it re-imports).
Future<void> _export(BuildContext context, Family f) async {
  final s = context.read<AppState>();
  final bytes = await guard(context, () => s.api!.getBytes('/families/${f.id}/export.csv'));
  if (bytes == null || !context.mounted) return;
  final slug = f.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  final name = 'nestling-${slug.isEmpty ? 'export' : slug}-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
  final saved = await guard(context, () => FilePicker.saveFile(fileName: name, bytes: bytes, mimeType: 'text/csv').then((_) => true));
  if (saved == true && context.mounted) showMessage(context, 'Exported $name');
}

/// Serverless mode: back up to (and see the last backup in) the caregiver's Google Drive.
class DriveBackupTile extends StatefulWidget {
  const DriveBackupTile({super.key, required this.drive});
  final DriveBackup drive;

  @override
  State<DriveBackupTile> createState() => _DriveBackupTileState();
}

class _DriveBackupTileState extends State<DriveBackupTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.drive, last = d.lastBackup;
    return ListTile(
      leading: const Icon(Icons.backup_outlined),
      title: const Text('Back up to Google Drive'),
      subtitle: Text(
        !DriveBackup.available
            ? 'Available in the Android app'
            : last == null
            ? 'Keeps a copy in your Google account, once a day'
            : 'Last backup ${DateFormat('MMM d, HH:mm').format(last)} · ${d.account ?? ''}',
      ),
      trailing: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
      enabled: DriveBackup.available && !_busy,
      onTap: () async {
        setState(() => _busy = true);
        final ok = await guard(this.context, () => d.backUp().then((_) => true));
        if (!mounted) return;
        setState(() => _busy = false);
        if (ok == true) showMessage(this.context, 'Backed up to Google Drive');
      },
    );
  }
}
