import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';

import '../format.dart';
import '../growth/percentiles.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'child_form.dart';
import 'event_form.dart';

/// Growth charts: the child's weight, length and head size over the WHO percentile curves
/// (birth to 24 months). Tap a point for its percentile.
class GrowthChartScreen extends StatefulWidget {
  const GrowthChartScreen({super.key});

  @override
  State<GrowthChartScreen> createState() => _GrowthChartScreenState();
}

class _GrowthChartScreenState extends State<GrowthChartScreen> {
  GrowthIndicator _indicator = GrowthIndicator.weight;

  /// WHO curves to compare with when the child's sex isn't set.
  String _compareSex = 'female';
  List<Event>? _events;
  Event? _selected;
  (String?, int)? _loadedFor;

  Future<void> _load() async {
    final s = context.read<AppState>();
    if (s.childId == null) return;
    final res = await guard(context, () => s.api!.get('/children/${s.childId}/events', {'type': 'growth', 'limit': '1000'}));
    if (!mounted || res == null) return;
    setState(() {
      _events = [for (final e in res['events'] as List) Event(e)];
      _selected = null;
    });
  }

  String get _field => switch (_indicator) {
    GrowthIndicator.weight => 'weight_g',
    GrowthIndicator.length => 'length_cm',
    GrowthIndicator.head => 'head_cm',
  };

  /// Metric value as the WHO tables use it (kg / cm).
  double? _metric(Event e) {
    final v = toDouble(e[_field]);
    if (v == null) return null;
    return _indicator == GrowthIndicator.weight ? v / 1000 : v;
  }

  /// WHO metric (kg / cm) → what the user reads (kg or lb, cm or in).
  double _display(double metric, Units u) => _indicator == GrowthIndicator.weight ? u.weightIn(metric * 1000) : u.lengthIn(metric);

  String _unit(Units u) => _indicator == GrowthIndicator.weight ? u.weightUnit : u.lengthUnit;

