import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../local/domain.dart' show dayWindowOf, hhmm;
import '../l10n/l10n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Family setting: when daytime starts and ends (Trends' day/night split, naps).
class DayHoursScreen extends StatefulWidget {
  const DayHoursScreen({super.key});

  @override
  State<DayHoursScreen> createState() => _DayHoursScreenState();
}

class _DayHoursScreenState extends State<DayHoursScreen> {
  static const _step = 15;
  int? _start, _end;

  Future<void> _save(int start, int end) async {
    final s = context.read<AppState>();
    final id = s.family!.id;
    await guard(
      context,
      () => s.act((api) => api.patch('/families/$id', {'day_start': hhmm(start), 'day_end': hhmm(end)}), families: true),
    );
  }

  Future<void> _pick(bool isStart, int start, int end) async {
    final minutes = isStart ? start : end;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60 % 24, minute: minutes % 60),
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (t == null || !mounted) return;
    final v = t.hour * 60 + t.minute;
    final (s, e) = isStart ? (v, end) : (start, v == 0 ? 24 * 60 : v);
    if (s >= e) {
      showMessage(context, l10n.dayHoursStartBeforeEnd);
      return;
    }
    setState(() {
      _start = s;
      _end = e;
    });
    await _save(s, e);
  }

  @override
  Widget build(BuildContext context) {
    final saved = dayWindowOf(context.watch<AppState>().family?.json);
    final start = _start ?? saved.start, end = _end ?? saved.end;
    final pal = context.pal;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.familyDayNight)),
      body: Constrained(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Text(l10n.dayHoursIntro, style: TextStyle(color: pal.muted, fontSize: 14, height: 1.4)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _TimeBox(label: l10n.dayHoursDayStarts, minutes: start, onTap: () => _pick(true, start, end)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_forward_rounded, color: pal.muted),
                ),
                Expanded(
                  child: _TimeBox(label: l10n.dayHoursNightStarts, minutes: end, onTap: () => _pick(false, start, end)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _DayBar(
              start: start,
              end: end,
              step: _step,
              onChanged: (s, e) => setState(() {
                _start = s;
                _end = e;
              }),
              onChangeEnd: (s, e) => _save(s, e),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.label, required this.minutes, required this.onTap});
  final String label;
  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Material(
      color: pal.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: pal.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hhmm(minutes), style: serifStyle(26)),
                    const SizedBox(height: 2),
                    Text(label, style: TextStyle(color: pal.muted, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, size: 20, color: pal.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 24 hours as a bar: drag either end of the daytime band (snaps to [step] minutes).
class _DayBar extends StatefulWidget {
  const _DayBar({required this.start, required this.end, required this.step, required this.onChanged, required this.onChangeEnd});
  final int start, end, step;
  final void Function(int start, int end) onChanged, onChangeEnd;

  @override
  State<_DayBar> createState() => _DayBarState();
}

class _DayBarState extends State<_DayBar> {
  static const _day = 24 * 60;
  static const _height = 64.0;
  bool? _draggingStart;

  int _at(double dx, double width) {
    final m = (dx / width * _day / widget.step).round() * widget.step;
    return m.clamp(0, _day);
  }

  void _drag(double dx, double width) {
    final m = _at(dx, width);
    if (_draggingStart!) {
      widget.onChanged(m.clamp(0, widget.end - widget.step), widget.end);
    } else {
      widget.onChanged(widget.start, m.clamp(widget.start + widget.step, _day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        double x(int minutes) => minutes / _day * w;
        final x0 = x(widget.start), x1 = x(widget.end);
        return Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (d) {
                final dx = d.localPosition.dx;
                setState(() => _draggingStart = (dx - x0).abs() <= (dx - x1).abs());
                _drag(dx, w);
              },
              onHorizontalDragUpdate: (d) => _drag(d.localPosition.dx, w),
              onHorizontalDragEnd: (_) {
                setState(() => _draggingStart = null);
                widget.onChangeEnd(widget.start, widget.end);
              },
              child: SizedBox(
                height: _height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Night: the whole day, one cell per hour.
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Row(
                          children: [
                            for (var h = 0; h < 24; h++)
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Kind.sleep.fill(pal),
                                    border: h == 0 ? null : Border(left: BorderSide(color: pal.surface.withValues(alpha: 0.35))),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: x0,
                      width: x1 - x0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(color: Kind.pump.fill(pal), borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: x1 - x0 > 90
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.wb_sunny_rounded, size: 20, color: pal.bandInk),
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.dayHoursDaytime,
                                    style: TextStyle(color: pal.bandInk, fontWeight: FontWeight.w700, fontSize: 15),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ),
                    for (final (pos, isStart) in [(x0, true), (x1, false)])
                      Positioned(
                        left: pos - 7,
                        top: 10,
                        bottom: 10,
                        child: Container(
                          width: 14,
                          decoration: BoxDecoration(
                            color: _draggingStart == isStart ? pal.accent : pal.surface,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: pal.bandInk.withValues(alpha: 0.5), width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 16,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var h = 0; h <= 24; h += 4)
                    Positioned(
                      left: h == 0 ? 0 : (h == 24 ? w - 40 : x(h * 60) - 20),
                      width: 40,
                      child: Text(
                        hhmm(h * 60),
                        textAlign: h == 0 ? TextAlign.left : (h == 24 ? TextAlign.right : TextAlign.center),
                        style: TextStyle(fontSize: 11, color: pal.muted),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
