import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Log a new event of [type] (feeds also take a [method]) or edit [event].
Future<void> showEventForm(BuildContext context, {String? type, String? method, Event? event}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => EventForm(type: event?.type ?? type!, method: event?['method'] ?? method, event: event),
);

class EventForm extends StatefulWidget {
  const EventForm({super.key, required this.type, this.method, this.event});
  final String type;
  final String? method;
  final Event? event;

  @override
  State<EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  Event? get e => widget.event;
  late final Units u = context.read<AppState>().units;

  // A new sleep defaults to "the last hour" since sleeps in progress use the timer.
  late DateTime _start = e?.start ?? (widget.type == 'sleep' ? DateTime.now().subtract(const Duration(hours: 1)) : DateTime.now());
  late DateTime? _end = e?.end ?? (widget.type == 'sleep' ? DateTime.now() : null);
  late final _note = TextEditingController(text: e?.note ?? '');
  bool _busy = false;

  // feed
  late String _method = widget.method ?? 'breast';
  late final _left = _minutes(e?['left_seconds']);
  late final _right = _minutes(e?['right_seconds']);
  late String? _startSide = e?['start_side'];
  late final _amount = _num(e?['amount_ml'], u.volumeIn);
  late String? _milk = e?['milk'] ?? (widget.method == 'bottle' ? 'formula' : null);
  late final _formula = TextEditingController(text: e?['formula_name'] ?? '');
  late final _foods = TextEditingController(text: e?['foods'] ?? '');
  // sleep
  late String? _location = e?['location'];
  // diaper
  late bool _wet = e?['wet'] ?? true, _dirty = e?['dirty'] ?? false, _dry = e?['dry'] ?? false;
  late bool _rash = e?['rash'] ?? false, _blowout = e?['blowout'] ?? false;
  late String? _color = e?['color'], _consistency = e?['consistency'];
  // pump
  late final _leftMl = _num(e?['left_ml'], u.volumeIn);
  late final _rightMl = _num(e?['right_ml'], u.volumeIn);
  late final _pumpMinutes = _minutes(e?.durationSeconds);
  // growth
  late final _weight = _num(e?['weight_g'], u.weightIn, digits: 3);
  late final _length = _num(e?['length_cm'], u.lengthIn);
  late final _head = _num(e?['head_cm'], u.lengthIn);
  // health
  late String _healthKind = e?['kind'] ?? 'medicine';
  late final _name = TextEditingController(text: e?['name'] ?? '');
  late final _dose = _num(e?['dose'], (v) => v);
  late final _doseUnit = TextEditingController(text: e?['dose_unit'] ?? 'mL');
  late final _temp = _num(e?['temperature_c'], u.tempIn);
  // activity
  late final _activityKind = TextEditingController(text: e?['kind'] ?? '');
  late final _activityMinutes = _minutes(e?.durationSeconds);

  static TextEditingController _minutes(dynamic seconds) {
    final s = toInt(seconds);
    return TextEditingController(text: s == null || s == 0 ? '' : (s / 60).round().toString());
  }

  static TextEditingController _num(dynamic metric, double Function(double) conv, {int digits = 1}) {
    final v = toDouble(metric);
    if (v == null) return TextEditingController();
    final s = conv(v).toStringAsFixed(digits);
    return TextEditingController(text: s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s);
  }

