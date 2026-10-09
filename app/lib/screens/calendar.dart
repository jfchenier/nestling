import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'event_form.dart';

/// A week at a glance: one column per day, 00–24 from top to bottom, a bar per entry
/// (as tall as its duration). Tap a bar to open the entry.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  /// Filter groups: label, the look of its chip, the event types it covers.
  static const _groups = <(String, Kind, Set<String>)>[
    ('Feeds', Kind.breast, {'feed'}),
    ('Sleep', Kind.sleep, {'sleep'}),
    ('Diapers', Kind.diaper, {'diaper'}),
    ('Pump', Kind.pump, {'pump'}),
    ('Other', Kind.activity, {'growth', 'health', 'activity', 'milestone', 'note'}),
  ];
  static const _labelWidth = 34.0;
  static const _nightEnd = 6, _nightStart = 18; // same day/night split as Trends

  /// Last day shown (the week is the 7 days ending on it).
  DateTime _end = _today();
  final Set<String> _hidden = {};
  List<Event> _events = [];
  bool _loading = false;
  (String?, int, DateTime)? _loadedFor; // child, revision, week

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  List<DateTime> get _days => [for (var i = 6; i >= 0; i--) DateTime(_end.year, _end.month, _end.day - i)];

  Future<void> _fetch() async {
    final s = context.read<AppState>();
    if (s.childId == null) return;
    setState(() => _loading = true);
    final first = _days.first;
    // One extra day back so a sleep that started the night before still shows.
    final res = await guard(
      context,
      () => s.api!.get('/children/${s.childId}/events', {
        'from': formatTime(DateTime(first.year, first.month, first.day - 1)),
        'to': formatTime(DateTime(_end.year, _end.month, _end.day + 1)),
        'limit': '1000',
      }),
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res != null) _events = [for (final e in res['events'] as List) Event(e)];
    });
  }

  void _move(int days) => setState(() {
    final next = DateTime(_end.year, _end.month, _end.day + days);
    _end = next.isAfter(_today()) ? _today() : next;
  });

  bool _visible(Event e) {
    for (final (label, _, types) in _groups) {
      if (types.contains(e.type)) return !_hidden.contains(label);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.pal;
    final key = (s.childId, s.revision, _end);
    if (_loadedFor != key) {
      _loadedFor = key;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
    }
    final days = _days;
    final isThisWeek = _end == _today();
    final range = days.first.month == days.last.month
        ? '${DateFormat.MMMd().format(days.first)} – ${days.last.day}'
        : '${DateFormat.MMMd().format(days.first)} – ${DateFormat.MMMd().format(days.last)}';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          if (_loading) const Padding(padding: EdgeInsets.all(18), child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))),
        ],
      ),
      body: Constrained(
        maxWidth: 760,
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final (label, kind, _) in _groups)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(label),
                        avatar: CircleAvatar(backgroundColor: _barColor(kind, c), radius: 6),
                        selected: !_hidden.contains(label),
                        showCheckmark: false,
                        selectedColor: c.accentSoft,
                        onSelected: (on) => setState(() => on ? _hidden.remove(label) : _hidden.add(label)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  IconButton(tooltip: 'Previous week', icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _move(-7)),
                  Expanded(
                    child: Text(range, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  if (!isThisWeek) TextButton(onPressed: () => setState(() => _end = _today()), child: const Text('Today')),
                  IconButton(
                    tooltip: 'Next week',
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: isThisWeek ? null : () => _move(7),
                  ),
                ],
              ),
            ),
            _DayHeader(days: days, labelWidth: _labelWidth),
            Divider(height: 1, color: c.line),
            Expanded(
              child: GestureDetector(
                // Swipe between weeks.
                onHorizontalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v > 300) _move(-7);
                  if (v < -300 && !isThisWeek) _move(7);
                },
                child: LayoutBuilder(
                  builder: (context, box) {
                    final hour = ((box.maxHeight - 14) / 24).clamp(22.0, 80.0);
                    return SingleChildScrollView(
                      child: SizedBox(
                        height: hour * 24 + 12,
                        child: _Grid(
                          days: days,
                          events: [for (final e in _events) if (_visible(e)) e],
                          hour: hour,
                          labelWidth: _labelWidth,
                          nightEnd: _nightEnd,
                          nightStart: _nightStart,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bar color: the activity pastel, a touch deeper on light backgrounds so it stands out.
Color _barColor(Kind k, AppColors c) => c.isDark ? k.color : Color.lerp(k.color, k.deepTone, 0.3)!;

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.days, required this.labelWidth});
  final List<DateTime> days;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final today = _CalendarScreenState._today();
    return Padding(
      padding: EdgeInsets.only(left: labelWidth, bottom: 6),
      child: Row(
        children: [
          for (final d in days)
            Expanded(
              child: Column(
                children: [
                  Text(DateFormat.E().format(d).substring(0, 2), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted)),
                  const SizedBox(height: 4),
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: d == today ? BoxDecoration(color: c.accent, shape: BoxShape.circle) : null,
                    child: Text(
                      '${d.day}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: d == today ? c.onAccent : c.ink),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.days,
    required this.events,
    required this.hour,
    required this.labelWidth,
    required this.nightEnd,
    required this.nightStart,
  });
  final List<DateTime> days;
  final List<Event> events;
  final double hour;
  final double labelWidth;
  final int nightEnd, nightStart;

  static const _top = 6.0; // room for the "00" label

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return LayoutBuilder(
      builder: (context, box) {
        final colW = (box.maxWidth - labelWidth - 4) / days.length;
        double y(DateTime day, DateTime t) => _top + t.difference(day).inSeconds / 3600 * hour;
        final bars = <Widget>[];
        for (var i = 0; i < days.length; i++) {
          final day = days[i], next = DateTime(day.year, day.month, day.day + 1);
          for (final e in events) {
            final end = e.end ?? e.start;
            if (!end.isAfter(day) && !(e.start == day)) continue;
            if (!e.start.isBefore(next)) continue;
            final from = e.start.isBefore(day) ? day : e.start;
            final to = end.isAfter(next) ? next : end;
            final top = y(day, from);
            final height = (y(day, to) - top).clamp(7.0, double.infinity);
            final kind = Kind.of(e.type, e['method'] as String?);
            bars.add(
              Positioned(
                left: labelWidth + i * colW + 4,
                width: colW - 8,
                top: top,
                height: height,
                child: Semantics(
                  button: true,
                  label: '${kind.label} ${DateFormat.jm().format(e.start)}',
                  child: GestureDetector(
                    onTap: () => showEventForm(context, type: e.type, event: e),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _barColor(kind, c),
                        borderRadius: BorderRadius.circular(3),
                        // Thin edge so stacked entries stay distinct.
                        border: Border.all(color: c.surface.withValues(alpha: 0.7), width: 0.8),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        }
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPainter(
                  pal: c,
                  hour: hour,
                  top: _top,
                  labelWidth: labelWidth,
                  nightEnd: nightEnd,
                  nightStart: nightStart,
                  nowColumn: days.indexWhere((d) => d == _CalendarScreenState._today()),
                  columns: days.length,
                ),
              ),
            ),
            ...bars,
          ],
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.pal,
    required this.hour,
    required this.top,
    required this.labelWidth,
    required this.nightEnd,
    required this.nightStart,
    required this.nowColumn,
    required this.columns,
  });
  final AppColors pal;
  final double hour, top, labelWidth;
  final int nightEnd, nightStart, nowColumn, columns;

  @override
  void paint(Canvas canvas, Size size) {
    final left = labelWidth;
    // Day hours on the card color, night hours a shade of dusk.
    final night = Paint()..color = Color.lerp(pal.background, Kind.sleep.fill(pal), pal.isDark ? 0.35 : 0.25)!;
    final day = Paint()..color = pal.surface;
    canvas.drawRect(Rect.fromLTRB(left, top, size.width, top + nightEnd * hour), night);
    canvas.drawRect(Rect.fromLTRB(left, top + nightEnd * hour, size.width, top + nightStart * hour), day);
    canvas.drawRect(Rect.fromLTRB(left, top + nightStart * hour, size.width, top + 24 * hour), night);

    final line = Paint()
      ..color = pal.line
      ..strokeWidth = 1;
    for (var h = 0; h <= 24; h += 3) {
      final y = top + h * hour;
      if (h > 0 && h < 24) {
        for (var x = left; x < size.width; x += 8) {
          canvas.drawLine(Offset(x, y), Offset(x + 4, y), line);
        }
      }
      final tp = TextPainter(
        text: TextSpan(text: h.toString().padLeft(2, '0'), style: TextStyle(fontSize: 11, color: pal.muted)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(4, (y - tp.height / 2).clamp(0, size.height - tp.height)));
    }

    // Now marker on today's column.
    if (nowColumn >= 0) {
      final n = DateTime.now();
      final y = top + (n.hour + n.minute / 60) * hour;
      final colW = (size.width - left - 4) / columns;
      final x0 = left + nowColumn * colW, x1 = x0 + colW;
      final p = Paint()
        ..color = pal.accent
        ..strokeWidth = 2;
      canvas.drawLine(Offset(x0, y), Offset(x1, y), p);
      canvas.drawCircle(Offset(x0 + 2, y), 3.5, p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => true;
}
