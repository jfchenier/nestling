import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/date_time.dart';
import 'event_form.dart';
import 'log_screen.dart';

/// Live timer for `breastfeed`, `sleep` or `pump`, shared with every caregiver.
class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key, required this.kind, this.continued, this.switcher, this.title});
  final String kind;

  /// On the Feed and Pump pages ([LogScreen]): the switch to another kind of entry, shown until
  /// the timer starts, and the page's title.
  final Widget? switcher;
  final String? title;

  /// The saved entry this timer continues (Continue on its edit sheet): its note, sleep location
  /// and pump amounts are kept here, since a timer doesn't store them.
  final Event? continued;

  static Future<void> open(BuildContext context, String kind, {Event? continued}) => Navigator.of(
    context,
  ).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => TimerScreen(kind: kind, continued: continued)));

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  bool _busy = false;
  String? _location;
  String _pumpSide = 'both';

  /// Start time picked before the timer runs (null = now).
  DateTime? _startAt;

  /// End time picked on a running timer (null = now); Save stops the timer at that time.
  DateTime? _endAt;
  final _note = TextEditingController();

  Kind get kind => switch (widget.kind) {
    'sleep' => Kind.sleep,
    'pump' => Kind.pump,
    _ => Kind.breast,
  };
  String get title => switch (widget.kind) {
    'sleep' => l10n.kindSleep,
    'pump' => l10n.kindPump,
    _ => l10n.kindBreastfeed,
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

  Future<void> _start(AppState s, String? side) => s.act(
    (api) => api.post('/children/${s.childId}/timers', {
      'kind': widget.kind,
      'side': ?side,
      if (_startAt != null) 'start': formatTime(_startAt!),
    }),
  );

  /// Start Time row: before starting, remembers the time; afterwards moves the running timer.
  Future<void> _editStart(TimerModel? t, DateTime picked) async {
    if (picked.isAfter(DateTime.now())) return showMessage(context, l10n.timerStartInFuture);
    if (t == null) return setState(() => _startAt = picked);
    await _call((s) => s.act((api) => api.patch('/timers/${t.id}', {'start': formatTime(picked)})));
  }

  /// Time on the timer, stopping at the picked end on a running timer.
  int _total(TimerModel? t) {
    final elapsed = t?.elapsed ?? 0;
    if (t == null || !t.running || _endAt == null) return elapsed;
    return (elapsed - DateTime.now().difference(_endAt!).inSeconds).clamp(0, elapsed);
  }

  /// Pencil under a side (breastfeed) or on Total Time (sleep, pump): correct the time. Before
  /// anything runs, it creates the timer with that time and leaves it paused.
  Future<void> _editTime(TimerModel? t, [String? side]) async {
    final secs = switch (side) {
      'left' => t?.left ?? 0,
      'right' => t?.right ?? 0,
      _ => _total(t),
    };
    TextEditingController ctl(int v) =>
        TextEditingController(text: '$v')..selection = TextSelection(baseOffset: 0, extentOffset: '$v'.length);
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
        title: Text(switch (side) {
          'left' => l10n.timerLeftSide,
          'right' => l10n.timerRightSide,
          _ => widget.kind == 'sleep' ? l10n.timerTimeAsleep : l10n.timerTotalTimeTitle,
        }, style: serifStyle(22)),
        content: Row(children: [field(min, l10n.timerMinutes, autofocus: true), const SizedBox(width: 12), field(sec, l10n.timerSeconds, digits: 2)]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(c, (int.tryParse(min.text) ?? 0) * 60 + (int.tryParse(sec.text) ?? 0)),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (total == null || !mounted) return;
    final key = side == null ? 'seconds' : '${side}_seconds';
    if (t != null) {
      setState(() => _endAt = null); // the corrected time runs up to now again
      await _call((s) => s.act((api) => api.patch('/timers/${t.id}', {key: total})));
      return;
    }
    if (total == 0) return;
    final startAt = _startAt;
    await _call(
      (s) => s.act((api) async {
        final created = await api.post('/children/${s.childId}/timers', {
          'kind': widget.kind,
          'side': ?(side ?? (widget.kind == 'pump' ? _pumpSide : null)),
          'start': formatTime(startAt ?? DateTime.now().subtract(Duration(seconds: total))),
        });
        await api.post('/timers/${created['id']}/pause');
        // A start time picked beforehand stays; the duration is then set on top of it.
        if (startAt != null) await api.patch('/timers/${created['id']}', {key: total});
      }),
    );
    if (mounted) setState(() => _startAt = null);
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

  /// Pump amounts of a continued entry, offered again when it's saved.
  late final Map<String, dynamic>? _pumped = widget.kind == 'pump' && widget.continued != null
      ? {'left_ml': widget.continued!.json['left_ml'], 'right_ml': widget.continued!.json['right_ml']}
      : null;

  @override
  void initState() {
    super.initState();
    _note.text = widget.continued?.note ?? '';
    _location = widget.continued?.json['location'] as String?;
  }

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
      showMessage(context, l10n.timerSaved(title));
      Navigator.pop(context);
    }
  }

  Future<Map<String, dynamic>?> _askPumpAmounts(TimerModel t) {
    final u = context.read<AppState>().units;
    String prior(String key) => switch (_pumped?[key]) {
      final num v => u.volumeIn(v.toDouble()).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''),
      _ => '',
    };
    final left = TextEditingController(text: prior('left_ml')), right = TextEditingController(text: prior('right_ml'));
    double? read(TextEditingController c) {
      final v = double.tryParse(c.text.replaceAll(',', '.'));
      return v == null ? null : double.parse(u.volumeOut(v).toStringAsFixed(1));
    }

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.timerPumpHowMuch, style: serifStyle(22)),
        content: Row(
          children: [
            if (t.side != 'right')
              Expanded(
                child: TextField(
                  controller: left,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l10n.left, suffixText: u.volumeUnit),
                ),
              ),
            if (t.side == 'both') const SizedBox(width: 12),
            if (t.side != 'left')
              Expanded(
                child: TextField(
                  controller: right,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: l10n.right, suffixText: u.volumeUnit),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, {'left_ml': ?read(left), 'right_ml': ?read(right)}), child: Text(l10n.save)),
        ],
      ),
    );
  }

  /// End Time row: a time later than now means yesterday (when only the time was picked).
  void _editEnd(TimerModel t, DateTime picked) {
    final now = DateTime.now();
    var end = picked;
    if (end.isAfter(now)) end = _endAt == null ? end.subtract(const Duration(days: 1)) : now;
    if (!end.isAfter(t.startedAt)) return showMessage(context, l10n.timerEndAfterStart(timeOfDay(t.startedAt)));
    setState(() => _endAt = end);
  }

  Future<void> _delete(TimerModel t) async {
    if (!await confirm(context, l10n.timerDeleteTitle, l10n.timerDeleteBody, action: l10n.delete)) return;
    await _call((s) => s.act((api) => api.delete('/timers/${t.id}')));
    if (mounted) Navigator.pop(context);
  }

  /// Log a finished session by hand instead of timing it. While a timer runs, this screen stays
  /// open under the form (the timer keeps going); a nursing timer offers every kind of feed.
  void _manual(TimerModel? running) {
    if (running == null) {
      Navigator.pop(context);
    } else if (widget.kind == 'breastfeed') {
      LogScreen.open(context, 'feed', pastBreast: true);
      return;
    }
    showEventForm(context, type: widget.kind == 'breastfeed' ? 'feed' : widget.kind, method: 'breast');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final t = _timer(s);
    final c = context.pal;
    final strong = c.isDark ? kind.fill(c) : kind.deepTone;
    final logPast = TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: kind.on(c),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      onPressed: () => _manual(t),
      icon: const Icon(Icons.edit_calendar_rounded, size: 18),
      label: Text(l10n.timerLogPast),
    );
    return Scaffold(
      backgroundColor: Color.lerp(c.background, kind.fill(c), c.isDark ? 0.25 : 0.3),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        // Closing never stops the timer: it keeps running (for every caregiver) until saved or deleted.
        leading: IconButton(icon: const Icon(Icons.close_rounded), tooltip: l10n.close, onPressed: () => Navigator.pop(context)),
        // Scaled down rather than cut off when Save leaves little room (French).
        title: FittedBox(fit: BoxFit.scaleDown, child: Text(widget.title ?? title)),
        centerTitle: true,
        actions: [
          // The Pump page's Amount tab is its Log past.
          if (t == null && !(widget.switcher != null && widget.kind == 'pump')) ...[logPast, const SizedBox(width: 8)],
          if (t != null) ...[
            // Capped so a long label ("Enregistrer") shrinks instead of pushing the title off center.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 88),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: strong,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(80, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: _busy ? null : () => _stop(t, end: _endAt),
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(l10n.save)),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
      body: SafeArea(
        child: Constrained(
          maxWidth: 520,
          child: Ticking(
            next: () => _timer(context.read<AppState>())?.untilNextSecond,
            builder: (context) => ListView(
              children: [
                const SizedBox(height: 4),
                if (t == null && widget.switcher != null)
                  Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: widget.switcher),
                _hint(s, t, logPast),
                const SizedBox(height: 12),
                Text(
                  clock(_total(t)),
                  textAlign: TextAlign.center,
                  style: serifStyle(widget.kind == 'breastfeed' ? 44 : 64, weight: FontWeight.w600).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                ),
                Text(
                  t == null
                      ? (widget.kind == 'breastfeed' ? l10n.timerTapSide : l10n.timerTapStart)
                      : !t.running
                      ? l10n.timerPaused
                      : widget.kind == 'breastfeed'
                      ? l10n.timerOnSide(t.side ?? 'left')
                      : widget.kind == 'sleep'
                      ? l10n.timerSleeping
                      : l10n.timerPumping,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted, fontSize: 16),
                ),
                const SizedBox(height: 28),
                if (widget.kind == 'breastfeed')
                  LayoutBuilder(
                    builder: (context, box) {
                      // As big as two fit side by side on a phone, capped on wide screens.
                      final size = ((box.maxWidth - 56) / 2).clamp(120.0, 176.0);
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [_side(t, 'left', size), _side(t, 'right', size)],
                      );
                    },
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
                        options: {
                          'crib': l10n.locationCrib,
                          'bassinet': l10n.locationBassinet,
                          'bed': l10n.locationBed,
                          'arms': l10n.locationArms,
                          'stroller': l10n.locationStroller,
                          'car': l10n.locationCar,
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
                      decoration: InputDecoration(hintText: l10n.timerNoteHint, prefixIcon: const Icon(Icons.edit_note_rounded)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.timerKeepsRunning,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.muted, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: c.danger,
                        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                      onPressed: _busy ? null : () => _delete(t),
                      child: Text(l10n.delete),
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
  /// While a timer runs the hint line holds [logPast] instead.
  Widget _hint(AppState s, TimerModel? t, Widget logPast) {
    String? hint;
    if (t == null && widget.kind == 'breastfeed') {
      final last = s.summary?['last']?['feed'];
      final e = last is Map<String, dynamic> ? Event(last) : null;
      final end = e?.endSide;
      if (end != null) {
        hint = l10n.timerLastFeedEnded(ago(DateTime.now().difference(e!.start).inSeconds), end);
      }
    } else if (t == null && widget.kind == 'sleep') {
      final last = s.summary?['last']?['sleep'];
      final e = last is Map<String, dynamic> ? Event(last) : null;
      if (e?.end != null) hint = l10n.timerAwakeFor(duration(DateTime.now().difference(e!.end!).inSeconds));
    }
    return SizedBox(
      height: 48,
      child: t != null
          ? Center(child: logPast)
          : hint == null
          ? null
          : Text(hint, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.4)),
    );
  }

  /// Start Time and End Time (editable) and Total Time rows.
  Widget _timeRows(TimerModel? t) {
    final c = context.pal;
    final start = t?.startedAt ?? _startAt;
    final total = _total(t);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          FormRow(
            label: widget.kind == 'sleep' ? l10n.timerFellAsleep : l10n.timerStartTime,
            child: DateTimeValue(value: start, placeholder: l10n.now, enabled: !_busy, onChanged: (v) => _editStart(t, v)),
          ),
          if (t != null)
            FormRow(
              label: widget.kind == 'sleep' ? l10n.timerWokeUp : l10n.timerEndTime,
              child: DateTimeValue(value: _endAt, placeholder: l10n.now, enabled: !_busy, onChanged: (v) => _editEnd(t, v)),
            ),
          // Breastfeed time is the sum of the sides (edited with their pencils), so it's read-only.
          FormRow(
            label: l10n.timerTotalTime,
            onTap: _busy || widget.kind == 'breastfeed' ? null : () => _editTime(t),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  duration(total, showSeconds: true),
                  style: TextStyle(fontSize: 17, color: widget.kind == 'breastfeed' ? c.muted : c.ink),
                ),
                if (widget.kind != 'breastfeed') ...[
                  const SizedBox(width: 8),
                  Icon(Icons.edit_rounded, size: 20, color: kind.on(c), semanticLabel: l10n.timerEditTotal),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A side: "Last side" on its edge (the side the last feed ended on, then the side last started
  /// on this timer), its round button with the time on that side, then its name with a pencil to
  /// correct the time.
  Widget _side(TimerModel? t, String side, double size) {
    final c = context.pal;
    final last = (t != null ? t.side : _lastSide(context.read<AppState>())) == side;
    return Column(
      children: [
        const SizedBox(height: 14),
        Stack(
          clipBehavior: Clip.none,
          children: [
            _circle(t, side, size),
            // On the edge, at 11 o'clock on the left circle and 1 o'clock on the right one.
            if (last)
              Positioned.fill(
                child: Align(
                  alignment: Alignment(side == 'left' ? -0.5 : 0.5, -0.866),
                  child: FractionalTranslation(
                    translation: Offset(side == 'left' ? -0.1 : 0.1, -0.433),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                      decoration: ShapeDecoration(
                        color: Color.alphaBlend(kind.fill(c).withValues(alpha: c.isDark ? 0.3 : 0.45), c.background),
                        shape: StadiumBorder(side: BorderSide(color: kind.on(c), width: 1.5)),
                      ),
                      child: Text(
                        l10n.timerLastSideLabel,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kind.on(c)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 40), // as wide as the pencil, so the name sits under the circle's center
            Text(side == 'left' ? l10n.left : l10n.right, style: serifStyle(22, color: kind.on(c))),
            IconButton(
              tooltip: l10n.timerEditSide(side),
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.edit_rounded, size: 20, color: kind.on(c)),
              onPressed: _busy ? null : () => _editTime(t, side),
            ),
          ],
        ),
      ],
    );
  }

  /// Side the last breastfeed ended on, named above its circle until a new one starts.
  String? _lastSide(AppState s) {
    final last = s.summary?['last']?['feed'];
    return last is Map<String, dynamic> && last['method'] == 'breast' ? Event(last).endSide : null;
  }

  /// Big round side button: start, pause (same side), switch (other side) or resume. With no
  /// time on that side yet it holds a big play icon; once timed, the side's time with a small
  /// play/pause icon under it.
  Widget _circle(TimerModel? t, String side, double size) {
    final c = context.pal;
    final active = t != null && t.running && t.side == side;
    final current = t != null && t.side == side;
    final strong = c.isDark ? kind.fill(c) : kind.deepTone;
    final seconds = (side == 'left' ? t?.left : t?.right) ?? 0;
    final ink = active ? Colors.white : kind.on(c);
    final action = t == null
        ? (_lastSide(context.read<AppState>()) == side ? l10n.timerStartSideLast(side) : l10n.timerStartSide(side))
        : active
        ? l10n.timerPauseSide(side)
        : t.running
        ? l10n.timerSwitchSide(side)
        : l10n.timerResumeSide(side);
    return Semantics(
      button: true,
      label: action,
      value: l10n.durMinutesSeconds(seconds ~/ 60, (seconds % 60).toString().padLeft(2, '0')),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _busy ? null : () => _tapSide(t, side),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: size,
          height: size,
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
          child: active || seconds > 0
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          clock(seconds),
                          style: serifStyle(size * 0.25, weight: FontWeight.w600, color: ink)
                              .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                      ),
                    ),
                    Icon(active ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 28, color: ink),
                  ],
                )
              : Icon(Icons.play_arrow_rounded, size: size * 0.45, color: ink),
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
      label: t == null ? l10n.timerStart : (running ? l10n.timerPause : l10n.timerResume),
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
                t == null ? l10n.timerStart : (running ? l10n.timerPause : l10n.timerResume),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: running ? Colors.white : kind.on(c)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pumpSides(TimerModel? t) => SegmentedButton<String>(
    segments: [
      ButtonSegment(value: 'left', label: Text(l10n.left)),
      ButtonSegment(value: 'both', label: Text(l10n.both)),
      ButtonSegment(value: 'right', label: Text(l10n.right)),
    ],
    selected: {t?.side ?? _pumpSide},
    showSelectedIcon: false,
    onSelectionChanged: (v) {
      setState(() => _pumpSide = v.first);
      if (t != null && t.running) _call((s) => s.act((api) => api.post('/timers/${t.id}/switch', {'side': v.first})));
    },
  );
}
