import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../l10n/l10n.dart';
import '../local/schedule.dart' show routineKey;
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/medicine_picker.dart';

/// The selected child's medicine schedules (how often each may be given; the home screen shows
/// when the next dose is allowed), routines (a bath every 2 days, on Mondays and Fridays…; shown
/// on the home screen when due) and reminders (shown on the home screen when due). All of them are
/// sent to phones by a server with notifications set up.
/// They are saved on the child (`PATCH /children/{id}`, see src/schedule.rs).
class SchedulesScreen extends StatelessWidget {
  const SchedulesScreen({super.key});

  /// "Every 4 h", "Once a day", "Every 30 min".
  static String every(num hours) => switch (hours) {
    24 => l10n.scheduleOnceADay,
    168 => l10n.scheduleOnceAWeek,
    final h when h > 24 && h % 24 == 0 => l10n.scheduleEveryNDays(h ~/ 24),
    < 1 => l10n.scheduleEveryMinutes((hours * 60).round()),
    _ => l10n.scheduleEveryHours(_n(hours)),
  };

  static String _n(num v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

  /// A saved "HH:MM" dose time, shown in the user's clock format.
  static String clock(String hhmm) {
    final [h, m] = [for (final p in hhmm.split(':')) int.tryParse(p) ?? 0];
    return minutesOfDay(h * 60 + m);
  }

  /// "Daily at 08:00, 20:00", "Every 2 days at 19:00" or "Mon, Fri at 19:00" for set times,
  /// "Every 4 h" otherwise.
  static String when(Map<String, dynamic> m) {
    final times = m['times'] as List? ?? const [];
    if (times.isEmpty) return every(m['every_hours'] as num);
    final at = times.map((t) => clock('$t')).join(', ');
    if (m['weekdays'] case final List days when days.isNotEmpty) {
      return l10n.scheduleWeekdaysAt(days.map((d) => weekdayName(d as int)).join(', '), at);
    }
    if (m['every_days'] case final int n when n > 1) return l10n.scheduleEveryDaysAt(n, at);
    return l10n.scheduleDailyAt(at);
  }

  /// "Mon" for 1 … "Sun" for 7, in the app's language.
  static String weekdayName(int day) => DateFormat.E().format(DateTime(2024, 1, day));

  /// "30 min", "2 h", "1 h 30 min" (no line break inside a number and its unit).
  static String hm(int minutes) => switch ((minutes ~/ 60, minutes % 60)) {
    (0, final m) => '$m\u00a0min',
    (final h, 0) => '$h\u00a0h',
    (final h, final m) => '$h\u00a0h $m\u00a0min',
  };

  /// The Family screen's line: "Vitamin D, Tylenol, Bath · feed reminder".
  static String describe(Child c) {
    final meds = [for (final m in c.medicines) '${m['name']}', for (final r in c.routines) cap('${r['name']}')].join(', ');
    final rem = c.reminders.map((r) => _typeLabel('${r['type']}').toLowerCase()).join(', ');
    final parts = [if (meds.isNotEmpty) meds, if (rem.isNotEmpty) l10n.scheduleRemindersList(c.reminders.length, rem)];
    return parts.isEmpty ? l10n.scheduleDescribeEmpty : parts.join(' · ');
  }

  /// Reminder types, in the order of the home cards.
  static const _types = ['feed', 'sleep', 'diaper', 'pump'];

  static String _typeLabel(String type) => switch (type) {
    'sleep' => l10n.kindSleep,
    'diaper' => l10n.kindDiaper,
    'pump' => l10n.kindPump,
    _ => l10n.scheduleFeed,
  };
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

  Future<void> _editRoutine(BuildContext context, Child c, int? index, {String? name}) async {
    final s = context.read<AppState>();
    final list = c.routines;
    final r = index == null ? <String, dynamic>{'name': name} : list[index];
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => _RoutineDialog(routine: r, isNew: index == null, canRemind: s.pushEnabled),
    );
    if (result == null || !context.mounted) return;
    if (result.isEmpty) {
      list.removeAt(index!);
    } else if (index == null) {
      list.add(result);
    } else {
      list[index] = result;
    }
    await _save(context, c, {'routines': list});
  }

