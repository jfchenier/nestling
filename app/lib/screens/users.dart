import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Server admins: every account on this server. Add caregivers (optionally straight into your
/// family), reset a forgotten password, make someone admin, remove an account.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<Map<String, dynamic>>? _users;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = context.read<AppState>();
    final res = await guard(context, () => s.api!.get('/admin/users'));
    if (mounted && res != null) setState(() => _users = [for (final u in res['users'] as List) u as Map<String, dynamic>]);
  }

  Future<void> _run(Future<dynamic> Function() action, String done) async {
    final ok = await guard(context, action);
    if (ok == null || !mounted) return;
    showMessage(context, done);
    await _load();
  }

  Future<void> _add() async {
    final s = context.read<AppState>();
    final family = s.family;
    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _NewUserDialog(familyName: family?.name),
    );
    if (res == null || !mounted) return;
    if (res.remove('add_to_family') == true && family != null) res['family_id'] = family.id;
    await _run(() => s.api!.post('/admin/users', res), '${res['name']} can now sign in');
  }

  Future<void> _resetPassword(Map<String, dynamic> u) async {
    final password = await _askPassword(context, u['name']);
    if (password == null || !mounted) return;
    await _run(
      () => context.read<AppState>().api!.patch('/admin/users/${u['id']}', {'password': password}),
      'New password set for ${u['name']}',
    );
  }

  Future<void> _toggleAdmin(Map<String, dynamic> u) => _run(
    () => context.read<AppState>().api!.patch('/admin/users/${u['id']}', {'is_admin': u['is_admin'] != true}),
    u['is_admin'] == true ? '${u['name']} is no longer an admin' : '${u['name']} is now an admin',
  );

  Future<void> _delete(Map<String, dynamic> u) async {
    if (!await confirm(context, 'Remove ${u['name']}?', 'They can no longer sign in. Their families and everything logged stay.')) {
      return;
    }
    if (mounted) await _run(() => context.read<AppState>().api!.delete('/admin/users/${u['id']}'), '${u['name']} removed');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final users = _users;
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add user'),
      ),
      body: users == null
          ? const Center(child: CircularProgressIndicator())
          : Constrained(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                    child: Text(
                      'Only admins can create accounts on this server. Give people their email and '
                      'password; they can change the password under Settings → Account.',
                      style: TextStyle(color: c.muted),
                    ),
                  ),
                  Card(
                    child: Column(
                      children: [
                        for (final u in users)
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: u['is_admin'] == true ? c.accentSoft : c.raised,
                              child: Icon(
                                u['is_admin'] == true ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                                color: u['is_admin'] == true ? c.accent : c.muted,
                              ),
                            ),
                            title: Text('${u['name']}${u['you'] == true ? ' (you)' : ''}'),
                            subtitle: Text(
                              [
                                u['email'],
                                if (u['is_admin'] == true) 'admin',
                                for (final f in (u['families'] as List? ?? [])) f['name'],
                              ].join(' · '),
                            ),
                            trailing: PopupMenuButton<String>(
                              tooltip: 'Manage ${u['name']}',
                              onSelected: (v) => switch (v) {
                                'password' => _resetPassword(u),
                                'admin' => _toggleAdmin(u),
                                _ => _delete(u),
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'password', child: Text('Set a new password')),
                                PopupMenuItem(value: 'admin', child: Text(u['is_admin'] == true ? 'Remove admin' : 'Make admin')),
                                if (u['you'] != true)
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Remove account', style: TextStyle(color: c.danger)),
                                  ),
                              ],
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

Future<String?> _askPassword(BuildContext context, String name) {
  final password = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('New password for $name', style: serifStyle(22)),
      content: TextField(
        controller: password,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Password', helperText: 'At least 8 characters. They\'ll be signed out.'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        FilledButton(onPressed: () => password.text.length < 8 ? null : Navigator.pop(c, password.text), child: const Text('Save')),
      ],
    ),
  );
}

class _NewUserDialog extends StatefulWidget {
  const _NewUserDialog({this.familyName});
  final String? familyName;

  @override
  State<_NewUserDialog> createState() => _NewUserDialogState();
}

class _NewUserDialogState extends State<_NewUserDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _email = TextEditingController(), _password = TextEditingController();
  bool _admin = false;
  late bool _family = widget.familyName != null;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Add a user', style: serifStyle(22)),
    content: Form(
      key: _form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) => (v ?? '').contains('@') ? null : 'Enter an email',
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _password,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Password', helperText: 'They can change it later'),
              validator: (v) => (v ?? '').length < 8 ? 'At least 8 characters' : null,
            ),
            if (widget.familyName != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Add to ${widget.familyName}'),
                subtitle: const Text('As a caregiver'),
                value: _family,
                onChanged: (v) => setState(() => _family = v),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Admin'),
              subtitle: const Text('Can manage users'),
              value: _admin,
              onChanged: (v) => setState(() => _admin = v),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(context, {
            'name': _name.text.trim(),
            'email': _email.text.trim(),
            'password': _password.text,
            'is_admin': _admin,
            'add_to_family': _family,
          });
        },
        child: const Text('Add'),
      ),
    ],
  );
}
