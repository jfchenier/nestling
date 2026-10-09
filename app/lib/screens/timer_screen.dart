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
  final _note = TextEditingController();

  Kind get kind => switch (widget.kind) {
    'sleep' => Kind.sleep,
    'pump' => Kind.pump,
    _ => Kind.breast,
  };
  String get title => switch (widget.kind) {
    'sleep' => 'Sleep',
    'pump' => 'Pump',
    _ => 'Breastfeed',
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
      s.act((api) => api.post('/children/${s.childId}/timers', {'kind': widget.kind, 'side': ?side}));

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

  Future<void> _discard(TimerModel t) async {
    if (!await confirm(context, 'Discard this timer?', 'Nothing will be saved.', action: 'Discard')) return;
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
    return Scaffold(
      body: Column(
        children: [
          SheetHeader(title: title, color: kind.fill(context.pal), onSave: t == null || _busy ? null : () => _stop(t)),
          Expanded(
            child: Constrained(
              child: Ticking(
                builder: (context) => ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: context.pal.line)),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                      child: switch (widget.kind) {
                        'breastfeed' => _breast(s, t),
                        _ => _single(t),
                      },
                    ),
                    FormRow(
                      label: 'Start Time',
                      child: t == null
                          ? TextButton(
                              onPressed: _manual,
                              child: const Text('Log past', style: TextStyle(fontWeight: FontWeight.w700)),
                            )
                          : Text('${dayLabel(t.startedAt)}   ${timeOfDay(t.startedAt)}', style: const TextStyle(fontSize: 17)),
                    ),
                    FormRow(
                      label: 'Total Time',
                      child: Text(
                        duration(t?.elapsed ?? 0, showSeconds: true),
                        style: TextStyle(fontSize: 17, color: t == null ? context.pal.muted : context.pal.ink),
                      ),
                    ),
                    if (widget.kind == 'sleep')
                      FormRow(
                        label: 'Where',
                        below: ChoiceChips<String>(
                          options: const {
                            'crib': 'Crib',
                            'bassinet': 'Bassinet',
                            'bed': 'Bed',
                            'arms': 'Arms',
                            'stroller': 'Stroller',
                            'car': 'Car',
                          },
                          value: _location,
                          color: kind.fill(context.pal),
                          onChanged: (v) => setState(() => _location = v),
                        ),
                      ),
                    FormRow(
                      label: 'Notes',
                      below: TextField(
                        controller: _note,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(hintText: 'Saved with the entry'),
                      ),
                    ),
                    if (t != null) ...[
                      FormRow(
                        label: widget.kind == 'sleep' ? 'Woke up earlier?' : 'Ended earlier?',
                        value: 'Set time',
                        onTap: () => _stopEarlier(t),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: _busy ? null : () => _discard(t),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Discard timer'),
                            style: TextButton.styleFrom(foregroundColor: context.pal.danger),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Two columns: L and R counters with start/pause/switch buttons and a "last side" tag.
  Widget _breast(AppState s, TimerModel? t) {
    String? lastSide;
    if (t == null) {
      final last = s.summary?['last']?['feed'];
      lastSide = last is Map<String, dynamic> ? Event(last).endSide : null;
    }
    Widget column(String side) {
      final seconds = side == 'left' ? (t?.left ?? 0) : (t?.right ?? 0);
      final active = t != null && t.running && t.side == side;
      final label = side == 'left' ? 'Left' : 'Right';
      final action = t == null
          ? 'Start $label'
          : active
          ? 'Pause'
          : t.running
          ? 'Switch to $label'
          : 'Resume $label';
      return Expanded(
        child: Column(
          children: [
            SizedBox(
              height: 38,
              child: lastSide == side || (t != null && t.side == side)
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: kind.fill(context.pal).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(t == null ? 'last side' : (active ? 'now' : 'paused'), style: serifStyle(19)),
                    )
                  : null,
            ),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(clock(seconds), style: serifStyle(52, height: 1, color: active ? kind.on(context.pal) : context.pal.ink)),
                  if (t == null)
                    IconButton(
                      onPressed: _manual,
                      tooltip: 'Enter minutes',
                      icon: Icon(Icons.edit_outlined, color: context.pal.ink),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            PillButton(label: action, active: active, color: kind.fill(context.pal), onTap: _busy ? null : () => _tapSide(t, side)),
          ],
        ),
      );
    }

    return Row(children: [column('left'), const SizedBox(width: 12), column('right')]);
  }

  /// Sleep and pump: one big counter and a start / pause / resume button.
  Widget _single(TimerModel? t) {
    final running = t?.running ?? false;
    return Column(
      children: [
        if (widget.kind == 'pump') ...[
          SegmentedButton<String>(
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
          ),
          const SizedBox(height: 20),
        ],
        BlobIcon(kind, size: 84),
        const SizedBox(height: 12),
        Text(clock(t?.elapsed ?? 0), style: serifStyle(64, height: 1, color: running ? kind.on(context.pal) : context.pal.ink)),
        const SizedBox(height: 6),
        Text(
          t == null
              ? (widget.kind == 'sleep' ? 'Tap start when baby falls asleep' : 'Tap start when you begin')
              : (running ? 'Running' : 'Paused'),
          style: TextStyle(color: context.pal.muted),
        ),
        const SizedBox(height: 22),
        PillButton(
          label: t == null ? 'Start' : (running ? 'Pause' : 'Resume'),
          active: running,
          color: kind.fill(context.pal),
          onTap: _busy ? null : () => _toggle(t),
        ),
      ],
    );
  }
}
