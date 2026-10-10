import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../models.dart';
import '../state.dart';
import '../theme.dart';
import 'event_form.dart';

/// Days at a glance: one column per day (today on the right), 00–24 from top to bottom, a bar
/// per entry as tall as its duration. Drag sideways to go back in time; tap a bar to open it.
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
  static const _headerHeight = 58.0;
  static const _visibleDays = 7;
  static const _chunk = 14; // days fetched per request

  final _scroll = ScrollController();
  final Set<String> _hidden = {};

  /// Entries per local day (an entry crossing midnight is in both days).
  final Map<DateTime, List<Event>> _byDay = {};
  final Set<int> _loaded = {}, _loading = {};
  (String?, int)? _loadedFor; // child, revision
  double _colWidth = 1;

  static DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime _dayAt(int index) {
    final t = today();
    return DateTime(t.year, t.month, t.day - index);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Load the chunk holding day [index] (0 = today) if needed.
  void _ensure(int index) {
    final chunk = index ~/ _chunk;
    if (_loaded.contains(chunk) || _loading.contains(chunk)) return;
    _loading.add(chunk);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch(chunk));
  }

  Future<void> _fetch(int chunk) async {
    final s = context.read<AppState>();
    final key = _loadedFor;
    if (s.childId == null) return;
    final newest = _dayAt(chunk * _chunk), oldest = _dayAt(chunk * _chunk + _chunk - 1);
    try {
      final res = await s.api!.get('/children/${s.childId}/events', {
        // A day earlier so a sleep that started the night before still shows.
        'from': formatTime(DateTime(oldest.year, oldest.month, oldest.day - 1)),
        'to': formatTime(DateTime(newest.year, newest.month, newest.day + 1)),
        'limit': '1000',
      });
      if (!mounted || key != _loadedFor) return;
      final events = [for (final e in res['events'] as List) Event(e)];
      setState(() {
        for (var i = 0; i < _chunk; i++) {
          final day = _dayAt(chunk * _chunk + i), next = DateTime(day.year, day.month, day.day + 1);
          _byDay[day] = [
            for (final e in events)
              if (e.start.isBefore(next) && ((e.end ?? e.start).isAfter(day) || e.start == day)) e,
          ];
        }
        _loaded.add(chunk);
      });
    } catch (_) {
      // Shown as empty; retried on the next change.
    } finally {
      _loading.remove(chunk);
    }
  }

  bool _visible(Event e) {
    for (final (label, _, types) in _groups) {
      if (types.contains(e.type)) return !_hidden.contains(label);
    }
    return true;
  }

  void _jump(int days) {
    final target = (_scroll.offset + days * _colWidth).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo((target / _colWidth).round() * _colWidth, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.pal;
    final key = (s.childId, s.revision);
    if (_loadedFor != key) {
      _loadedFor = key;
      _byDay.clear();
      _loaded.clear();
      _loading.clear();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: Column(
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
          // Visible range + arrows; follows the scroll position.
          AnimatedBuilder(
            animation: _scroll,
            builder: (context, _) {
              final first = _scroll.hasClients ? (_scroll.offset / _colWidth).round() : 0;
              final newest = _dayAt(first), oldest = _dayAt(first + _visibleDays - 1);
              final range = oldest.month == newest.month
                  ? '${DateFormat.MMMd().format(oldest)} – ${newest.day}'
                  : '${DateFormat.MMMd().format(oldest)} – ${DateFormat.MMMd().format(newest)}';
              return Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Row(
                  children: [
                    IconButton(tooltip: 'Previous week', icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _jump(7)),
                    Expanded(
                      child: Text(
                        range,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (first > 0) TextButton(onPressed: () => _jump(-first), child: const Text('Today')),
                    IconButton(
                      tooltip: 'Next week',
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: first == 0 ? null : () => _jump(-7),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                _colWidth = (box.maxWidth - _labelWidth) / _visibleDays;
                final hour = math.max(16.0, (box.maxHeight - _headerHeight - 14) / 24);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: _labelWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(top: _headerHeight),
                        child: CustomPaint(
                          size: Size(_labelWidth, hour * 24 + 12),
                          painter: _HourLabels(pal: c, hour: hour),
                        ),
                      ),
                    ),
                    Expanded(
                      // Drag with a mouse too, not only touch (web on a computer).
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
                        child: ListView.builder(
                          controller: _scroll,
                          scrollDirection: Axis.horizontal,
                          reverse: true, // today on the right, drag right to go back
                          itemExtent: _colWidth,
                          physics: _DaySnapPhysics(_colWidth),
                          itemCount: 3650,
                          itemBuilder: (context, i) {
                            _ensure(i);
                            final day = _dayAt(i);
                            return _DayColumn(
                              day: day,
                              events: [
                                for (final e in _byDay[day] ?? const <Event>[])
                                  if (_visible(e)) e,
                              ],
                              hour: hour,
                              headerHeight: _headerHeight,
                              loading: !_loaded.contains(i ~/ _chunk),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Bar color: the activity pastel, a touch deeper on light backgrounds so it stands out.
Color _barColor(Kind k, AppColors c) => c.isDark ? k.color : Color.lerp(k.color, k.deepTone, 0.3)!;

/// Settles on whole days after a drag or fling.
class _DaySnapPhysics extends ScrollPhysics {
  const _DaySnapPhysics(this.extent, {super.parent});
  final double extent;

  @override
  _DaySnapPhysics applyTo(ScrollPhysics? ancestor) => _DaySnapPhysics(extent, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if (position.outOfRange) return super.createBallisticSimulation(position, velocity);
    // Where a free fling would stop, rounded to a day.
    final free = super.createBallisticSimulation(position, velocity);
    final end = free == null ? position.pixels : free.x(double.infinity);
    final target = ((end / extent).round() * extent).clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < 0.5) return null;
    return ScrollSpringSimulation(spring, position.pixels, target, velocity, tolerance: toleranceFor(position));
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.day, required this.events, required this.hour, required this.headerHeight, required this.loading});
  final DateTime day;
  final List<Event> events;
  final double hour, headerHeight;
  final bool loading;

  static const _top = 6.0;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final isToday = day == _CalendarScreenState.today();
    final next = DateTime(day.year, day.month, day.day + 1);
    double y(DateTime t) => _top + t.difference(day).inSeconds / 3600 * hour;

    Widget bar(Event e) {
      final end = e.end ?? e.start;
      final from = e.start.isBefore(day) ? day : e.start;
      final to = end.isAfter(next) ? next : end;
      final top = y(from);
      final kind = Kind.of(e.type, e.look);
      return Positioned(
        left: 3,
        right: 3,
        top: top,
        height: math.max(7.0, y(to) - top),
        child: Semantics(
          button: true,
          label: '${kind.label} ${DateFormat.Hm().format(e.start)}',
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
      );
    }

    return Column(
      children: [
        SizedBox(
          height: headerHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // The 1st of a month shows the month instead of the weekday.
              Text(
                day.day == 1 ? DateFormat.MMM().format(day) : DateFormat.E().format(day).substring(0, 2),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: day.day == 1 ? c.accent : c.muted),
              ),
              const SizedBox(height: 4),
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: isToday ? BoxDecoration(color: c.accent, shape: BoxShape.circle) : null,
                child: Text(
                  '${day.day}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isToday ? c.onAccent : c.ink),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: c.line),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ColumnPainter(pal: c, hour: hour, top: _top, now: isToday ? DateTime.now() : null),
                ),
              ),
              if (loading)
                Positioned(
                  left: 0,
                  right: 0,
                  top: _top,
                  child: LinearProgressIndicator(minHeight: 2, color: c.line),
                ),
              for (final e in events) bar(e),
            ],
          ),
        ),
      ],
    );
  }
}

/// One day's background: day hours on the card color, night (18–06, as in Trends) a shade of
/// dusk, dashed lines every 3 h, and the current time on today.
class _ColumnPainter extends CustomPainter {
  _ColumnPainter({required this.pal, required this.hour, required this.top, this.now});
  final AppColors pal;
  final double hour, top;
  final DateTime? now;

  @override
  void paint(Canvas canvas, Size size) {
    final night = Paint()..color = Color.lerp(pal.background, Kind.sleep.fill(pal), pal.isDark ? 0.35 : 0.25)!;
    canvas.drawRect(Rect.fromLTRB(0, top, size.width, top + 6 * hour), night);
    canvas.drawRect(Rect.fromLTRB(0, top + 6 * hour, size.width, top + 18 * hour), Paint()..color = pal.surface);
    canvas.drawRect(Rect.fromLTRB(0, top + 18 * hour, size.width, top + 24 * hour), night);
    final line = Paint()
      ..color = pal.line
      ..strokeWidth = 1;
    for (var h = 3; h < 24; h += 3) {
      final y = top + h * hour;
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(x + 4, y), line);
      }
    }
    // Faint separator between days.
    canvas.drawLine(
      Offset(size.width - 0.5, top),
      Offset(size.width - 0.5, top + 24 * hour),
      Paint()..color = pal.line.withValues(alpha: 0.5),
    );
    final n = now;
    if (n != null) {
      final y = top + (n.hour + n.minute / 60) * hour;
      final p = Paint()
        ..color = pal.accent
        ..strokeWidth = 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      canvas.drawCircle(Offset(3, y), 3.5, p);
    }
  }

  @override
  bool shouldRepaint(_ColumnPainter old) => old.hour != hour || old.pal != pal || old.now != now;
}

/// 00, 03 … 24 down the left edge, lined up with the day columns.
class _HourLabels extends CustomPainter {
  _HourLabels({required this.pal, required this.hour});
  final AppColors pal;
  final double hour;

  @override
  void paint(Canvas canvas, Size size) {
    const top = _DayColumn._top + 1; // + the header divider
    for (var h = 0; h <= 24; h += 3) {
      final tp = TextPainter(
        text: TextSpan(
          text: h.toString().padLeft(2, '0'),
          style: TextStyle(fontSize: 11, color: pal.muted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(4, top + h * hour - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_HourLabels old) => old.hour != hour || old.pal != pal;
}