  Future<void> _addRoutine(BuildContext context, Child c) async {
    final name = await showActivityPicker(context);
    if (name == null || !context.mounted) return;
    final i = c.routines.indexWhere((r) => routineKey('${r['name']}') == routineKey(name));
    await _editRoutine(context, c, i < 0 ? null : i, name: name);
  }

  Future<void> _editReminder(BuildContext context, Child c, String type) async {
    final list = c.reminders;
    final current = list.where((r) => r['type'] == type).firstOrNull;
    final choice = await showDialog<int>(
      context: context,
      builder: (d) => SimpleDialog(
        title: Text(l10n.scheduleReminderTitle(_typeLabel(type))),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              l10n.scheduleNotifyWhen(type),
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
            title: Text(l10n.scheduleOff),
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
    list.sort((a, b) => _types.indexOf(a['type']).compareTo(_types.indexOf(b['type'])));
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
      when(m),
      if (m['max_per_day'] != null && (m['times'] as List? ?? const []).isEmpty) l10n.scheduleUpToPerDay(m['max_per_day']),
      if (m['dose'] != null) '${_n(m['dose'] as num)} ${m['dose_unit'] ?? ''}'.trim(),
      if (s.pushEnabled && m['remind'] == true) l10n.scheduleReminderOn,
    ].join(' · ');
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scheduleTitle)),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Text(
              l10n.scheduleIntro(c.name),
              style: TextStyle(color: pal.muted, fontSize: 14, height: 1.4),
            ),
            SectionTitle(l10n.scheduleMedicineSection),
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
                    title: Text(l10n.scheduleAddMedicine),
                    onTap: () => _addMedicine(context, c),
                  ),
                ],
              ),
            ),
            SectionTitle(l10n.scheduleRoutineSection),
            Card(
              child: Column(
                children: [
                  for (final (i, r) in c.routines.indexed)
                    ListTile(
                      leading: const BlobIcon(Kind.activity, size: 40),
                      title: Text(cap('${r['name']}'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text([when(r), if (s.pushEnabled && r['remind'] == true) l10n.scheduleReminderOn].join(' · ')),
                      trailing: const Icon(Icons.edit_outlined, size: 20),
                      onTap: () => _editRoutine(context, c, i),
                    ),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: pal.line,
                      child: Icon(Icons.add, color: pal.ink),
                    ),
                    title: Text(l10n.scheduleAddRoutine),
                    subtitle: c.routines.isEmpty ? Text(l10n.scheduleRoutineHint) : null,
                    onTap: () => _addRoutine(context, c),
                  ),
                ],
              ),
            ),
            SectionTitle(l10n.scheduleReminders),
            Card(
              child: Column(
                children: [
                  for (final type in _types)
                    () {
                      final r = c.reminders.where((r) => r['type'] == type).firstOrNull;
                      final kind = Kind.of(type == 'feed' ? 'feed' : type);
                      return ListTile(
                        leading: BlobIcon(kind, size: 40),
                        title: Text(_typeLabel(type), style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          r == null ? l10n.scheduleOff : l10n.scheduleWhenAfter(hm(r['after_minutes'] as int), type),
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
                  ? l10n.scheduleFooterPush
                  : s.serverless
                  ? l10n.scheduleFooterServerless
                  : l10n.scheduleFooterServer,
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

  /// Daily dose times ("HH:MM", sorted); used instead of "every" when [_fixed].
  late final List<String> _times = [for (final t in widget.medicine['times'] as List? ?? const []) '$t'];
  late bool _fixed = _times.isNotEmpty;
  late var _days = _Days.of(widget.medicine);
  String? _error;

  static num? _num(TextEditingController c) {
    final v = num.tryParse(c.text.trim().replaceAll(',', '.'));
    return v == null ? null : (v == v.roundToDouble() ? v.round() : v);
  }

  void _save() {
    final every = _num(_every), max = _num(_max), dose = _num(_dose);
    String? err;
    if (_name.text.trim().isEmpty) {
      err = l10n.scheduleErrName;
    } else if (_fixed && _times.isEmpty) {
      err = l10n.scheduleErrTimes;
    } else if (!_fixed && (every == null || every < 0.5 || every > 168)) {
      err = l10n.scheduleErrEvery;
    } else if (!_fixed && _max.text.trim().isNotEmpty && (max is! int || max < 1 || max > 24)) {
      err = l10n.scheduleErrMax;
    } else if (_dose.text.trim().isNotEmpty && dose == null) {
      err = l10n.scheduleErrDose;
    }
    if (err != null) return setState(() => _error = err);
    Navigator.pop(context, <String, dynamic>{
      'name': _name.text.trim(),
      // With set times these are unused but kept, for switching back (the server wants a spacing).
      'every_hours': _fixed && (every == null || every < 0.5 || every > 168) ? (24 / _times.length * 10).round() / 10 : every,
      if (!_fixed || (max is int && max >= 1 && max <= 24)) 'max_per_day': ?max,
      if (_fixed) 'times': _times,
      if (_fixed) ..._days.json,
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
      title: Text(widget.isNew ? l10n.scheduleAddMedicine : l10n.healthMedicine),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: l10n.scheduleName),
          ),
          const SizedBox(height: 14),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(l10n.scheduleModeAfterDose)),
              ButtonSegment(value: true, label: Text(l10n.scheduleModeTimes)),
            ],
            selected: {_fixed},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() {
              _fixed = v.first;
              if (_fixed && _times.isEmpty) _times.add('08:00');
            }),
          ),
          const SizedBox(height: 6),
          Text(l10n.scheduleModeHint(_fixed ? 'times' : 'after'), style: TextStyle(color: pal.muted, fontSize: 13, height: 1.3)),
          if (_fixed) ...[
            const SizedBox(height: 12),
            _TimesPicker(label: l10n.scheduleTimesLabel, times: _times, onChanged: () => setState(() {})),
            const SizedBox(height: 12),
            _DaysPicker(days: _days, onChanged: (d) => setState(() => _days = d)),
          ] else ...[
            const SizedBox(height: 12),
            TextField(
              controller: _every,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l10n.scheduleEvery, suffixText: l10n.scheduleHours),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final h in quick)
                  ChoiceChip(
                    label: Text(h == 24 ? l10n.scheduleDaily : '$h h'),
                    selected: _num(_every) == h,
                    onSelected: (_) => setState(() => _every.text = '$h'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _max,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.scheduleMaxLabel, suffixText: l10n.scheduleDoses),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _dose,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l10n.scheduleDoseLabel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _unit,
                  decoration: InputDecoration(labelText: l10n.scheduleUnit),
                ),
              ),
            ],
          ),
          if (widget.canRemind) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.scheduleRemindDue),
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
            child: Text(l10n.remove, style: TextStyle(color: pal.danger)),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}

