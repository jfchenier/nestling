import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/medicine_picker.dart';

/// The selected child's medicine schedules (how often each may be given; the home screen shows
/// when the next dose is allowed) and reminders (shown on the home screen when due, and sent to
/// phones by a server with notifications set up).
/// Both are saved on the child (`PATCH /children/{id}`, see src/schedule.rs).
class SchedulesScreen extends StatelessWidget {
  const SchedulesScreen({super.key});

  /// "Every 4 h", "Once a day", "Every 30 min".
  static String every(num hours) => switch (hours) {
    24 => 'Once a day',
    168 => 'Once a week',
    < 1 => 'Every ${(hours * 60).round()} min',
    _ => 'Every ${_n(hours)} h',
  };

  static String _n(num v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

  /// "30 min", "2 h", "1 h 30 min" (no line break inside a number and its unit).
  static String hm(int minutes) => switch ((minutes ~/ 60, minutes % 60)) {
    (0, final m) => '$m\u00a0min',
    (final h, 0) => '$h\u00a0h',
    (final h, final m) => '$h\u00a0h $m\u00a0min',
  };

  /// The Family screen's line: "Vitamin D, Tylenol · feed reminder".
  static String describe(Child c) {
    final meds = c.medicines.map((m) => '${m['name']}').join(', ');
    final rem = c.reminders.map((r) => '${r['type']}').join(', ');
    final parts = [if (meds.isNotEmpty) meds, if (rem.isNotEmpty) '$rem reminder${c.reminders.length == 1 ? '' : 's'}'];
    return parts.isEmpty ? 'Doses on a schedule, "no feed in 3 h"…' : parts.join(' · ');
  }

  static const _types = {'feed': ('Feed', 'feed'), 'sleep': ('Sleep', 'sleep'), 'diaper': ('Diaper', 'diaper change'), 'pump': ('Pump', 'pumping')};
  static const _afterChoices = [30, 60, 90, 120, 150, 180, 210, 240, 300, 360, 480, 720];

  Future<void> _save(BuildContext context, Child c, Map<String, dynamic> body) async {
    final s = context.read<AppState>();
    await guard(context, () => s.act((api) => api.patch('/children/${c.id}', body), families: true));
  }

  Future<void> _editMedicine(BuildContext context, Child c, int? index, {MedicinePick? pick}) async {
    final s = context.read<AppState>();
    final list = c.medicines;
    final m = index == null ? <String, dynamic>{'name': pick?.name ?? '', 'dose': pick?.dose, 'dose_unit': pick?.unit} : list[index];
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => _MedicineDialog(medicine: m, isNew: index == null, canRemind: s.pushEnabled),
    );
    if (result == null || !context.mounted) return;
    if (result.isEmpty) {
      list.removeAt(index!);
    } else if (index == null) {
      list.add(result);
    } else {
      list[index] = result;
    }
    await _save(context, c, {'medicines': list});
  }

  Future<void> _addMedicine(BuildContext context, Child c) async {
    final pick = await showMedicinePicker(context);
    if (pick == null || !context.mounted) return;
    await _editMedicine(context, c, null, pick: pick);
  }

