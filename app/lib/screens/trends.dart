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
    final prev = data?['previous'] as Map<String, dynamic>?;
    final u = s.units;
    // Formats for each kind of value (also used for the change since the previous period).
    String count(dynamic v) => (toDouble(v) ?? 0).toStringAsFixed(1);
    String time(dynamic v) => duration(toInt(v), showSeconds: true).ifEmpty('—');
    String volume(dynamic v) => u.volume(toDouble(v)).ifEmpty('—');
    bool either(String key) => (toDouble(avg[key]) ?? 0) > 0 || (toDouble(prev?[key]) ?? 0) > 0;
    final feedColors = [Kind.breast.on(context.pal), Kind.bottle.color, Kind.solids.deepTone];

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
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
                  child: Text(
                    'Daily averages over ${avg['days'] ?? 0} full days; daytime is ${s.family?.dayStart ?? '06:00'}–${s.family?.dayEnd ?? '18:00'}. '
                    '${prev == null ? 'Nothing logged in the $_days days before to compare with.' : 'Arrows compare with the $_days days before.'}',
                    style: TextStyle(color: context.pal.muted, fontSize: 12),
                  ),
                ),
                const SectionTitle('Feed'),
                _AverageGrid(
                  items: [
                    _Stat(
                      Kind.breast,
                      'Feeds',
                      'feeds_per_day',
                      'per day',
                      count,
                      lines: [
                        if (either('breast_feeds_per_day')) ('Breastfeed', count(avg['breast_feeds_per_day'])),
                        if (either('bottle_feeds_per_day')) ('Bottle', count(avg['bottle_feeds_per_day'])),
                        if (either('solids_per_day')) ('Solids', count(avg['solids_per_day'])),
                      ],
                      lineColors: feedColors,
                    ),
                    if (either('breast_seconds_per_day')) ...[
                      for (final (key, title) in [
                        ('', 'Breastfeeding'),
                        ('day_', 'Daytime breastfeeding'),
                        ('night_', 'Nighttime breastfeeding'),
                      ])
                        _Stat(
                          Kind.breast,
                          title,
                          '${key}breast_seconds_per_day',
                          'per day',
                          time,
                          lines: [
                            ('Left', time(avg['${key}breast_left_seconds_per_day'])),
                            ('Right', time(avg['${key}breast_right_seconds_per_day'])),
                          ],
                        ),
                      _Stat(Kind.breast, 'Breastfeed length', 'avg_breastfeed_seconds', 'average', time),
                    ],
                    if (either('bottle_ml_per_day')) ...[
                      _Stat(
                        Kind.bottle,
                        'Bottle',
                        'bottle_ml_per_day',
                        'per day',
                        volume,
                        lines: [
                          if (either('breast_milk_ml_per_day')) ('Breast milk', volume(avg['breast_milk_ml_per_day'])),
                          if (either('formula_ml_per_day')) ('Formula', volume(avg['formula_ml_per_day'])),
                          if (either('mixed_ml_per_day')) ('Mixed', volume(avg['mixed_ml_per_day'])),
                        ],
                      ),
                      _Stat(Kind.bottle, 'Bottle size', 'avg_bottle_ml', 'average', volume),
                    ],
                    _Stat(Kind.breast, 'Time between feeds', 'feed_interval_seconds', 'average', time),
                  ],
                  previous: prev,
                  current: avg,
                ),
                const SizedBox(height: 10),
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
                  colors: feedColors,
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
                if (either('pumps_per_day')) ...[
                  const SectionTitle('Pump'),
                  _AverageGrid(
                    items: [
                      _Stat(Kind.pump, 'Pump sessions', 'pumps_per_day', 'per day', count),
                      _Stat(Kind.pump, 'Amount pumped', 'pumped_ml_per_day', 'per day', volume),
                      _Stat(Kind.pump, 'Pump time', 'pump_seconds_per_day', 'per day', time),
                    ],
                    previous: prev,
                    current: avg,
                  ),
                  if (days.any((d) => (toDouble(d['pump']['total_ml']) ?? 0) > 0)) ...[
                    const SizedBox(height: 10),
                    _Chart(
                      days: days,
                      kind: Kind.pump,
                      stacks: (d) => [u.volumeIn(toDouble(d['pump']['total_ml']) ?? 0)],
                      label: (v) => v.toStringAsFixed(0),
                    ),
                  ],
                ],
                const SectionTitle('Diaper'),
                _AverageGrid(
                  items: [
                    for (final (key, title) in [('', 'Diapers'), ('day_', 'Daytime diapers'), ('night_', 'Nighttime diapers')])
                      _Stat(
                        Kind.diaper,
                        title,
                        '${key}diapers_per_day',
                        'per day',
                        count,
                        lines: [('Wet', count(avg['${key}wet_per_day'])), ('Dirty', count(avg['${key}dirty_per_day']))],
                      ),
                  ],
                  previous: prev,
                  current: avg,
                ),
                const SizedBox(height: 10),
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
                const SectionTitle('Sleep'),
                _AverageGrid(
                  items: [
                    _Stat(Kind.sleep, 'Sleep', 'sleep_seconds_per_day', 'per day', time),
                    _Stat(Kind.sleep, 'Daytime sleep', 'day_sleep_seconds_per_day', 'per day', time),
                    _Stat(Kind.sleep, 'Nighttime sleep', 'night_sleep_seconds_per_day', 'per day', time),
                    _Stat(Kind.sleep, 'Longest sleep', 'longest_sleep_seconds', 'average', time),
                    _Stat(Kind.sleep, 'Naps', 'naps_per_day', 'per day', count),
                    _Stat(Kind.sleep, 'Nap length', 'avg_nap_seconds', 'average', time),
                    _Stat(Kind.sleep, 'Wake window', 'wake_window_seconds', 'average', time),
                  ],
                  previous: prev,
                  current: avg,
                ),
                const SizedBox(height: 10),
                _Chart(
                  days: days,
                  kind: Kind.sleep,
                  legend: const ['Night', 'Day'],
                  stacks: (d) => [(toDouble(d['sleep']['night_seconds']) ?? 0) / 3600, (toDouble(d['sleep']['day_seconds']) ?? 0) / 3600],
                  label: (v) => '${v.toStringAsFixed(1)} h',
                ),
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