/// The days a schedule at set times is due on: every day, every N days (`every_days`) or some
/// weekdays (`weekdays`, 1 = Monday).
class _Days {
  const _Days({this.everyDays, this.weekdays = const []});
  final int? everyDays;
  final List<int> weekdays;

  static _Days of(Map<String, dynamic> m) => _Days(
    everyDays: m['every_days'] is int && (m['every_days'] as int) > 1 ? m['every_days'] as int : null,
    weekdays: [for (final d in m['weekdays'] as List? ?? const []) d as int],
  );

  Map<String, dynamic> get json => {'every_days': ?everyDays, if (weekdays.isNotEmpty) 'weekdays': weekdays};
}

/// Set times as chips: tap one to change it, ✕ to remove it, "Add a time".
class _TimesPicker extends StatelessWidget {
  const _TimesPicker({required this.label, required this.times, required this.onChanged});
  final String label;

  /// Changed in place ("HH:MM", sorted), then [onChanged].
  final List<String> times;
  final VoidCallback onChanged;

  Future<void> _pick(BuildContext context, [int? index]) async {
    final [h, m] = [for (final p in (index == null ? (times.lastOrNull ?? '08:00') : times[index]).split(':')) int.parse(p)];
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: h, minute: m));
    if (t == null) return;
    final v = '${'${t.hour}'.padLeft(2, '0')}:${'${t.minute}'.padLeft(2, '0')}';
    if (index != null) times.removeAt(index);
    if (!times.contains(v)) times.add(v);
    times.sort();
    onChanged();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: context.pal.muted, fontSize: 12)),
      const SizedBox(height: 4),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (i, t) in times.indexed)
            InputChip(
              avatar: const Icon(Icons.schedule_rounded, size: 18),
              label: Text(SchedulesScreen.clock(t)),
              onPressed: () => _pick(context, i),
              onDeleted: () {
                times.removeAt(i);
                onChanged();
              },
            ),
          ActionChip(avatar: const Icon(Icons.add, size: 18), label: Text(l10n.scheduleAddTime), onPressed: () => _pick(context)),
        ],
      ),
    ],
  );
}