  Future<void> _editReminder(BuildContext context, Child c, String type) async {
    final list = c.reminders;
    final current = list.where((r) => r['type'] == type).firstOrNull;
    final (label, what) = _types[type]!;
    final choice = await showDialog<int>(
      context: context,
      builder: (d) => SimpleDialog(
        title: Text('$label reminder'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              type == 'sleep' ? 'Notify when awake for this long:' : 'Notify when there was no $what for:',
              style: TextStyle(color: d.pal.muted),
            ),
          ),
          for (final m in _afterChoices)
            ListTile(
              title: Text(hm(m)),
              trailing: current?['after_minutes'] == m ? Icon(Icons.check_rounded, color: d.pal.accent) : null,
              onTap: () => Navigator.pop(d, m),
            ),
          ListTile(
            title: const Text('Off'),
            trailing: current == null ? Icon(Icons.check_rounded, color: d.pal.accent) : null,
            onTap: () => Navigator.pop(d, 0),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    list.removeWhere((r) => r['type'] == type);
    if (choice > 0) list.add({'type': type, 'after_minutes': choice});
    // Same order as the home cards.
    list.sort((a, b) => _types.keys.toList().indexOf(a['type']).compareTo(_types.keys.toList().indexOf(b['type'])));
    await _save(context, c, {'reminders': list});
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = s.child;
    final pal = context.pal;
    if (c == null) return const Scaffold();
    final meds = c.medicines;
    String medLine(Map<String, dynamic> m) => [
      every(m['every_hours'] as num),
      if (m['max_per_day'] != null) 'up to ${m['max_per_day']} a day',
      if (m['dose'] != null) '${_n(m['dose'] as num)} ${m['dose_unit'] ?? ''}'.trim(),
      if (s.pushEnabled && m['remind'] == true) 'reminder on',
    ].join(' · ');
    return Scaffold(
      appBar: AppBar(title: const Text('Medicines and reminders')),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Text(
              'For ${c.name}. A scheduled medicine shows on the home screen with when the next dose may be given, '
              'and logging one too early warns you.',
              style: TextStyle(color: pal.muted, fontSize: 14, height: 1.4),
            ),
            const SectionTitle('Medicine schedule'),
            Card(
              child: Column(
                children: [
                  for (final (i, m) in meds.indexed)
                    ListTile(
                      leading: const BlobIcon(Kind.health, icon: Icons.medication_rounded, size: 40),
                      title: Text('${m['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(medLine(m)),
                      trailing: const Icon(Icons.edit_outlined, size: 20),
                      onTap: () => _editMedicine(context, c, i),
                    ),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: pal.line,
                      child: Icon(Icons.add, color: pal.ink),
                    ),
                    title: const Text('Add a medicine'),
                    onTap: () => _addMedicine(context, c),
                  ),
                ],
              ),
            ),
            const SectionTitle('Reminders'),
            Card(
              child: Column(
                children: [
                  for (final MapEntry(key: type, value: (label, what)) in _types.entries)
                    () {
                      final r = c.reminders.where((r) => r['type'] == type).firstOrNull;
                      final kind = Kind.of(type == 'feed' ? 'feed' : type);
                      return ListTile(
                        leading: BlobIcon(kind, size: 40),
                        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          r == null
                              ? 'Off'
                              : type == 'sleep'
                              ? 'When awake for ${hm(r['after_minutes'] as int)}'
                              : 'When there was no $what for ${hm(r['after_minutes'] as int)}',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _editReminder(context, c, type),
                      );
                    }(),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.pushEnabled
                  ? 'A reminder that is due shows on the home screen (swipe it away to hide it) and is sent to the phones of everyone in the family. '
                        'A medicine\'s phone reminder is turned on in its schedule.'
                  : s.serverless
                  ? 'A reminder that is due shows on the home screen (swipe it away to hide it). Phone notifications need a Nestling server with them set up.'
                  : 'A reminder that is due shows on the home screen (swipe it away to hide it). To also get it as a phone notification, set up '
                        'notifications on the server (see "Notifications on phones" in the README).',
              style: TextStyle(color: pal.muted, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Edit a medicine schedule. Pops the new schedule, `{}` to remove it, or null.
class _MedicineDialog extends StatefulWidget {
  const _MedicineDialog({required this.medicine, required this.isNew, required this.canRemind});
  final Map<String, dynamic> medicine;
  final bool isNew, canRemind;

  @override
  State<_MedicineDialog> createState() => _MedicineDialogState();
}

class _MedicineDialogState extends State<_MedicineDialog> {
  static String _n(Object? v) => v is num ? SchedulesScreen._n(v) : '';

  late final _name = TextEditingController(text: '${widget.medicine['name'] ?? ''}');
  late final _every = TextEditingController(text: _n(widget.medicine['every_hours']));
  late final _max = TextEditingController(text: _n(widget.medicine['max_per_day']));
  late final _dose = TextEditingController(text: _n(widget.medicine['dose']));
  late final _unit = TextEditingController(text: '${widget.medicine['dose_unit'] ?? 'mL'}');
  late bool _remind = widget.medicine['remind'] == true || (widget.isNew && widget.canRemind);
  String? _error;

  static num? _num(TextEditingController c) {
    final v = num.tryParse(c.text.trim().replaceAll(',', '.'));
    return v == null ? null : (v == v.roundToDouble() ? v.round() : v);
  }

  void _save() {
    final every = _num(_every), max = _num(_max), dose = _num(_dose);
    String? err;
    if (_name.text.trim().isEmpty) {
      err = 'Give the medicine a name.';
    } else if (every == null || every < 0.5 || every > 168) {
      err = 'How often: between 0.5 and 168 hours.';
    } else if (_max.text.trim().isNotEmpty && (max is! int || max < 1 || max > 24)) {
      err = 'At most per 24 hours: a number from 1 to 24.';
    } else if (_dose.text.trim().isNotEmpty && dose == null) {
      err = 'The dose must be a number.';
    }
    if (err != null) return setState(() => _error = err);
    Navigator.pop(context, <String, dynamic>{
      'name': _name.text.trim(),
      'every_hours': every,
      'max_per_day': ?max,
      'dose': ?dose,
      if (dose != null && _unit.text.trim().isNotEmpty) 'dose_unit': _unit.text.trim(),
      'remind': widget.canRemind ? _remind : widget.medicine['remind'] == true,
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    const quick = [4, 6, 8, 12, 24];
    return AlertDialog(
      title: Text(widget.isNew ? 'Add a medicine' : 'Medicine'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _every,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Every', suffixText: 'hours'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final h in quick)
                ChoiceChip(
                  label: Text(h == 24 ? 'daily' : '$h h'),
                  selected: _num(_every) == h,
                  onSelected: (_) => setState(() => _every.text = '$h'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _max,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'At most per 24 hours (optional)', suffixText: 'doses'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _dose,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Usual dose (optional)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _unit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                ),
              ),
            ],
          ),
          if (widget.canRemind) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Remind when the next dose is due'),
              value: _remind,
              onChanged: (v) => setState(() => _remind = v),
            ),
          ],
          if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: TextStyle(color: pal.danger))],
        ],
      ),
      actions: [
        if (!widget.isNew)
          TextButton(
            onPressed: () => Navigator.pop(context, <String, dynamic>{}),
            child: Text('Remove', style: TextStyle(color: pal.danger)),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
