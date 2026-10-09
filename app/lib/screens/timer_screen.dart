import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'event_form.dart';

/// Live timer for `breastfeed`, `sleep` or `pump`, shared with every caregiver.
class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key, required this.kind});
  final String kind;

  static Future<void> open(BuildContext context, String kind) =>
      Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => TimerScreen(kind: kind)));

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  bool _busy = false;
  String? _location;
  String _pumpSide = 'both';

  /// Start time picked before the timer runs (null = now).
  DateTime? _startAt;
  final _note = TextEditingController();

  Kind get kind => switch (widget.kind) {
    'sleep' => Kind.sleep,
    'pump' => Kind.pump,
    _ => Kind.breast,
  };
  String get title => switch (widget.kind) {
    'sleep' => 'Sleep',
    'pump' => 'Pump',
    _ => 'Nursing',
  };

  TimerModel? _timer(AppState s) => s.timers.where((t) => t.kind == widget.kind).firstOrNull;

  Future<void> _call(Future<dynamic> Function(AppState s) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    final s = context.read<AppState>();
    await guard(context, () => action(s));
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _start(AppState s, String? side) =>
      s.act(
    (api) => api.post('/children/${s.childId}/timers', {
      'kind': widget.kind,
      'side': ?side,
      if (_startAt != null) 'start': formatTime(_startAt!),
    }),
  );

  /// Start Time row: before starting, remembers the time; afterwards moves the running timer.
  Future<void> _editStart(TimerModel? t) async {
    final picked = await pickDateTime(context, t?.startedAt ?? _startAt ?? DateTime.now());
    if (picked == null || !mounted) return;
    if (picked.isAfter(DateTime.now())) return showMessage(context, 'The start can\'t be in the future.');
    if (t == null) return setState(() => _startAt = picked);
    await _call((s) => s.act((api) => api.patch('/timers/${t.id}', {'start': formatTime(picked)})));
  }

  /// Pencil under a side (nursing) or on Total Time (sleep, pump): correct the time.
  Future<void> _editTime(TimerModel t, [String? side]) async {
    final secs = switch (side) {
      'left' => t.left,
      'right' => t.right,
      _ => t.elapsed,
    };
    TextEditingController ctl(int v) => TextEditingController(text: '$v')..selection = TextSelection(baseOffset: 0, extentOffset: '$v'.length);
    final min = ctl(secs ~/ 60), sec = ctl(secs % 60);
    Widget field(TextEditingController c, String label, {bool autofocus = false, int digits = 3}) {
      // Typing replaces the current value: select it all when the field gets focus.
      final focus = FocusNode();
      focus.addListener(() {
        if (focus.hasFocus) {
          WidgetsBinding.instance.addPostFrameCallback((_) => c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length));
        }
      });
      return Expanded(
      child: TextField(
        controller: c,
        focusNode: focus,
        autofocus: autofocus,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(digits)],
        textAlign: TextAlign.center,
        style: serifStyle(28),
        decoration: InputDecoration(labelText: label),
      ),
    );
    }

    final total = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          switch (side) {
            'left' => 'Left side',
            'right' => 'Right side',
            _ => widget.kind == 'sleep' ? 'Time asleep' : 'Total time',
          },
          style: serifStyle(22),
        ),
        content: Row(children: [field(min, 'Minutes', autofocus: true), const SizedBox(width: 12), field(sec, 'Seconds', digits: 2)]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(c, (int.tryParse(min.text) ?? 0) * 60 + (int.tryParse(sec.text) ?? 0)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (total == null || !mounted) return;
    await _call((s) => s.act((api) => api.patch('/timers/${t.id}', {side == null ? 'seconds' : '${side}_seconds': total})));
  }

  /// A side's button: start, pause (same side), switch (other side) or resume.
  void _tapSide(TimerModel? t, String side) => _call((s) {
    if (t == null) return _start(s, side);
    if (!t.running) return s.act((api) => api.post('/timers/${t.id}/resume', {'side': side}));
    if (t.side == side) return s.act((api) => api.post('/timers/${t.id}/pause'));
    return s.act((api) => api.post('/timers/${t.id}/switch', {'side': side}));
  });

  void _toggle(TimerModel? t) => _call((s) {
    if (t == null) return _start(s, widget.kind == 'pump' ? _pumpSide : null);
    if (t.running) return s.act((api) => api.post('/timers/${t.id}/pause'));
    return s.act((api) => api.post('/timers/${t.id}/resume', widget.kind == 'pump' ? {'side': _pumpSide} : {}));
  });

  Future<void> _stop(TimerModel t, {DateTime? end}) async {
    final body = <String, dynamic>{if (end != null) 'end': formatTime(end)};
    if (_note.text.trim().isNotEmpty) body['note'] = _note.text.trim();
    if (widget.kind == 'sleep' && _location != null) body['location'] = _location;
    if (widget.kind == 'pump') {
      final amounts = await _askPumpAmounts(t);
      if (amounts == null) return;
      body.addAll(amounts);
    }
    if (!mounted) return;
    setState(() => _busy = true);
    final s = context.read<AppState>();
    final ok = await guard(context, () => s.act((api) => api.post('/timers/${t.id}/stop', body)));
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok != null) {
      showMessage(context, '$title saved');
      Navigator.pop(context);
    }
  }

  Future<Map<String, dynamic>?> _askPumpAmounts(TimerModel t) {
    final u = context.read<AppState>().units;
    final left = TextEditingController(), right = TextEditingController();
    double? read(TextEditingController c) {
      final v = double.tryParse(c.text.replaceAll(',', '.'));
      return v == null ? null : double.parse(u.volumeOut(v).toStringAsFixed(1));
    }

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('How much did you pump?', style: serifStyle(22)),
        content: Row(
          children: [
            if (t.side != 'right')
              Expanded(
                child: TextField(
                  controller: left,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Left', suffixText: u.volumeUnit),
                ),
              ),
            if (t.side == 'both') const SizedBox(width: 12),
            if (t.side != 'left')
              Expanded(
                child: TextField(
                  controller: right,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Right', suffixText: u.volumeUnit),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, {'left_ml': ?read(left), 'right_ml': ?read(right)}), child: const Text('Save')),
        ],
      ),
    );
  }

  Future<void> _stopEarlier(TimerModel t) async {
    final end = await pickDateTime(context, DateTime.now().subtract(const Duration(minutes: 5)));
    if (end == null || !mounted) return;
    if (!end.isAfter(t.startedAt)) return showMessage(context, 'The end must be after the start (${timeOfDay(t.startedAt)}).');
    await _stop(t, end: end);
  }

  Future<void> _delete(TimerModel t) async {
    if (!await confirm(context, 'Delete this timer?', 'Nothing will be saved.', action: 'Delete')) return;
    await _call((s) => s.act((api) => api.delete('/timers/${t.id}')));
    if (mounted) Navigator.pop(context);
  }

  /// Log a finished session by hand instead of timing it.
  void _manual() {
    Navigator.pop(context);
    showEventForm(context, type: widget.kind == 'breastfeed' ? 'feed' : widget.kind, method: 'breast');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = _timer(s);
    final c = context.pal;
    final strong = c.isDark ? kind.fill(c) : kind.deepTone;
    return Scaffold(
      backgroundColor: Color.lerp(c.background, kind.fill(c), c.isDark ? 0.25 : 0.3),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        // Closing never stops the timer: it keeps running (for every caregiver) until saved or deleted.
        leading: IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'Close', onPressed: () => Navigator.pop(context)),
        title: Text(title),
        actions: [
          if (t == null) TextButton(onPressed: _manual, child: const Text('Log past')),
          if (t != null) ...[
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: strong,
                foregroundColor: Colors.white,
                minimumSize: const Size(80, 40),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onPressed: _busy ? null : () => _stop(t),
              child: const Text('Save'),
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (_) => _stopEarlier(t),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'earlier', child: Text(widget.kind == 'sleep' ? 'Woke up earlier…' : 'Ended earlier…')),
              ],
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Constrained(
          maxWidth: 520,
          child: Ticking(
            builder: (context) => ListView(
              children: [
                const SizedBox(height: 4),
                _hint(s, t),
                const SizedBox(height: 12),
                Text(
                  clock(t?.elapsed ?? 0),
                  textAlign: TextAlign.center,
                  style: serifStyle(64, weight: FontWeight.w600).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
                Text(
                  t == null
                      ? (widget.kind == 'breastfeed' ? 'Tap a side to start' : 'Tap to start')
                      : !t.running
                      ? 'Paused'
                      : widget.kind == 'breastfeed'
                      ? 'On the ${t.side}'
                      : widget.kind == 'sleep'
                      ? 'Sleeping'
                      : 'Pumping',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted, fontSize: 16),
                ),
                const SizedBox(height: 28),
                if (widget.kind == 'breastfeed')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [_side(t, 'left'), _side(t, 'right')],
                  )
                else ...[
                  if (widget.kind == 'pump') ...[
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: _pumpSides(t)),
                    const SizedBox(height: 24),
                  ],
                  Center(child: _bigButton(t)),
                  if (widget.kind == 'sleep') ...[
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ChoiceChips<String>(
                        options: const {
                          'crib': 'Crib',
                          'bassinet': 'Bassinet',
                          'bed': 'Bed',
                          'arms': 'Arms',
                          'stroller': 'Stroller',
                          'car': 'Car',
                        },
                        value: _location,
                        color: kind.fill(c),
                        onChanged: (v) => setState(() => _location = v),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                _timeRows(t),
                const SizedBox(height: 16),
                if (t != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextField(
                      controller: _note,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Note (optional)', prefixIcon: Icon(Icons.edit_note_rounded)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Close with ✕ and the timer keeps running.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.muted, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      style: TextButton.styleFrom(foregroundColor: c.danger, textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      onPressed: _busy ? null : () => _delete(t),
                      child: const Text('Delete'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "Last feed ended on the left · 2h ago — start on the right" / "Awake for 45m".
  Widget _hint(AppState s, TimerModel? t) {
    String? hint;
    if (t == null && widget.kind == 'breastfeed') {
      final last = s.summary?['last']?['feed'];
      final e = last is Map<String, dynamic> ? Event(last) : null;
      final end = e?.endSide;
      if (end != null) {
        hint =
            'Last feed ended on the $end · ${ago(DateTime.now().difference(e!.start).inSeconds)}\nStart on the ${end == 'left' ? 'right' : 'left'}';
      }
    } else if (t == null && widget.kind == 'sleep') {
      final last = s.summary?['last']?['sleep'];
      final e = last is Map<String, dynamic> ? Event(last) : null;
      if (e?.end != null) hint = 'Awake for ${duration(DateTime.now().difference(e!.end!).inSeconds)}';
    }
    return SizedBox(
      height: 48,
      child: hint == null ? null : Text(hint, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.4)),
    );
  }

  /// Start Time (editable) and Total Time rows.
  Widget _timeRows(TimerModel? t) {
    final c = context.pal;
    final start = t?.startedAt ?? _startAt;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          FormRow(
            label: widget.kind == 'sleep' ? 'Fell asleep' : 'Start Time',
            onTap: _busy ? null : () => _editStart(t),
            child: Text(
              start == null ? 'Now' : '${dayLabel(start)}   ${timeOfDay(start)}',
              style: TextStyle(fontSize: 17, color: start == null ? c.accent : c.ink, fontWeight: start == null ? FontWeight.w600 : null),
            ),
          ),
          FormRow(
            label: 'Total Time',
            onTap: t == null || _busy || widget.kind == 'breastfeed' ? null : () => _editTime(t),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(duration(t?.elapsed ?? 0, showSeconds: true), style: TextStyle(fontSize: 17, color: c.ink)),
                // Nursing time is the sum of the sides, edited with their pencils.
                if (t != null && widget.kind != 'breastfeed') ...[
                  const SizedBox(width: 8),
                  Icon(Icons.edit_rounded, size: 20, color: kind.on(c), semanticLabel: 'Edit total time'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A side: its round button, then the time on that side with a pencil to correct it.
  Widget _side(TimerModel? t, String side) {
    final c = context.pal;
    final seconds = (side == 'left' ? t?.left : t?.right) ?? 0;
    final name = side == 'left' ? 'left' : 'right';
    return Column(
      children: [
        _circle(t, side),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${seconds ~/ 60}m ${(seconds % 60).toString().padLeft(2, '0')}s',
              style: serifStyle(20, weight: FontWeight.w600).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            // Only once there's a timer to correct; keeps its space so nothing jumps.
            Visibility.maintain(
              visible: t != null,
              child: IconButton(
                tooltip: 'Edit $name time',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.edit_rounded, size: 20, color: kind.on(c)),
                onPressed: t == null || _busy ? null : () => _editTime(t, side),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Big round side button: start, pause (same side), switch (other side) or resume.
  Widget _circle(TimerModel? t, String side) {
    final c = context.pal;
    final active = t != null && t.running && t.side == side;
    final current = t != null && t.side == side;
    final strong = c.isDark ? kind.fill(c) : kind.deepTone;
    final name = side == 'left' ? 'left' : 'right';
    final action = t == null
        ? 'Start $name'
        : active
        ? 'Pause $name'
        : t.running
        ? 'Switch to $name'
        : 'Resume $name';
    return Semantics(
      button: true,
      label: action,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _busy ? null : () => _tapSide(t, side),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 128,
          height: 128,
          decoration: BoxDecoration(
            color: active ? strong : c.surface,
            shape: BoxShape.circle,
            border: Border.all(color: active || current ? strong : kind.fill(c), width: 4),
            boxShadow: [
              BoxShadow(
                color: strong.withValues(alpha: active ? 0.35 : 0.1),
                blurRadius: active ? 24 : 8,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(side == 'left' ? 'Left' : 'Right', style: serifStyle(28, color: active ? Colors.white : kind.on(c))),
              const SizedBox(height: 4),
              Icon(active ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 30, color: active ? Colors.white : kind.on(c)),
            ],
          ),
        ),
      ),
    );
  }

  /// Sleep / pump: one big start / pause / resume button.
  Widget _bigButton(TimerModel? t) {
    final c = context.pal;
    final running = t?.running ?? false;
    final strong = c.isDark ? kind.fill(c) : kind.deepTone;
    return Semantics(
      button: true,
      label: t == null ? 'Start' : (running ? 'Pause' : 'Resume'),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _busy ? null : () => _toggle(t),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            color: running ? strong : c.surface,
            shape: BoxShape.circle,
            border: Border.all(color: strong, width: 4),
            boxShadow: [
              BoxShadow(
                color: strong.withValues(alpha: running ? 0.35 : 0.12),
                blurRadius: running ? 28 : 10,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(kind.icon, size: 48, color: running ? Colors.white : kind.on(c)),
              const SizedBox(height: 6),
              Text(
                t == null ? 'Start' : (running ? 'Pause' : 'Resume'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: running ? Colors.white : kind.on(c)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pumpSides(TimerModel? t) => SegmentedButton<String>(
    segments: const [
      ButtonSegment(value: 'left', label: Text('Left')),
      ButtonSegment(value: 'both', label: Text('Both')),
      ButtonSegment(value: 'right', label: Text('Right')),
    ],
    selected: {t?.side ?? _pumpSide},
    showSelectedIcon: false,
    onSelectionChanged: (v) {
      setState(() => _pumpSide = v.first);
      if (t != null && t.running) _call((s) => s.act((api) => api.post('/timers/${t.id}/switch', {'side': v.first})));
    },
  );
}
