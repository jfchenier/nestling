import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/date_time.dart';
import '../widgets/medicine_picker.dart';

/// Log a new event of [type] (feeds also take a [method]) or edit [event].
Future<void> showEventForm(BuildContext context, {String? type, String? method, Event? event}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: context.pal.background,
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
  late final String _method = widget.method ?? 'breast';
  late final _left = _minutes(e?['left_seconds']);
  late final _right = _minutes(e?['right_seconds']);
  late String? _startSide = e?['start_side'];
  late final _amount = _num(e?['amount_ml'], u.volumeIn);
  late String? _milk = e?['milk'] ?? (widget.method == 'bottle' || widget.method == 'combo' ? 'formula' : null);
  late final _formula = TextEditingController(text: e?['formula_name'] ?? '');
  late final _foods = TextEditingController(text: e?['foods'] ?? '');
  // sleep
  late String? _location = e?['location'];
  // diaper
  late bool _wet = e?['wet'] ?? true, _dirty = e?['dirty'] ?? false, _dry = e?['dry'] ?? false;
  late bool _rash = e?['rash'] ?? false, _blowout = e?['blowout'] ?? false;
  late String? _color = e?['color'], _consistency = e?['consistency'];
  // potty (diaper page, Potty tab): sat_dry / success / accident, then the same wet/dirty details.
  // A new entry opens on the tab of the last diaper/potty entry.
  late bool _pottyMode = e != null ? e!['potty'] != null : context.read<AppState>().summary?['last']?['diaper']?['potty'] != null;
  late String _potty = e?['potty'] ?? 'success';
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

  Kind get kind => Kind.of(widget.type, widget.type == 'diaper' && _pottyMode ? 'potty' : _method);

  String get _title => switch (widget.type) {
    'feed' => switch (_method) {
      'bottle' => 'Bottle Feed',
      'solids' => 'Solids',
      'combo' => 'Combo Feed',
      _ => 'Breastfeed',
    },
    'health' => cap(_healthKind),
    'milestone' => 'Baby First',
    'diaper' when _pottyMode => 'Potty',
    _ => kind.label,
  };

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
      case 'diaper' when _pottyMode:
        final dry = _potty == 'sat_dry';
        body.addAll({'potty': _potty, 'wet': !dry && _wet, 'dirty': !dry && _dirty, 'dry': dry, 'rash': _rash, 'blowout': !dry && _blowout});
        body['color'] = !dry && _dirty ? _color : null;
        body['consistency'] = !dry && _dirty ? _consistency : null;
      case 'diaper':
        body.addAll({'potty': null, 'wet': _wet, 'dirty': _dirty, 'dry': _dry, 'rash': _rash, 'blowout': _blowout});
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
    if (widget.type == 'diaper' && _pottyMode && _potty != 'sat_dry' && !_wet && !_dirty) {
      return showMessage(context, 'Was it wet, dirty or both?');
    }
    if (widget.type == 'diaper' && !_pottyMode && !_wet && !_dirty && !_dry) {
      return showMessage(context, 'Was the diaper wet, dirty or dry?');
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
    final c = context.pal;
    final k = kind;
    final strong = c.isDark ? k.fill(c) : k.deepTone;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92, maxWidth: 640),
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
                child: Row(
                  children: [
                    BlobIcon(k, size: 46),
                    const SizedBox(width: 14),
                    Expanded(child: Text(e == null ? _title : 'Edit ${_title.toLowerCase()}', style: serifStyle(24))),
                    if (e != null)
                      IconButton(onPressed: _delete, tooltip: 'Delete', icon: const Icon(Icons.delete_outline_rounded), color: c.danger),
                  ],
                ),
              ),
              Divider(height: 1, color: c.line),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ..._fields(),
                    FormRow(
                      label: widget.type == 'note' ? 'Note' : 'Notes',
                      below: TextField(
                        controller: _note,
                        maxLines: null,
                        minLines: widget.type == 'note' ? 4 : 1,
                        autofocus: widget.type == 'note' && e == null,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(hintText: 'Add a note…'),
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    style: FilledButton.styleFrom(backgroundColor: strong, foregroundColor: Colors.white),
                    child: Text(e == null ? 'Save' : 'Save changes'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Activity list (this child's own first, then the built-in ones, or a new name).
  Future<void> _chooseActivity() async {
    final a = await showActivityPicker(context);
    if (a != null && mounted) setState(() => _activityKind.text = a);
  }

  /// Foods list (several at once): foods already tried, usual first foods, or new ones.
  Future<void> _chooseFoods() async {
    final f = await showFoodPicker(context, splitFoods(_foods.text));
    if (f != null && mounted) setState(() => _foods.text = f.join(', '));
  }

  /// A row that opens a picker: the chosen value, or an accent "Choose".
  Widget _pickRow(String label, String value, VoidCallback onTap) => FormRow(
    label: label,
    onTap: onTap,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            value.isEmpty ? 'Choose' : value,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 17,
              color: value.isEmpty ? context.pal.accent : context.pal.ink,
              fontWeight: value.isEmpty ? FontWeight.w600 : null,
            ),
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: context.pal.muted),
      ],
    ),
  );

  /// Medicine list (recent first, then common, or a custom name); fills the last dose used.
  Future<void> _chooseMedicine() async {
    final m = await showMedicinePicker(context);
    if (m == null || !mounted) return;
    setState(() {
      _name.text = m.name;
      if (m.dose != null && _dose.text.isEmpty) _dose.text = m.dose == m.dose!.roundToDouble() ? '${m.dose!.round()}' : '${m.dose}';
      if (m.unit != null) _doseUnit.text = m.unit!;
    });
  }

  Widget _timeRow(String label, DateTime? value, ValueChanged<DateTime> set, {String placeholder = 'Add'}) => FormRow(
    label: label,
    child: DateTimeValue(value: value, onChanged: set, placeholder: placeholder),
  );

  Widget _numRow(String label, TextEditingController c, String? unit) => FormRow(
    label: label,
    child: InlineNumber(controller: c, unit: unit),
  );

  Widget _textRow(String label, TextEditingController c, {String hint = ''}) => FormRow(
    label: label,
    child: SizedBox(
      width: 200,
      child: TextField(
        controller: c,
        textAlign: TextAlign.right,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(fontSize: 17),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          filled: false,
          isDense: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    ),
  );

  Widget _chipsRow<T>(String label, Map<T, String> options, T? value, ValueChanged<T?> onChanged) => FormRow(
    label: label,
    below: ChoiceChips<T>(options: options, value: value, color: kind.fill(context.pal), onChanged: onChanged),
  );

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) => FormRow(
    label: label,
    onTap: () => onChanged(!value),
    child: Switch(value: value, onChanged: onChanged),
  );

  List<Widget> _fields() {
    switch (widget.type) {
      case 'feed':
        return [
          _timeRow('Start Time', _start, (v) => setState(() => _start = v)),
          if (_method == 'breast' || _method == 'combo') ...[
            _numRow('Left', _left, 'min'),
            _numRow('Right', _right, 'min'),
            _chipsRow<String>('Started on', const {'left': 'Left', 'right': 'Right'}, _startSide, (v) => setState(() => _startSide = v)),
          ],
          if (_method == 'bottle' || _method == 'combo') ...[
            _numRow('Amount', _amount, u.volumeUnit),
            _chipsRow<String>(
              'Milk',
              const {'formula': 'Formula', 'breast_milk': 'Breast milk', 'mixed': 'Mixed'},
              _milk,
              (v) => setState(() => _milk = v),
            ),
            if (_milk != 'breast_milk') _textRow('Formula', _formula, hint: 'Brand (optional)'),
          ],
          if (_method == 'solids') _pickRow('Foods', _foods.text, _chooseFoods),
        ];
      case 'sleep':
        return [
          _timeRow('Fell asleep', _start, (v) => setState(() => _start = v)),
          _timeRow('Woke up', _end, (v) => setState(() => _end = v)),
          FormRow(
            label: 'Total Time',
            child: Text(
              _end != null && _end!.isAfter(_start) ? duration(_end!.difference(_start).inSeconds) : '—',
              style: TextStyle(fontSize: 17, color: context.pal.muted),
            ),
          ),
          _chipsRow<String>(
            'Where',
            const {'crib': 'Crib', 'bassinet': 'Bassinet', 'bed': 'Bed', 'arms': 'Arms', 'stroller': 'Stroller', 'car': 'Car'},
            _location,
            (v) => setState(() => _location = v),
          ),
        ];
      case 'diaper':
        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Diaper'), icon: Icon(Icons.baby_changing_station_rounded)),
                ButtonSegment(value: true, label: Text('Potty'), icon: Icon(Icons.wc_rounded)),
              ],
              selected: {_pottyMode},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: kind.fill(context.pal),
                selectedForegroundColor: context.pal.bandInk,
                side: BorderSide(color: context.pal.line),
              ),
              onSelectionChanged: (v) => setState(() {
                _pottyMode = v.first;
                // A potty trip starts as "wet in the potty"; back on Diaper, a sat-but-dry trip
                // isn't a dry diaper.
                if (_pottyMode && !_wet && !_dirty) _wet = true;
              }),
            ),
          ),
          _timeRow('Time', _start, (v) => setState(() => _start = v)),
          if (_pottyMode) ..._pottyFields() else ..._diaperFields(),
        ];
      case 'pump':
        return [
          _timeRow('Start Time', _start, (v) => setState(() => _start = v)),
          _numRow('Left', _leftMl, u.volumeUnit),
          _numRow('Right', _rightMl, u.volumeUnit),
          _numRow('Duration', _pumpMinutes, 'min'),
        ];
      case 'growth':
        return [
          _timeRow('Measured', _start, (v) => setState(() => _start = v)),
          _numRow('Weight', _weight, u.weightUnit),
          _numRow('Height', _length, u.lengthUnit),
          _numRow('Head Size', _head, u.lengthUnit),
        ];
      case 'health':
        return [
          _chipsRow<String>(
            'Type',
            const {
              'medicine': 'Medicine',
              'temperature': 'Temperature',
              'vaccine': 'Vaccine',
              'symptom': 'Symptom',
              'appointment': 'Appointment',
            },
            _healthKind,
            (v) => setState(() => _healthKind = v ?? _healthKind),
          ),
          _timeRow('Time', _start, (v) => setState(() => _start = v)),
          if (_healthKind == 'temperature')
            _numRow('Temperature', _temp, u.tempUnit)
          else ...[
            if (_healthKind == 'medicine')
              _pickRow('Medicine', _name.text, _chooseMedicine)
            else
              _textRow(switch (_healthKind) {
                'vaccine' => 'Vaccine',
                'appointment' => 'Doctor',
                _ => 'Symptom',
              }, _name),
            if (_healthKind == 'medicine') ...[_numRow('Dose', _dose, null), _textRow('Unit', _doseUnit)],
          ],
        ];
      case 'activity':
        return [
          _pickRow('Activity', cap(_text(_activityKind)), _chooseActivity),
          _timeRow('Start Time', _start, (v) => setState(() => _start = v)),
          _numRow('Duration', _activityMinutes, 'min'),
        ];
      case 'milestone':
        return [
          FormRow(
            label: 'What happened?',
            below: TextField(
              controller: _name,
              autofocus: e == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'First smile, rolled over…'),
            ),
          ),
          _timeRow('When', _start, (v) => setState(() => _start = v)),
        ];
      default:
        return [_timeRow('Time', _start, (v) => setState(() => _start = v))];
    }
  }

  List<Widget> _diaperFields() => [
    Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.pal.line)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleToggle(
            label: 'wet',
            selected: _wet,
            onTap: () => setState(() {
              _wet = !_wet;
              if (_wet) _dry = false;
            }),
          ),
          const SizedBox(width: 20),
          CircleToggle(
            label: 'dirty',
            selected: _dirty,
            onTap: () => setState(() {
              _dirty = !_dirty;
              if (_dirty) _dry = false;
            }),
          ),
          const SizedBox(width: 20),
          CircleToggle(
            label: 'dry',
            selected: _dry,
            onTap: () => setState(() {
              _dry = !_dry;
              if (_dry) _wet = _dirty = false;
            }),
          ),
        ],
      ),
    ),
    if (_dirty) FormRow(label: 'Texture & Color', below: _textureAndColor()),
    _switchRow('Blowout', _blowout, (v) => setState(() => _blowout = v)),
    _switchRow('Diaper Rash', _rash, (v) => setState(() => _rash = v)),
  ];

  /// Potty tab: what happened (one of three), then wet/dirty with the diaper's details unless
  /// the baby stayed dry.
  List<Widget> _pottyFields() => [
    Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.pal.line)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final (i, (value, label, icon)) in pottyResults.indexed) ...[
            if (i > 0) const SizedBox(width: 16),
            CircleToggle(label: label, icon: icon, size: 96, selected: _potty == value, onTap: () => setState(() => _potty = value)),
          ],
        ],
      ),
    ),
    if (_potty != 'sat_dry') ...[
      FormRow(
        label: 'What came',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleToggle(label: 'wet', size: 60, selected: _wet, onTap: () => setState(() => _wet = !_wet)),
            const SizedBox(width: 12),
            CircleToggle(label: 'dirty', size: 60, selected: _dirty, onTap: () => setState(() => _dirty = !_dirty)),
          ],
        ),
      ),
      if (_dirty) FormRow(label: 'Texture & Color', below: _textureAndColor()),
      _switchRow('Blowout', _blowout, (v) => setState(() => _blowout = v)),
    ],
    _switchRow('Diaper Rash', _rash, (v) => setState(() => _rash = v)),
  ];

  Widget _textureAndColor() {
    const textures = ['runny', 'mucousy', 'mushy', 'solid', 'pebbles'];
    const colors = {
      'black': Color(0xFF4A2A12),
      'green': Color(0xFF7FA33A),
      'yellow': Color(0xFFE6BF4A),
      'brown': Color(0xFF7A4E1E),
      'red': Color(0xFFCF4535),
      'gray': Color(0xFFD5D5D5),
    };
    // Six swatches per row on a phone; the tile width follows the sheet width.
    final tile = ((MediaQuery.sizeOf(context).width.clamp(0, 640) - 40) / 6).floorToDouble().clamp(52.0, 80.0);
    Widget option(String label, bool selected, Widget art, VoidCallback onTap) => InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: tile,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? context.pal.accent : Colors.transparent, width: 1.5),
          color: selected ? context.pal.accent.withValues(alpha: 0.25) : null,
        ),
        child: Column(
          children: [
            SizedBox(width: tile * 0.62, height: tile * 0.62, child: art),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 4,
          children: [
            for (final t in textures)
              option(
                cap(t),
                _consistency == t,
                CustomPaint(painter: TexturePainter(t, context.pal.isDark ? const Color(0xFFE3DACB) : const Color(0xFFA8987F))),
                () => setState(() => _consistency = _consistency == t ? null : t),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 4,
          children: [
            for (final c in colors.entries)
              option(
                cap(c.key),
                _color == c.key,
                CustomPaint(painter: BlobPainter(c.value, stableSeed(c.key), wobble: 0.16)),
                () => setState(() => _color = _color == c.key ? null : c.key),
              ),
          ],
        ),
      ],
    );
  }
}