/// One average: [key] in `averages` (and `previous`), shown with [format]; [lines] break it down.
class _Stat {
  const _Stat(this.kind, this.title, this.key, this.sub, this.format, {this.lines = const [], this.lineColors});
  final Kind kind;
  final String title;
  final String key;
  final String sub;
  final String Function(dynamic) format;
  final List<(String, String)> lines;
  final List<Color>? lineColors;
}

class _AverageGrid extends StatelessWidget {
  const _AverageGrid({required this.items, required this.current, this.previous});
  final List<_Stat> items;
  final Map<String, dynamic> current;
  final Map<String, dynamic>? previous;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final cols = box.maxWidth > 500 ? 3 : 2;
      // Rows of equal-height cards.
      return Column(
        children: [
          for (var i = 0; i < items.length; i += cols)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = i; j < i + cols; j++) ...[
                      if (j > i) const SizedBox(width: 10),
                      Expanded(child: j < items.length ? _card(context, items[j]) : const SizedBox()),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _card(BuildContext context, _Stat st) {
    final pal = context.pal;
    final cur = toDouble(current[st.key]), prev = toDouble(previous?[st.key]);
    final colors = st.lineColors ?? [st.kind.on(pal), Color.lerp(st.kind.on(pal), pal.surface, 0.5)!];
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Same colored band as the home cards.
          Container(
            color: st.kind.fill(pal),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(
              st.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: pal.bandInk, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(st.format(current[st.key]), style: serifStyle(24)),
                Row(
                  children: [
                    Expanded(
                      child: Text(st.sub, style: TextStyle(color: pal.muted, fontSize: 13)),
                    ),
                    if (cur != null && prev != null) _Change(st.kind, cur - prev, st.format),
                  ],
                ),
                if (st.lines.isNotEmpty) const SizedBox(height: 8),
                for (final (k, (label, value)) in st.lines.indexed)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: colors[k % colors.length], shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(label, style: TextStyle(color: pal.muted, fontSize: 13)),
                        ),
                        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
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

/// Change since the previous period: "↑ 21m 10s" on the kind's color. Nothing when it rounds to zero.
class _Change extends StatelessWidget {
  const _Change(this.kind, this.diff, this.format);
  final Kind kind;
  final double diff;
  final String Function(dynamic) format;

  @override
  Widget build(BuildContext context) {
    final text = format(diff.abs());
    if (RegExp(r'^[0.]+$|^0s$|^0 ').hasMatch(text) || text == '—') return const SizedBox.shrink();
    final pal = context.pal;
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: kind.fill(pal), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(diff > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 12, color: pal.bandInk),
          const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(color: pal.bandInk, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
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
