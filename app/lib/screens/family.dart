import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../l10n/l10n.dart';
import '../local/drive_backup.dart';
import '../local/drive_relay.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'child_form.dart';
import 'day_hours.dart';
import 'home.dart' show ChildAvatar;
import 'pairing.dart';
import 'users.dart';

/// The family: its babies and caregivers, invites, joining another family (Home's people button).
class FamilyScreen extends StatelessWidget with _FamilyActions {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final f = s.family!;
    final me = s.me!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.familyTitle)),
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
                subtitle: Text('${l10n.familyCaregiverCount(f.members.length)} · ${f.timezone.replaceAll('_', ' ')}'),
                trailing: const Icon(Icons.edit_outlined, size: 20),
                onTap: () => _editFamily(context, f),
              ),
            ),
            SectionTitle(l10n.familyBabies),
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
                    title: Text(l10n.familyAddBaby),
                    onTap: () => showChildForm(context, familyId: f.id),
                  ),
                ],
              ),
            ),
            SectionTitle(l10n.familyCaregivers),
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
                      title: Text(m.userId == me.id ? l10n.familyYou(m.name) : m.name),
                      subtitle: Text(m.email.isEmpty ? m.roleLabel : '${m.email} · ${m.roleLabel}'),
                      trailing: (f.isOwner && m.userId != me.id && !s.serverless)
                          ? IconButton(icon: const Icon(Icons.person_remove_outlined), tooltip: l10n.remove, onPressed: () => _remove(context, f, m))
                          : null,
                      // Owners choose what each caregiver may do (e.g. book only for grandparents).
                      onTap: (f.isOwner && m.userId != me.id && !s.serverless) ? () => _changeRole(context, f, m) : null,
                    ),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: context.pal.line,
                      child: Icon(s.serverless ? Icons.qr_code_rounded : Icons.person_add_alt_1_outlined, color: context.pal.ink),
                    ),
                    title: Text(s.serverless ? l10n.familyPairPhone : l10n.familyInviteCaregiver),
                    subtitle: Text(s.serverless ? l10n.familyPairPhoneHint : l10n.familyInviteHint),
                    onTap: () => s.serverless ? Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PairScreen())) : _invite(context, f),
                  ),
                ],
              ),
            ),
            if (!s.serverless)
              Card(
                margin: const EdgeInsets.only(top: 12),
                child: ListTile(
                  leading: const Icon(Icons.group_add_outlined),
                  title: Text(l10n.familyJoinAnother),
                  subtitle: Text(l10n.familyJoinAnotherHint),
                  onTap: () => _join(context),
                ),
              ),
            if (f.isOwner && !s.serverless) ...[
              const SizedBox(height: 16),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: context.pal.danger),
                onPressed: () async {
                  if (!await confirmByTyping(
                    context,
                    l10n.familyDeleteTitle(f.name),
                    l10n.familyDeleteBody,
                    expected: f.name,
                  )) {
                    return;
                  }
                  if (context.mounted) await guard(context, () => s.act((api) => api.delete('/families/${f.id}'), families: true));
                },
                child: Text(l10n.familyDelete),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Settings and the account (Home's gear button): units, appearance, language, day and night, time zone, Drive sync and backup, Nara import, export, API token.
class SettingsScreen extends StatelessWidget with _FamilyActions {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final f = s.family!;
    final me = s.me!;
    // Book viewers only read the book: no family settings, imports, exports or API tokens.
    final full = !s.bookOnly;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.familySettings)),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          children: [
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(l10n.familyImperialUnits),
                    subtitle: Text(s.units.imperial ? 'oz, lb, in, °F' : 'mL, kg, cm, °C'),
                    value: s.units.imperial,
                    onChanged: (v) => guard(context, () => s.setUnits(v)),
                  ),
                  ListTile(
                    title: Text(l10n.familyAppearance),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: SegmentedButton<ThemeMode>(
                        segments: [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text(l10n.system),
                            icon: const Icon(Icons.brightness_auto_outlined),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text(l10n.familyThemeLight),
                            icon: const Icon(Icons.light_mode_outlined),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text(l10n.familyThemeDark),
                            icon: const Icon(Icons.dark_mode_outlined),
                          ),
                        ],
                        selected: {s.themeMode},
                        showSelectedIcon: false,
                        onSelectionChanged: (v) => s.setThemeMode(v.first),
                      ),
                    ),
                  ),
                  ListTile(
                    title: Text(l10n.language),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: DropdownButton<String?>(
                        value: s.language,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: [
                          DropdownMenuItem(value: null, child: Text(l10n.settingsLanguageDevice)),
                          for (final e in languages.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                        ],
                        onChanged: s.setLanguage,
                      ),
                    ),
                  ),
                  if (full)
                    ListTile(
                      leading: const Icon(Icons.wb_twilight_rounded),
                      title: Text(l10n.familyDayNight),
                      subtitle: Text(l10n.familyDaytime(f.dayEnd, f.dayStart)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DayHoursScreen())),
                    ),
                  if (full)
                    ListTile(
                      leading: const Icon(Icons.public),
                      title: Text(l10n.familyTimeZone),
                      subtitle: Text(f.timezone.replaceAll('_', ' ')),
                      onTap: () => _editFamily(context, f),
                    ),
                  if (s.serverless) const DriveSyncTile(),
                  if (s.serverless) DriveBackupTile(drive: s.drive),
                  if (full)
                    ListTile(
                      leading: const Icon(Icons.cloud_download_outlined),
                      title: Text(l10n.familyImportNara),
                      subtitle: Text(l10n.familyImportNaraHint),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NaraImportScreen())),
                    ),
                  if (!s.serverless && full)
                    ListTile(
                      leading: const Icon(Icons.file_download_outlined),
                      title: Text(l10n.familyExport),
                      subtitle: Text(l10n.familyExportHint),
                      onTap: () => _export(context, f),
                    ),
                  if (!s.serverless && full)
                    ListTile(
                      leading: const Icon(Icons.key_outlined),
                      title: Text(l10n.familyApiToken),
                      subtitle: Text(l10n.familyApiTokenHint),
                      onTap: () => _token(context),
                    ),
                ],
              ),
            ),
            if (!full) ...[
              SectionTitle(l10n.familyTitle),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.auto_stories_outlined),
                      title: Text(f.name),
                      subtitle: Text(l10n.familyBookOnlyHint),
                    ),
                    ListTile(
                      leading: const Icon(Icons.group_add_outlined),
                      title: Text(l10n.familyJoinAnother),
                      subtitle: Text(l10n.familyJoinAnotherHint),
                      onTap: () => _join(context),
                    ),
                    ListTile(
                      leading: Icon(Icons.exit_to_app_rounded, color: context.pal.danger),
                      title: Text(l10n.familyLeave(f.name), style: TextStyle(color: context.pal.danger)),
                      onTap: () => _leave(context, f),
                    ),
                  ],
                ),
              ),
            ],
            SectionTitle(l10n.familyAccount),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(me.name),
                    subtitle: me.email.isEmpty ? null : Text(me.email),
                  ),
                  ListTile(
                    leading: Icon(s.serverless ? Icons.smartphone_rounded : Icons.dns_outlined),
                    title: Text(s.serverless ? l10n.familyWithoutServer : l10n.familyServer),
                    subtitle: Text(s.serverless ? l10n.familyWithoutServerHint : s.server),
                  ),
                  if (!s.serverless)
                    ListTile(leading: const Icon(Icons.password_rounded), title: Text(l10n.familyChangePassword), onTap: () => _changePassword(context)),
                  if (me.isAdmin)
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      title: Text(l10n.usersTitle),
                      subtitle: Text(l10n.familyUsersHint),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UsersScreen())),
                    ),
                  ListTile(
                    leading: Icon(Icons.logout, color: context.pal.danger),
                    title: Text(s.serverless ? l10n.familyRemoveFromPhone : l10n.signOut, style: TextStyle(color: context.pal.danger)),
                    onTap: () async {
                      if (s.serverless) {
                        if (!await confirm(context, l10n.familyRemoveDataTitle, l10n.familyRemoveDataBody, action: l10n.remove)) {
                          return;
                        }
                        return s.signOut();
                      }
                      final n = s.pendingChanges;
                      if (n > 0 && !await confirm(context, l10n.familySignOutAnyway, l10n.familyPendingLost(n), action: l10n.signOut)) {
                        return;
                      }
                      await s.signOut();
                    },
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

/// What the family and settings screens both do.
mixin _FamilyActions {
  Future<void> _invite(BuildContext context, Family f) async {
    final s = context.read<AppState>();
    final role = await _pickRole(
      context,
      title: l10n.familyInviteCaregiver,
      current: 'caregiver',
      roles: [if (f.isOwner) 'owner', 'caregiver', 'book_viewer'],
      action: l10n.familyNext,
    );
    if (role == null || !context.mounted) return;
    final res = await guard(context, () => s.api!.post('/families/${f.id}/invites', {'role': role}));
    if (res == null || !context.mounted) return;
    final code = res['code'] as String;
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.familyInviteCode),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              [l10n.familyInviteBody, if (role == 'book_viewer') l10n.familyInviteBookOnly].join(' '),
            ),
            const SizedBox(height: 20),
            SelectableText(code, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: 4)),
            const SizedBox(height: 8),
            Text(l10n.familyServerValue(s.server), style: TextStyle(color: context.pal.muted)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              showMessage(context, l10n.familyCodeCopied);
            },
            child: Text(l10n.familyCopy),
          ),
          FilledButton(onPressed: () => Navigator.pop(c), child: Text(l10n.done)),
        ],
      ),
    );
  }

  /// Asks what a caregiver may do; null when cancelled.
  Future<String?> _pickRole(BuildContext context, {required String title, required String current, required List<String> roles, String? action}) {
    var role = current;
    return showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(title),
          contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
          content: RadioGroup<String>(
            groupValue: role,
            onChanged: (v) => set(() => role = v ?? role),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [for (final r in roles) RadioListTile<String>(value: r, title: Text(roleName(r)), subtitle: Text(roleHint(r)))],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(c, role), child: Text(action ?? l10n.save)),
          ],
        ),
      ),
    );
  }

  Future<void> _changeRole(BuildContext context, Family f, Member m) async {
    final role = await _pickRole(context, title: m.name, current: m.role, roles: memberRoles);
    if (role == null || role == m.role || !context.mounted) return;
    final s = context.read<AppState>();
    await guard(context, () => s.act((api) => api.patch('/families/${f.id}/members/${m.userId}', {'role': role}), families: true));
  }

  Future<void> _leave(BuildContext context, Family f) async {
    if (!await confirm(context, l10n.familyLeaveTitle(f.name), l10n.familyLeaveBody, action: l10n.familyLeaveAction)) return;
    if (!context.mounted) return;
    final s = context.read<AppState>();
    await guard(context, () => s.act((api) => api.delete('/families/${f.id}/members/${s.me!.id}'), families: true));
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _remove(BuildContext context, Family f, Member m) async {
    if (!await confirm(context, l10n.familyRemoveMemberTitle(m.name), l10n.familyRemoveMemberBody(f.name), action: l10n.remove)) return;
    if (!context.mounted) return;
    final s = context.read<AppState>();
    await guard(context, () => s.act((api) => api.delete('/families/${f.id}/members/${m.userId}'), families: true));
  }

  Future<void> _join(BuildContext context) async {
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.familyJoin),
        content: TextField(
          controller: code,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: l10n.familyInviteCode),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l10n.familyJoinButton)),
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
          title: Text(l10n.familyTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(labelText: l10n.familyName),
              ),
              const SizedBox(height: 12),
              TimezoneField(value: tz, onChanged: (v) => set(() => tz = v)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l10n.save)),
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
        title: Text(l10n.familyNewToken),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.familyTokenBody),
            const SizedBox(height: 12),
            SelectableText(res['token'], style: const TextStyle(fontFamily: 'monospace')),
            const SizedBox(height: 12),
            Text(l10n.familySummarySensor('${s.server}/api/v1/children/${s.childId}/summary'), style: TextStyle(color: context.pal.muted, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: res['token'])),
            child: Text(l10n.familyCopy),
          ),
          FilledButton(onPressed: () => Navigator.pop(c), child: Text(l10n.done)),
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
    final s = context.watch<AppState>();
    final child = s.child;
    final muted = t.bodyMedium?.copyWith(color: context.pal.muted, height: 1.5);
    final babyName = child?.name ?? l10n.familyThisBaby;
    final canPreview = _source == _Source.csv ? _fileBytes != null : _email.text.isNotEmpty && _password.text.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.familyImportNara)),
      body: Constrained(
        maxWidth: 480,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Signing in to Nara goes through the server; without one, the export file is the way.
            if (!s.serverless)
              SegmentedButton<_Source>(
                segments: [
                  ButtonSegment(value: _Source.csv, label: Text(l10n.familyImportExportFile), icon: const Icon(Icons.description_outlined)),
                  ButtonSegment(value: _Source.account, label: Text(l10n.familyImportAccount), icon: const Icon(Icons.login_rounded)),
                ],
                selected: {_source},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() {
                  _source = v.first;
                  _preview = _done = null;
                }),
              ),
            if (!s.serverless) const SizedBox(height: 20),
            if (_source == _Source.csv) ...[
              Text(l10n.familyImportCsvBody(babyName), style: muted),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickFile,
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(_fileName == null ? l10n.familyChooseCsv : l10n.familyChooseAnotherFile),
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
              Text(l10n.familyImportAccountBody(babyName), style: muted),
              const SizedBox(height: 16),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: l10n.familyNaraEmail),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: l10n.familyNaraPassword),
              ),
              const SizedBox(height: 16),
              if (_done == null)
                OutlinedButton(
                  onPressed: _busy || !canPreview ? null : () => _run(dryRun: true),
                  child: Text(_preview == null ? l10n.familyPreview : l10n.familyPreviewAgain),
                ),
            ],
            const SizedBox(height: 16),
            if (_done != null)
              _Result(title: l10n.familyImportComplete, data: _done!)
            else if (_preview != null) ...[
              _Result(title: l10n.familyReadyToImport, data: _preview!),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy || (_preview!['importable'] ?? 0) == 0 ? null : () => _run(dryRun: false),
                child: Text(l10n.familyImportRecords((_preview!['importable'] as num?)?.toInt() ?? 0, babyName)),
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

  static Map<String, String> get _labels => {
    'feed': l10n.familyTypeFeeds,
    'sleep': l10n.familyTypeSleep,
    'diaper': l10n.familyTypeDiapers,
    'pump': l10n.familyTypePump,
    'growth': l10n.familyTypeGrowth,
    'health': l10n.familyTypeHealth,
    'activity': l10n.familyTypeRoutine,
    'milestone': l10n.familyTypeFirsts,
    'note': l10n.familyTypeNotes,
  };

  @override
  Widget build(BuildContext context) {
    final byType = (data['by_type'] as Map?) ?? {};
    final skipped = (data['skipped'] as Map?) ?? {};
    final kids = (data['nara_children'] as List?) ?? [];
    final first = data['first_ms'], last = data['last_ms'];
    final dates = DateFormat.yMMMd();
    final summary = data['dry_run'] == true
        ? l10n.familyRecords((data['importable'] as num?)?.toInt() ?? 0)
        : l10n.familyImportedUpdated('${data['imported']}', '${data['updated']}');
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
                  [l10n.familyNaraProfile('${k['name']}'), if (k['birth_date'] != null) l10n.familyBorn(dates.format(DateTime.parse(k['birth_date'])))].join(' · '),
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
                  for (final e in byType.entries) Chip(avatar: BlobIcon(Kind.of(e.key), size: 22), label: Text('${_labels[e.key] ?? e.key} ${e.value}')),
                ],
              ),
            ],
            if (skipped.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(l10n.familySkipped(skipped.entries.map((e) => '${e.key} (${e.value})').join(', ')), style: TextStyle(color: context.pal.muted)),
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
      title: Text(l10n.familyChangePassword, style: serifStyle(22)),
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: current,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.familyCurrentPassword),
              validator: (v) => (v ?? '').isEmpty ? l10n.familyEnterCurrentPassword : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: next,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.familyNewPassword, helperText: l10n.familyOtherDevicesSignedOut),
              validator: (v) => (v ?? '').length < 8 ? l10n.familyAtLeast8 : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => form.currentState!.validate() ? Navigator.pop(c, true) : null, child: Text(l10n.save)),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final s = context.read<AppState>();
  final res = await guard(context, () => s.api!.patch('/me', {'password': next.text, 'current_password': current.text}));
  if (res != null && context.mounted) showMessage(context, l10n.familyPasswordChanged);
}