/// Every day, every N days (2–30) or some weekdays.
class _DaysPicker extends StatelessWidget {
  const _DaysPicker({required this.days, required this.onChanged});
  final _Days days;
  final ValueChanged<_Days> onChanged;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final mode = days.weekdays.isNotEmpty ? 'weekdays' : (days.everyDays != null ? 'every' : 'daily');
    final n = days.everyDays ?? 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.scheduleDaysLabel, style: TextStyle(color: pal.muted, fontSize: 12)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in const ['daily', 'every', 'weekdays'])
              ChoiceChip(
                label: Text(l10n.scheduleDaysMode(m)),
                selected: mode == m,
                onSelected: (_) => onChanged(switch (m) {
                  'every' => _Days(everyDays: n),
                  'weekdays' => _Days(weekdays: [DateTime.now().weekday]),
                  _ => const _Days(),
                }),
              ),
          ],
        ),
        if (mode == 'every') ...[
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: '−',
                onPressed: n > 2 ? () => onChanged(_Days(everyDays: n - 1)) : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: Text(l10n.scheduleEveryNDays(n), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              IconButton.filledTonal(
                tooltip: '+',
                onPressed: n < 30 ? () => onChanged(_Days(everyDays: n + 1)) : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          Text(l10n.scheduleEveryNDaysHint, style: TextStyle(color: pal.muted, fontSize: 13, height: 1.3)),
        ],
        if (mode == 'weekdays') ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(SchedulesScreen.weekdayName(d)),
                  showCheckmark: false,
                  selected: days.weekdays.contains(d),
                  // At least one day stays picked.
                  onSelected: (on) {
                    final next = [...days.weekdays.where((x) => x != d), if (on) d]..sort();
                    if (next.isNotEmpty) onChanged(_Days(weekdays: next));
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Edit a routine (an activity done every so often, e.g. a bath). Pops the new routine, `{}` to
/// remove it, or null.
class _RoutineDialog extends StatefulWidget {
  const _RoutineDialog({required this.routine, required this.isNew, required this.canRemind});
  final Map<String, dynamic> routine;
  final bool isNew, canRemind;

  @override
  State<_RoutineDialog> createState() => _RoutineDialogState();
}

class _RoutineDialogState extends State<_RoutineDialog> {
  late String _name = '${widget.routine['name'] ?? ''}';
  late final num _hours = widget.routine['every_hours'] as num? ?? 24;

  /// The interval in days when it is a whole number of days (the field then counts days).
  late bool _inDays = _hours >= 24 && _hours % 24 == 0;
  late final _every = TextEditingController(text: SchedulesScreen._n(_inDays ? _hours ~/ 24 : _hours));
  late final List<String> _times = [for (final t in widget.routine['times'] as List? ?? const []) '$t'];
  late bool _fixed = _times.isNotEmpty || widget.isNew;
  late var _days = _Days.of(widget.routine);
  late bool _remind = widget.routine['remind'] == true || (widget.isNew && widget.canRemind);
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_fixed && _times.isEmpty) _times.add('09:00');
  }

  num? get _everyHours {
    final v = num.tryParse(_every.text.trim().replaceAll(',', '.'));
    if (v == null) return null;
    final h = _inDays ? v * 24 : v;
    return h == h.roundToDouble() ? h.round() : h;
  }

  Future<void> _rename() async {
    final name = await showActivityPicker(context);
    if (name != null && mounted) setState(() => _name = name);
  }

  void _save() {
    final every = _everyHours;
    String? err;
    if (_fixed && _times.isEmpty) {
      err = l10n.scheduleErrTimes;
    } else if (!_fixed && (every == null || every < 0.5 || every > 720)) {
      err = l10n.scheduleErrEveryRoutine;
    }
    if (err != null) return setState(() => _error = err);
    Navigator.pop(context, <String, dynamic>{
      'name': _name,
      // With set times it is unused but kept, for switching back (the server wants one).
      'every_hours': every == null || every < 0.5 || every > 720 ? 24 : every,
      if (_fixed) 'times': _times,
      if (_fixed) ..._days.json,
      'remind': widget.canRemind ? _remind : widget.routine['remind'] == true,
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    // Quick picks, in hours.
    const quick = [4, 12, 24, 48, 72, 168];
    return AlertDialog(
      title: Text(widget.isNew ? l10n.scheduleAddRoutine : l10n.homeCardRoutine),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const BlobIcon(Kind.activity, size: 40),
            title: Text(cap(_name), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            trailing: const Icon(Icons.edit_outlined, size: 20),
            onTap: _rename,
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(l10n.scheduleModeAfterLast)),
              ButtonSegment(value: true, label: Text(l10n.scheduleModeTimes)),
            ],
            selected: {_fixed},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() {
              _fixed = v.first;
              if (_fixed && _times.isEmpty) _times.add('09:00');
            }),
          ),
          const SizedBox(height: 6),
          Text(l10n.scheduleRoutineModeHint(_fixed ? 'times' : 'after'), style: TextStyle(color: pal.muted, fontSize: 13, height: 1.3)),
          if (_fixed) ...[
            const SizedBox(height: 12),
            _TimesPicker(label: l10n.scheduleRoutineTimesLabel, times: _times, onChanged: () => setState(() {})),
            const SizedBox(height: 12),
            _DaysPicker(days: _days, onChanged: (d) => setState(() => _days = d)),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _every,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: l10n.scheduleEvery),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<bool>(
                  value: _inDays,
                  items: [
                    DropdownMenuItem(value: false, child: Text(l10n.scheduleHours)),
                    DropdownMenuItem(value: true, child: Text(l10n.scheduleDaysUnit)),
                  ],
                  onChanged: (v) => setState(() => _inDays = v ?? _inDays),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final h in quick)
                  ChoiceChip(
                    label: Text(h < 24 ? '$h h' : SchedulesScreen.every(h)),
                    selected: _everyHours == h,
                    onSelected: (_) => setState(() {
                      _inDays = h % 24 == 0;
                      _every.text = '${_inDays ? h ~/ 24 : h}';
                    }),
                  ),
              ],
            ),
          ],
          if (widget.canRemind) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.scheduleRemindRoutineDue),
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
            child: Text(l10n.remove, style: TextStyle(color: pal.danger)),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}
