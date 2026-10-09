import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'growth_chart.dart';

/// Daily totals and averages from `/children/{id}/trends`.
class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  int _days = 7;
  Map<String, dynamic>? _data;
  (String?, int, int)? _loadedFor;

  Future<void> _load() async {
    final s = context.read<AppState>();
    if (s.childId == null) return;
    final res = await guard(context, () => s.api!.get('/children/${s.childId}/trends', {'days': '$_days'}));
    if (mounted && res != null) setState(() => _data = res);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final key = (s.childId, s.revision, _days);
    if (_loadedFor != key) {
      _loadedFor = key;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    final data = _data;
    final days = [for (final d in (data?['days'] as List? ?? [])) d as Map<String, dynamic>];
    final avg = data?['averages'] as Map<String, dynamic>? ?? {};
    final u = s.units;

    return Scaffold(
      appBar: AppBar(title: const Text('Trends')),
      body: Constrained(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('7 days')),
                  ButtonSegment(value: 14, label: Text('14 days')),
                  ButtonSegment(value: 30, label: Text('30 days')),
                ],
                selected: {_days},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _days = v.first),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: Icon(Icons.show_chart_rounded, color: Kind.growth.on(context.pal)),
                  title: const Text('Growth charts'),
                  subtitle: const Text('Weight, length and head size on the WHO percentile curves'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GrowthChartScreen())),
                ),
              ),
              if (data == null)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                SectionTitle(
                  'Daily averages',
                  trailing: Text('${avg['days'] ?? 0} full days', style: TextStyle(color: context.pal.muted, fontSize: 12)),
                ),
                _AverageGrid(
                  items: [
                    (Kind.breast, 'Feeds', (toDouble(avg['feeds_per_day']) ?? 0).toStringAsFixed(1), 'per day'),
                    (Kind.breast, 'Feed interval', duration(toInt(avg['feed_interval_seconds'])).ifEmpty('—'), 'between feeds'),
                    (Kind.sleep, 'Sleep', duration(toInt(avg['sleep_seconds_per_day']) ?? 0), 'per day'),
                    (Kind.sleep, 'Wake window', duration(toInt(avg['wake_window_seconds'])).ifEmpty('—'), 'average'),
                    (
                      Kind.sleep,
                      'Naps',
                      (toDouble(avg['naps_per_day']) ?? 0).toStringAsFixed(1),
                      'avg ${duration(toInt(avg['avg_nap_seconds'])).ifEmpty('—')}',
                    ),
                    (Kind.diaper, 'Diapers', (toDouble(avg['diapers_per_day']) ?? 0).toStringAsFixed(1), 'per day'),
                    if (avg['avg_bottle_ml'] != null)
                      (
                        Kind.bottle,
                        'Bottle',
                        u.volume(toDouble(avg['avg_bottle_ml'])),
                        '${u.volume(toDouble(avg['bottle_ml_per_day']) ?? 0)} / day',
                      ),
                    if (avg['avg_breastfeed_seconds'] != null)
                      (Kind.breast, 'Breastfeed', duration(toInt(avg['avg_breastfeed_seconds'])), 'per feed'),
                    if ((toDouble(avg['pumped_ml_per_day']) ?? 0) > 0)
                      (Kind.pump, 'Pumped', u.volume(toDouble(avg['pumped_ml_per_day'])), 'per day'),
                  ],
                ),
                const SectionTitle('Sleep'),
                _Chart(
                  days: days,
                  kind: Kind.sleep,
                  legend: const ['Night', 'Day'],
                  stacks: (d) => [(toDouble(d['sleep']['night_seconds']) ?? 0) / 3600, (toDouble(d['sleep']['day_seconds']) ?? 0) / 3600],
                  label: (v) => '${v.toStringAsFixed(1)} h',
                ),
                const SectionTitle('Feeds'),
                _Chart(
                  days: days,
                  kind: Kind.breast,
                  legend: const ['Breastfeed', 'Bottle', 'Solids'],
                  stacks: (d) => [
                    (toDouble(d['feed']['breast_count']) ?? 0),
                    (toDouble(d['feed']['bottle_count']) ?? 0),
                    (toDouble(d['feed']['solids_count']) ?? 0),
                  ],
                  label: (v) => v.toStringAsFixed(0),
                  colors: [Kind.breast.on(context.pal), Kind.bottle.color, Kind.solids.deepTone],
                ),
                if (days.any((d) => (toDouble(d['feed']['bottle_ml']) ?? 0) > 0)) ...[
                  SectionTitle('Bottle (${u.volumeUnit})'),
                  _Chart(
                    days: days,
                    kind: Kind.bottle,
                    stacks: (d) => [u.volumeIn(toDouble(d['feed']['bottle_ml']) ?? 0)],
                    label: (v) => v.toStringAsFixed(0),
                  ),
                ],
                const SectionTitle('Diapers'),
                _Chart(
                  days: days,
                  kind: Kind.diaper,
                  legend: const ['Dirty', 'Wet only'],
                  stacks: (d) {
                    final count = toDouble(d['diaper']['count']) ?? 0, dirty = toDouble(d['diaper']['dirty']) ?? 0;
                    return [dirty, count - dirty];
                  },
                  label: (v) => v.toStringAsFixed(0),
                ),
                if (days.any((d) => (toDouble(d['pump']['total_ml']) ?? 0) > 0)) ...[
                  SectionTitle('Pumped (${u.volumeUnit})'),
                  _Chart(
                    days: days,
                    kind: Kind.pump,
                    stacks: (d) => [u.volumeIn(toDouble(d['pump']['total_ml']) ?? 0)],
                    label: (v) => v.toStringAsFixed(0),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

class _AverageGrid extends StatelessWidget {
  const _AverageGrid({required this.items});
  final List<(Kind, String, String, String)> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final cols = box.maxWidth > 500 ? 3 : 2;
      final w = (box.maxWidth - 10 * (cols - 1)) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final (k, title, value, sub) in items)
            SizedBox(
              width: w,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Same colored band as the home cards.
                    Container(
                      color: k.fill(context.pal),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.pal.bandInk, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(value, style: serifStyle(24)),
                          Text(sub, style: TextStyle(color: context.pal.muted, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// Stacked daily bars. The first stack uses the deep color, the rest lighter shades.
class _Chart extends StatelessWidget {
  const _Chart({required this.days, required this.kind, required this.stacks, required this.label, this.legend, this.colors});
  final List<Map<String, dynamic>> days;
  final Kind kind;
  final List<double> Function(Map<String, dynamic> day) stacks;
  final String Function(double) label;
  final List<String>? legend;
  final List<Color>? colors;

  List<Color> _colorsFor(AppColors c) =>
      colors ?? [kind.on(c), Color.lerp(kind.on(c), c.surface, 0.55)!, Color.lerp(kind.on(c), c.surface, 0.75)!];

  @override
  Widget build(BuildContext context) {
    final values = [for (final d in days) stacks(d)];
    final totals = [for (final v in values) v.fold<double>(0, (a, b) => a + b)];
    final maxY = totals.fold<double>(0, (a, b) => a > b ? a : b);
    final barWidth = days.length > 14
        ? 6.0
        : days.length > 7
        ? 12.0
        : 22.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 16, 12),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: maxY <= 0 ? 1 : maxY * 1.15,
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(color: context.pal.line, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (v, meta) => v == meta.max
                            ? const SizedBox.shrink()
                            : Text(label(v), style: TextStyle(fontSize: 10, color: context.pal.muted)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= days.length) return const SizedBox.shrink();
                          final step = days.length > 14
                              ? 5
                              : days.length > 7
                              ? 2
                              : 1;
                          if ((days.length - 1 - i) % step != 0) return const SizedBox.shrink();
                          final date = DateTime.parse(days[i]['date']);
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              days.length > 7 ? DateFormat.Md().format(date) : DateFormat.E().format(date),
                              style: TextStyle(fontSize: 10, color: context.pal.muted),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => context.pal.ink,
                      getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                        '${DateFormat.MMMd().format(DateTime.parse(days[group.x]['date']))}\n${label(rod.toY)}',
                        TextStyle(color: context.pal.bandInk, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ),
                  barGroups: [
                    for (final (i, v) in values.indexed)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: totals[i],
                            width: barWidth,
                            color: _colorsFor(context.pal).first,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(barWidth / 2.5)),
                            rodStackItems: v.length < 2
                                ? []
                                : [
                                    for (var j = 0, from = 0.0; j < v.length; from += v[j], j++)
                                      BarChartRodStackItem(from, from + v[j], _colorsFor(context.pal)[j % _colorsFor(context.pal).length]),
                                  ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            if (legend != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(
                  spacing: 16,
                  children: [
                    for (final (j, name) in legend!.indexed)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _colorsFor(context.pal)[j % _colorsFor(context.pal).length],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(name, style: TextStyle(fontSize: 12, color: context.pal.muted)),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