/// Download the family's data as CSV (same layout as the import reads, so it re-imports).
Future<void> _export(BuildContext context, Family f) async {
  final s = context.read<AppState>();
  final bytes = await guard(context, () => s.api!.getBytes('/families/${f.id}/export.csv'));
  if (bytes == null || !context.mounted) return;
  final slug = f.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  final name = 'nestling-${slug.isEmpty ? 'export' : slug}-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';
  final saved = await guard(context, () => FilePicker.saveFile(fileName: name, bytes: bytes, mimeType: 'text/csv').then((_) => true));
  if (saved == true && context.mounted) showMessage(context, l10n.familyExported(name));
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
      title: Text(l10n.familyBackupDrive),
      subtitle: Text(
        !DriveBackup.available
            ? l10n.familyAndroidOnly
            : last == null
            ? l10n.familyBackupHint
            : l10n.familyLastBackup(d.account ?? '', '${DateFormat.MMMd().format(last)}, ${DateFormat.Hm().format(last)}'),
      ),
      trailing: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
      enabled: DriveBackup.available && !_busy,
      onTap: () async {
        setState(() => _busy = true);
        final ok = await guard(this.context, () => d.backUp().then((_) => true));
        if (!mounted) return;
        setState(() => _busy = false);
        if (ok == true) showMessage(this.context, l10n.familyBackedUp);
      },
    );
  }
}