  String _valueText(Event e, Units u) => switch (_indicator) {
    GrowthIndicator.weight => u.weight(toDouble(e['weight_g'])),
    GrowthIndicator.length => u.length(toDouble(e['length_cm'])),
    GrowthIndicator.head => u.length(toDouble(e['head_cm'])),
  };

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.pal;
    final child = s.child;
    final key = (s.childId, s.revision);
    if (_loadedFor != key) {
      _loadedFor = key;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    final birth = child?.birthDate;
    final sex = child?.sex == 'male' || child?.sex == 'female' ? child!.sex! : _compareSex;
    final std = WhoStandard(_indicator, sex);
    final u = s.units;

    double? age(Event e) => birth == null ? null : e.start.difference(birth).inHours / 24;
    final points = <_Point>[
      for (final e in (_events ?? const <Event>[]).reversed)
        if (_metric(e) case final v? when (age(e) ?? -1) >= 0) _Point(e, age(e)!, v),
    ];
    final selected = points.where((p) => p.event.id == _selected?.id).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Growth charts')),
      body: Constrained(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            SegmentedButton<GrowthIndicator>(
              segments: const [
                ButtonSegment(value: GrowthIndicator.weight, label: Text('Weight')),
                ButtonSegment(value: GrowthIndicator.length, label: Text('Length')),
                ButtonSegment(value: GrowthIndicator.head, label: Text('Head')),
              ],
              selected: {_indicator},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() {
                _indicator = v.first;
                _selected = null;
              }),
            ),
            const SizedBox(height: 12),
            if (child != null && child.sex != 'male' && child.sex != 'female')
              Row(
                children: [
                  Text('Compare with', style: TextStyle(color: c.muted)),
                  const SizedBox(width: 12),
                  ChoiceChips<String>(
                    options: const {'female': 'Girls', 'male': 'Boys'},
                    value: _compareSex,
                    onChanged: (v) => setState(() => _compareSex = v ?? _compareSex),
                  ),
                ],
              ),
            if (birth == null)
              _Notice(
                text: 'Add ${child?.name ?? 'the baby'}\'s birth date to compare with the WHO growth curves.',
                action: child == null ? null : ('Add birth date', () => showChildForm(context, familyId: child.familyId, child: child)),
              )
            else if (_events == null)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 8, 8),
                  child: AspectRatio(
                    aspectRatio: 0.85,
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final chart = _ChartGeometry.of(std, points, birth, box.biggest, (m) => _display(m, u));
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (d) => setState(() => _selected = chart.hit(d.localPosition)?.event),
                          child: CustomPaint(size: box.biggest, painter: _GrowthPainter(chart, std, c, _unit(u), selected)),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (selected != null)
                _Detail(
                  point: selected,
                  value: _valueText(selected.event, u),
                  label: _indicator.name,
                  percentile: std.percentile(selected.days, selected.metric),
                  sex: sex,
                  birth: birth,
                ),
              if (points.isEmpty)
                _Notice(
                  text: 'No ${_indicator == GrowthIndicator.head ? 'head size' : _indicator.name} measured yet.',
                  action: ('Add a measurement', () => showEventForm(context, type: 'growth')),
                ),
              const SizedBox(height: 8),
              for (final p in points.reversed)
                ListTile(
                  dense: true,
                  selected: p.event.id == _selected?.id,
                  title: Text(_valueText(p.event, u)),
                  subtitle: Text('${DateFormat.yMMMd().format(p.event.start)} · ${_ageLabel(birth, p.event.start)}'),
                  trailing: Text(switch (std.percentile(p.days, p.metric)) {
                    final pc? => '${percentileLabel(pc)} percentile',
                    null => '',
                  }, style: TextStyle(color: Kind.growth.on(c), fontWeight: FontWeight.w600)),
                  onTap: () => setState(() => _selected = p.event),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Curves: WHO Child Growth Standards (${sex == 'female' ? 'girls' : 'boys'}, birth to 24 months), '
                  'percentiles 2 to 98. A single measurement says little; follow the trend, and ask your '
                  'doctor about any worry.',
                  style: TextStyle(color: c.muted, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "2m 5d", "1y 3m", "12d".
String _ageLabel(DateTime birth, DateTime at) {
  var months = (at.year - birth.year) * 12 + at.month - birth.month;
  if (at.day < birth.day) months--;
  final anchor = DateTime(birth.year, birth.month + months, birth.day);
  final days = at.difference(anchor).inDays;
  if (months <= 0) return '${at.difference(birth).inDays}d';
  if (months >= 12) return '${months ~/ 12}y ${months % 12}m';
  return '${months}m ${days}d';
}

class _Point {
  _Point(this.event, this.days, this.metric);
  final Event event;
  final double days;

  /// kg or cm.
  final double metric;
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.action});
  final String text;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.pal.muted),
          ),
          if (action case (final label, final onTap)) ...[const SizedBox(height: 12), FilledButton(onPressed: onTap, child: Text(label))],
        ],
      ),
    ),
  );
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.point,
    required this.value,
    required this.label,
    required this.percentile,
    required this.sex,
    required this.birth,
  });
  final _Point point;
  final String value, label, sex;
  final double? percentile;
  final DateTime birth;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    Widget line(String k, String v) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$k  ',
              style: TextStyle(color: c.muted),
            ),
            TextSpan(
              text: v,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat.yMMMd().format(point.event.start), style: serifStyle(18)),
                  line(cap(label), value),
                  if (percentile != null) line('${sex == 'female' ? 'Girls' : 'Boys'} percentile', percentileLabel(percentile!)),
                  line('Age', _ageLabel(birth, point.event.start)),
                ],
              ),
            ),
            TextButton(
              onPressed: () => showEventForm(context, type: 'growth', event: point.event),
              child: const Text('Edit'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Axes and mapping between (age in days, display value) and pixels.
class _ChartGeometry {
  _ChartGeometry(this.plot, this.maxDays, this.yMin, this.yMax, this.yStep, this.weeks, this.points, this.display);

  static const left = 44.0, right = 40.0, top = 26.0, bottom = 34.0;

  final Rect plot;
  final double maxDays, yMin, yMax, yStep;

  /// X axis in weeks (young babies) or months.
  final bool weeks;
  final List<_Point> points;
  final double Function(double metric) display;

  factory _ChartGeometry.of(WhoStandard std, List<_Point> points, DateTime birth, Size size, double Function(double) display) {
    final today = DateTime.now().difference(birth).inHours / 24;
    final lastPoint = points.fold<double>(0, (a, p) => math.max(a, p.days));
    final maxDays = (math.max(math.max(today, lastPoint) * 1.15, 13 * 7.0)).clamp(13 * 7.0, whoMaxDays).toDouble();
    var lo = display(std.valueAt(0, percentileCurves.first.$2)!);
    var hi = display(std.valueAt(maxDays, percentileCurves.last.$2)!);
    for (final p in points.where((p) => p.days <= maxDays)) {
      lo = math.min(lo, display(p.metric));
      hi = math.max(hi, display(p.metric));
    }
    final step = [0.25, 0.5, 1.0, 2.0, 5.0, 10.0].firstWhere((s) => (hi - lo) / s <= 10, orElse: () => 20);
    final yMin = (lo / step).floor() * step, yMax = (hi / step).ceil() * step;
    final plot = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    return _ChartGeometry(plot, maxDays, yMin, yMax, step, maxDays <= 26 * 7, points, display);
  }

  Offset at(double days, double value) =>
      Offset(plot.left + days / maxDays * plot.width, plot.bottom - (value - yMin) / (yMax - yMin) * plot.height);

  _Point? hit(Offset pos) {
    _Point? best;
    var bestD = 28.0;
    for (final p in points) {
      if (p.days > maxDays) continue;
      final d = (at(p.days, display(p.metric)) - pos).distance;
      if (d < bestD) (best, bestD) = (p, d);
    }
    return best;
  }
}

class _GrowthPainter extends CustomPainter {
  _GrowthPainter(this.g, this.std, this.pal, this.unit, this.selected);
  final _ChartGeometry g;
  final WhoStandard std;
  final AppColors pal;
  final String unit;
  final _Point? selected;

  void _text(
    Canvas canvas,
    String s,
    Offset at, {
    Color? color,
    double size = 11,
    bool right = false,
    bool center = false,
    FontWeight? weight,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, color: color ?? pal.muted, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = right ? -tp.width : (center ? -tp.width / 2 : 0.0);
    tp.paint(canvas, at + Offset(dx, -tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = g.plot;
    final grid = Paint()
      ..color = pal.line
      ..strokeWidth = 1;

    // Horizontal grid + value labels.
    for (var v = g.yMin; v <= g.yMax + 1e-9; v += g.yStep) {
      final y = g.at(0, v).dy;
      canvas.drawLine(Offset(p.left, y), Offset(p.right, y), grid);
      final label = g.yStep < 1 ? v.toStringAsFixed(g.yStep < 0.5 ? 2 : 1) : v.toStringAsFixed(0);
      _text(canvas, label, Offset(p.left - 6, y), right: true);
    }
    _text(canvas, unit, Offset(p.left - 6, p.top - 18), right: true, weight: FontWeight.w600);

    // Age ticks.
    final unitDays = g.weeks ? 7.0 : 365.25 / 12;
    final span = g.maxDays / unitDays;
    final every = g.weeks ? (span > 16 ? 4 : 2) : (span > 12 ? 3 : (span > 6 ? 2 : 1));
    for (var i = 0; i * unitDays <= g.maxDays + 0.01; i += every) {
      final x = g.at(i * unitDays, g.yMin).dx;
      canvas.drawLine(Offset(x, p.bottom), Offset(x, p.bottom + 4), grid);
      _text(canvas, '$i', Offset(x, p.bottom + 12), center: true);
    }
    _text(canvas, g.weeks ? 'weeks' : 'months', Offset(p.right, p.bottom + 26), right: true);

    // Percentile curves, labelled at their right end.
    canvas.save();
    canvas.clipRect(p);
    final curveColor = Kind.milestone.on(pal);
    for (final (pct, z) in percentileCurves) {
      final path = Path();
      for (var d = 0.0; d <= g.maxDays; d += g.maxDays / 120) {
        final v = std.valueAt(d, z);
        if (v == null) continue;
        final o = g.at(d, g.display(v));
        d == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = curveColor.withValues(alpha: pct == 50 ? 0.95 : 0.55)
          ..strokeWidth = pct == 50 ? 2.2 : 1.1
          ..style = PaintingStyle.stroke,
      );
    }
    canvas.restore();
    for (final (pct, z) in percentileCurves) {
      final v = std.valueAt(g.maxDays, z);
      if (v == null) continue;
      _text(canvas, '$pct%', g.at(g.maxDays, g.display(v)) + const Offset(4, 0), color: curveColor, size: 10);
    }

    // The child's measurements.
    final pts = g.points.where((pt) => pt.days <= g.maxDays).map((pt) => (pt, g.at(pt.days, g.display(pt.metric)))).toList();
    final line = Paint()
      ..color = pal.accent
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    for (var i = 1; i < pts.length; i++) {
      canvas.drawLine(pts[i - 1].$2, pts[i].$2, line);
    }
    for (final (pt, o) in pts) {
      final isSel = pt.event.id == selected?.event.id;
      canvas.drawCircle(o, isSel ? 7 : 4.5, Paint()..color = pal.accent);
      if (isSel) {
        canvas.drawCircle(
          o,
          12,
          Paint()
            ..color = pal.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GrowthPainter old) => true;
}