  static double? _read(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));
  static String? _text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Kind get kind => Kind.of(widget.type, _method);

  Map<String, dynamic> _body() {
    final body = <String, dynamic>{'type': widget.type, 'start': formatTime(_start), 'note': _text(_note)};
    double? out(TextEditingController c, double Function(double) conv) {
      final v = _read(c);
      return v == null ? null : double.parse(conv(v).toStringAsFixed(2));
    }

    int? secs(TextEditingController c) {
      final v = _read(c);
      return v == null || v <= 0 ? null : (v * 60).round();
    }

    switch (widget.type) {
      case 'feed':
        body['method'] = _method;
        final l = secs(_left), r = secs(_right);
        final nursing = _method == 'breast' || _method == 'combo';
        body['left_seconds'] = nursing ? l : null;
        body['right_seconds'] = nursing ? r : null;
        body['start_side'] = nursing
            ? (_startSide ??
                  (l != null
                      ? 'left'
                      : r != null
                      ? 'right'
                      : null))
            : null;
        final bottle = _method == 'bottle' || _method == 'combo';
        body['amount_ml'] = bottle ? out(_amount, u.volumeOut) : null;
        body['milk'] = bottle ? _milk : null;
        body['formula_name'] = bottle && _milk != 'breast_milk' ? _text(_formula) : null;
        body['foods'] = _method == 'solids' ? _text(_foods) : null;
        final total = (l ?? 0) + (r ?? 0);
        body['end'] = nursing && total > 0 ? formatTime(_start.add(Duration(seconds: total))) : null;
      case 'sleep':
        body['end'] = _end == null ? null : formatTime(_end!);
        body['location'] = _location;
      case 'diaper':
        body.addAll({'wet': _wet, 'dirty': _dirty, 'dry': _dry, 'rash': _rash, 'blowout': _blowout});
        body['color'] = _dirty ? _color : null;
        body['consistency'] = _dirty ? _consistency : null;
      case 'pump':
        body['left_ml'] = out(_leftMl, u.volumeOut);
        body['right_ml'] = out(_rightMl, u.volumeOut);
        final s = secs(_pumpMinutes);
        body['end'] = s == null ? null : formatTime(_start.add(Duration(seconds: s)));
      case 'growth':
        body['weight_g'] = out(_weight, u.weightOut);
        body['length_cm'] = out(_length, u.lengthOut);
        body['head_cm'] = out(_head, u.lengthOut);
      case 'health':
        body['kind'] = _healthKind;
        if (_healthKind == 'temperature') {
          body['temperature_c'] = out(_temp, u.tempOut);
        } else {
          body['name'] = _text(_name);
          if (_healthKind == 'medicine') {
            body['dose'] = _read(_dose);
            body['dose_unit'] = _text(_doseUnit);
          }
        }
      case 'activity':
        body['kind'] = _text(_activityKind) ?? 'activity';
        final s = secs(_activityMinutes);
        body['end'] = s == null ? null : formatTime(_start.add(Duration(seconds: s)));
      case 'milestone':
        body['name'] = _text(_name);
    }
    if (e == null) body.removeWhere((k, v) => v == null);
    return body;
  }

  Future<void> _save() async {
    if (widget.type == 'sleep' && _end == null) {
      return showMessage(context, 'When did the sleep end? Use the sleep timer for a nap in progress.');
    }
    setState(() => _busy = true);
    final s = context.read<AppState>();
    final body = _body();
    final ok = await guard(
      context,
      () => s.act((api) => e == null ? api.post('/children/${s.childId}/events', body) : api.patch('/events/${e!.id}', body)),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok != null) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Delete this entry?', 'It will be removed for everyone in the family.')) return;
    if (!mounted) return;
    final s = context.read<AppState>();
    final ok = await guard(context, () => s.act((api) => api.delete('/events/${e!.id}')).then((_) => true));
    if (ok == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final k = kind;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Constrained(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Row(
              children: [
                KindBadge(k, size: 48),
                const SizedBox(width: 14),
                Expanded(child: Text(e == null ? k.label : 'Edit ${k.label.toLowerCase()}', style: t.titleLarge)),
                if (e != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline), color: Palette.danger),
              ],
            ),
            const SizedBox(height: 20),
            ..._fields(),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: widget.type == 'note' ? 'Note' : 'Note (optional)'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: k.deep),
              child: Text(e == null ? 'Save' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _fields() {
    const gap = SizedBox(height: 14);
    final k = kind;
    switch (widget.type) {
      case 'feed':
        return [
          if (e == null || e!['method'] != 'combo')
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'breast', label: Text('Nursing')),
                ButtonSegment(value: 'bottle', label: Text('Bottle')),
                ButtonSegment(value: 'solids', label: Text('Solids')),
              ],
              selected: {_method == 'combo' ? 'breast' : _method},
              onSelectionChanged: (v) => setState(() => _method = v.first),
              showSelectedIcon: false,
            ),
          gap,
          _TimeField(label: 'Started', value: _start, onChanged: (v) => setState(() => _start = v)),
          gap,
          if (_method == 'breast' || _method == 'combo') ...[
            Row(
              children: [
                Expanded(child: _numField(_left, 'Left', 'min')),
                const SizedBox(width: 12),
                Expanded(child: _numField(_right, 'Right', 'min')),
              ],
            ),
            gap,
            _label('Started on'),
            ChoiceChips<String>(
              options: const {'left': 'Left', 'right': 'Right'},
              value: _startSide,
              color: k.color,
              onChanged: (v) => setState(() => _startSide = v),
            ),
            gap,
          ],
          if (_method == 'bottle' || _method == 'combo') ...[
            _numField(_amount, 'Amount', u.volumeUnit),
            gap,
            ChoiceChips<String>(
              options: const {'formula': 'Formula', 'breast_milk': 'Breast milk', 'mixed': 'Mixed'},
              value: _milk,
              color: k.color,
              onChanged: (v) => setState(() => _milk = v),
            ),
            if (_milk != 'breast_milk') ...[
              gap,
              TextField(
                controller: _formula,
                decoration: const InputDecoration(labelText: 'Formula brand (optional)'),
              ),
            ],
          ],
          if (_method == 'solids')
            TextField(
              controller: _foods,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Foods', hintText: 'Avocado, banana…'),
            ),
        ];
      case 'sleep':
        return [
          _TimeField(label: 'Fell asleep', value: _start, onChanged: (v) => setState(() => _start = v)),
          gap,
          _TimeField(label: 'Woke up', value: _end, placeholder: 'Set wake-up time', onChanged: (v) => setState(() => _end = v)),
          if (_end != null && _end!.isAfter(_start))
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text('Slept ${duration(_end!.difference(_start).inSeconds)}', style: const TextStyle(color: Palette.muted)),
            ),
          gap,
          _label('Where'),
          ChoiceChips<String>(
            options: const {'crib': 'Crib', 'bassinet': 'Bassinet', 'bed': 'Bed', 'arms': 'Arms', 'stroller': 'Stroller', 'car': 'Car'},
            value: _location,
            color: k.color,
            onChanged: (v) => setState(() => _location = v),
          ),
        ];
      case 'diaper':
        return [
          _TimeField(label: 'Time', value: _start, onChanged: (v) => setState(() => _start = v)),
          gap,
          Row(
            children: [
              _bigToggle(
                'Wet',
                Icons.water_drop_outlined,
                _wet,
                () => setState(() {
                  _wet = !_wet;
                  if (_wet) _dry = false;
                }),
              ),
              const SizedBox(width: 10),
              _bigToggle(
                'Dirty',
                Icons.circle,
                _dirty,
                () => setState(() {
                  _dirty = !_dirty;
                  if (_dirty) _dry = false;
                }),
              ),
              const SizedBox(width: 10),
              _bigToggle(
                'Dry',
                Icons.check_circle_outline,
                _dry,
                () => setState(() {
                  _dry = !_dry;
                  if (_dry) _wet = _dirty = false;
                }),
              ),
            ],
          ),
          if (_dirty) ...[
            gap,
            _label('Color'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in const {
                  'yellow': Color(0xFFE8C547),
                  'green': Color(0xFF8BA644),
                  'brown': Color(0xFF8B5E3C),
                  'black': Color(0xFF2B2B2B),
                  'red': Color(0xFFC0392B),
                  'gray': Color(0xFFB0B0B0),
                }.entries)
                  GestureDetector(
                    onTap: () => setState(() => _color = _color == c.key ? null : c.key),
                    child: Tooltip(
                      message: cap(c.key),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c.value,
                          shape: BoxShape.circle,
                          border: Border.all(color: _color == c.key ? Palette.ink : Colors.white, width: 3),
                          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 3)],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            gap,
            _label('Consistency'),
            ChoiceChips<String>(
              options: const {'runny': 'Runny', 'mushy': 'Mushy', 'mucousy': 'Mucousy', 'pebbles': 'Pebbles', 'solid': 'Solid'},
              value: _consistency,
              color: k.color,
              onChanged: (v) => setState(() => _consistency = v),
            ),
          ],
          gap,
          Wrap(
            spacing: 8,
            children: [
              FilterChip(label: const Text('Rash'), selected: _rash, selectedColor: k.color, onSelected: (v) => setState(() => _rash = v)),
              FilterChip(
                label: const Text('Blowout'),
                selected: _blowout,
                selectedColor: k.color,
                onSelected: (v) => setState(() => _blowout = v),
              ),
            ],
          ),
        ];
      case 'pump':
        return [
          _TimeField(label: 'Started', value: _start, onChanged: (v) => setState(() => _start = v)),
          gap,
          Row(
            children: [
              Expanded(child: _numField(_leftMl, 'Left', u.volumeUnit)),
              const SizedBox(width: 12),
              Expanded(child: _numField(_rightMl, 'Right', u.volumeUnit)),
            ],
          ),
          gap,
          _numField(_pumpMinutes, 'Duration', 'min'),
        ];
      case 'growth':
        return [
          _TimeField(label: 'Measured', value: _start, onChanged: (v) => setState(() => _start = v)),
          gap,
          _numField(_weight, 'Weight', u.weightUnit),
          gap,
          Row(
            children: [
              Expanded(child: _numField(_length, 'Length', u.lengthUnit)),
              const SizedBox(width: 12),
              Expanded(child: _numField(_head, 'Head', u.lengthUnit)),
            ],
          ),
        ];
      case 'health':
        return [
          ChoiceChips<String>(
            options: const {
              'medicine': 'Medicine',
              'temperature': 'Temperature',
              'vaccine': 'Vaccine',
              'symptom': 'Symptom',
              'appointment': 'Appointment',
            },
            value: _healthKind,
            color: k.color,
            onChanged: (v) => setState(() => _healthKind = v ?? _healthKind),
          ),
          gap,
          _TimeField(label: 'Time', value: _start, onChanged: (v) => setState(() => _start = v)),
          gap,
          if (_healthKind == 'temperature')
            _numField(_temp, 'Temperature', u.tempUnit)
          else ...[
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: switch (_healthKind) {
                  'medicine' => 'Medicine',
                  'vaccine' => 'Vaccine',
                  'appointment' => 'Doctor / clinic',
                  _ => 'Symptom',
                },
              ),
            ),
            if (_healthKind == 'medicine') ...[
              gap,
              Row(
                children: [
                  Expanded(child: _numField(_dose, 'Dose', null)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _doseUnit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ];
      case 'activity':
        return [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in const ['bath', 'tummy_time', 'outdoor', 'play', 'read', 'nail_trim', 'vitamin'])
                ChoiceChip(
                  label: Text(cap(a)),
                  selected: _activityKind.text == a,
                  selectedColor: k.color,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _activityKind.text = a),
                ),
            ],
          ),
          gap,
          TextField(
            controller: _activityKind,
            decoration: const InputDecoration(labelText: 'Activity'),
            onChanged: (_) => setState(() {}),
          ),
          gap,
          _TimeField(label: 'Started', value: _start, onChanged: (v) => setState(() => _start = v)),
          gap,
          _numField(_activityMinutes, 'Duration', 'min'),
        ];
      case 'milestone':
        return [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Milestone', hintText: 'First smile, rolled over…'),
          ),
          gap,
          _TimeField(label: 'When', value: _start, onChanged: (v) => setState(() => _start = v)),
        ];
      default:
        return [_TimeField(label: 'Time', value: _start, onChanged: (v) => setState(() => _start = v))];
    }
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(color: Palette.muted, fontWeight: FontWeight.w600),
    ),
  );

  Widget _numField(TextEditingController c, String label, String? unit) => TextField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
    decoration: InputDecoration(labelText: label, suffixText: unit),
  );

  Widget _bigToggle(String label, IconData icon, bool on, VoidCallback onTap) {
    final k = kind;
    return Expanded(
      child: Material(
        color: on ? k.color : Palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: on ? k.deep : Palette.line, width: on ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Icon(icon, color: on ? k.deep : Palette.muted),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w600, color: on ? k.deep : Palette.ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tappable date + time field.
class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.value, required this.onChanged, this.placeholder});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String? placeholder;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: () => pickDateTime(context, value ?? DateTime.now()).then((v) => v == null ? null : onChanged(v)),
    child: InputDecorator(
      decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.schedule_rounded)),
      child: Text(
        value == null ? (placeholder ?? '') : '${dayLabel(value!)}, ${DateFormat.jm().format(value!)}',
        style: TextStyle(color: value == null ? Palette.muted : Palette.ink),
      ),
    ),
  );
}

Future<DateTime?> pickDateTime(BuildContext context, DateTime initial) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: initial.isAfter(now) ? now : initial,
    firstDate: DateTime(2000),
    lastDate: now,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