/// Serverless mode: sync through a shared Google Drive folder, so phones that aren't open at the
/// same time (or on the same Wi-Fi) still catch up.
class DriveSyncTile extends StatefulWidget {
  const DriveSyncTile({super.key});

  @override
  State<DriveSyncTile> createState() => _DriveSyncTileState();
}

class _DriveSyncTileState extends State<DriveSyncTile> {
  bool _busy = false;

  Future<void> _turnOn(AppState s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.familyDriveSync, style: serifStyle(22)),
        content: Text(l10n.familyDriveSyncBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l10n.familyContinue)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final merged = await guard(context, () => s.relay!.enable(s.familyId!));
    if (!mounted) return;
    setState(() => _busy = false);
    if (merged != null) {
      await s.load();
      if (mounted) showMessage(context, l10n.familyDriveSyncOn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final r = s.relay;
    final on = r?.on ?? false;
    final last = r?.sync.lastSync, error = r?.sync.error;
    final subtitle = !DriveRelay.available
        ? l10n.familyAndroidOnly
        : !on
        ? l10n.familyDriveSyncHint
        : error != null
        ? l10n.familyDriveSyncFailed
        : last == null
        ? l10n.familyDriveOn(r?.account ?? '')
        : l10n.familySyncedAgoAccount(r?.account ?? '', ago(DateTime.now().difference(last).inSeconds));
    return ListTile(
      leading: const Icon(Icons.cloud_sync_outlined),
      title: Text(l10n.familyDriveSync),
      subtitle: Text(subtitle),
      enabled: DriveRelay.available && !_busy && r != null,
      onTap: on ? () => s.syncRelay() : null,
      trailing: _busy
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Switch(
              value: on,
              onChanged: !DriveRelay.available || r == null
                  ? null
                  : (v) async {
                      if (v) return _turnOn(s);
                      await r.disable();
                      if (mounted) setState(() {});
                    },
            ),
    );
  }
}
