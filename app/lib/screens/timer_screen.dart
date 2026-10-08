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
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => TimerScreen(kind: kind)));

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  bool _busy = false;
  String? _location;
  String _pumpSide = 'both';

  Kind get kind => switch (widget.kind) {
    'sleep' => Kind.sleep,
    'pump' => Kind.pump,
    _ => Kind.breast,
  };
  String get title => switch (widget.kind) {
    'sleep' => 'Sleep',
    'pump' => 'Pumping',
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
      s.act((api) => api.post('/children/${s.childId}/timers', {'kind': widget.kind, 'side': ?side}));

  /// Tapping a breast: start, pause (same side), switch (other side) or resume.
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
        title: const Text('How much did you pump?'),
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

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = _timer(s);
    final k = kind;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Color.lerp(Palette.background, k.color, 0.35),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(title),
        actions: [
          if (t == null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                showEventForm(context, type: widget.kind == 'breastfeed' ? 'feed' : widget.kind, method: 'breast');
              },
              child: const Text('Log past'),
            ),
          if (t != null)
            PopupMenuButton<String>(
              onSelected: (v) => v == 'earlier' ? _stopEarlier(t) : _discard(t),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'earlier', child: Text(widget.kind == 'sleep' ? 'Woke up earlier…' : 'Ended earlier…')),
                const PopupMenuItem(value: 'discard', child: Text('Discard timer')),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Constrained(
          maxWidth: 520,
          child: Ticking(
            builder: (context) => Column(
              children: [
                const SizedBox(height: 8),
                _hint(s, t, text),
                const Spacer(),
                Text(
                  clock(t?.elapsed ?? 0),
                  style: text.displayMedium?.copyWith(
                    fontWeight: FontWeight.w300,
                    color: Palette.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t == null
                      ? 'Tap to start'
                      : t.running
                      ? 'Started ${timeOfDay(t.startedAt)}'
                      : 'Paused',
                  style: text.bodyLarge?.copyWith(color: Palette.muted),
                ),
                const Spacer(),
                if (widget.kind == 'breastfeed')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [_circle(t, 'left', 'L', t?.left ?? 0), _circle(t, 'right', 'R', t?.right ?? 0)],
                  )
                else ...[
                  _bigButton(t),
                  const SizedBox(height: 28),
                  if (widget.kind == 'pump') _pumpSides(t),
                  if (widget.kind == 'sleep')
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
                        color: k.color,
                        onChanged: (v) => setState(() => _location = v),
                      ),
                    ),
                ],
                const Spacer(),
                if (t != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(onPressed: _busy ? null : () => _discard(t), child: const Text('Discard')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: k.deep),
                            onPressed: _busy ? null : () => _stop(t),
                            child: Text(widget.kind == 'sleep' ? 'Woke up — save' : 'Done — save'),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 76),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hint(AppState s, TimerModel? t, TextTheme text) {
    String? hint;
    if (widget.kind == 'breastfeed' && t == null) {
      final last = s.summary?['last']?['feed'];
      final e = last is Map<String, dynamic> ? Event(last) : null;
      final end = e?.endSide;
      if (end != null) {
        final next = end == 'left' ? 'right' : 'left';
        hint =
            'Last feed ended on the ${end == 'left' ? 'left' : 'right'} · ${ago(DateTime.now().difference(e!.start).inSeconds)}\nStart on the $next';
      }
    } else if (widget.kind == 'sleep' && t == null) {
      final last = s.summary?['last']?['sleep'];
      final e = last is Map<String, dynamic> ? Event(last) : null;
      if (e?.end != null) hint = 'Awake for ${duration(DateTime.now().difference(e!.end!).inSeconds)}';
    }
    if (hint == null) return const SizedBox(height: 40);
    return Text(
      hint,
      textAlign: TextAlign.center,
      style: text.bodyLarge?.copyWith(color: Palette.ink, height: 1.5),
    );
  }

  Widget _circle(TimerModel? t, String side, String label, int seconds) {
    final k = kind;
    final active = t != null && t.running && t.side == side;
    final lastSide = t != null && !t.running && t.side == side;
    return GestureDetector(
      onTap: _busy ? null : () => _tapSide(t, side),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: active ? k.deep : Palette.surface,
          shape: BoxShape.circle,
          border: Border.all(color: active || lastSide ? k.deep : k.color, width: 4),
          boxShadow: [
            BoxShadow(
              color: k.deep.withValues(alpha: active ? 0.35 : 0.1),
              blurRadius: active ? 24 : 8,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: active ? Colors.white : k.deep),
            ),
            Text(clock(seconds), style: TextStyle(fontSize: 16, color: active ? Colors.white : Palette.ink)),
            Icon(active ? Icons.pause_rounded : Icons.play_arrow_rounded, color: active ? Colors.white : k.deep),
          ],
        ),
      ),
    );
  }

  Widget _bigButton(TimerModel? t) {
    final k = kind;
    final running = t?.running ?? false;
    return GestureDetector(
      onTap: _busy ? null : () => _toggle(t),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          color: running ? k.deep : Palette.surface,
          shape: BoxShape.circle,
          border: Border.all(color: k.deep, width: 4),
          boxShadow: [
            BoxShadow(
              color: k.deep.withValues(alpha: running ? 0.35 : 0.12),
              blurRadius: running ? 28 : 10,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(k.icon, size: 48, color: running ? Colors.white : k.deep),
            const SizedBox(height: 6),
            Text(
              t == null
                  ? 'Start'
                  : running
                  ? 'Pause'
                  : 'Resume',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: running ? Colors.white : k.deep),
            ),
          ],
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
