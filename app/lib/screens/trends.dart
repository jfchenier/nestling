import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../l10n/l10n.dart';
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
      appBar: AppBar(title: Text(l10n.trendsTitle)),
      body: Constrained(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              SegmentedButton<int>(
                segments: [
                  for (final n in const [7, 14, 30]) ButtonSegment(value: n, label: Text(l10n.trendsDays(n))),
                ],
                selected: {_days},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _days = v.first),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: Icon(Icons.show_chart_rounded, color: Kind.growth.on(context.pal)),
                  title: Text(l10n.growthTitle),
                  subtitle: Text(l10n.trendsGrowthChartsSub),
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
                    '${l10n.trendsIntro(toInt(avg['days']) ?? 0, s.family?.dayEnd ?? '18:00', s.family?.dayStart ?? '06:00')} '
                    '${prev == null ? l10n.trendsCompareNone(_days) : l10n.trendsCompareArrows(_days)}',
                    style: TextStyle(color: context.pal.muted, fontSize: 12),
                  ),
                ),
                SectionTitle(l10n.trendsFeed),
                _AverageGrid(
                  items: [
                    _Stat(
                      Kind.breast,
                      l10n.trendsFeeds,
                      'feeds_per_day',
                      l10n.trendsPerDay,
                      count,
                      lines: [
                        if (either('breast_feeds_per_day')) (l10n.kindBreastfeed, count(avg['breast_feeds_per_day'])),
                        if (either('bottle_feeds_per_day')) (l10n.kindBottle, count(avg['bottle_feeds_per_day'])),
                        if (either('solids_per_day')) (l10n.kindSolids, count(avg['solids_per_day'])),
                      ],
                      lineColors: feedColors,
                    ),
                    if (either('breast_seconds_per_day')) ...[
                      for (final (key, title) in [
                        ('', l10n.trendsBreastfeeding),
                        ('day_', l10n.trendsDayBreastfeeding),
                        ('night_', l10n.trendsNightBreastfeeding),
                      ])
                        _Stat(
                          Kind.breast,
                          title,
                          '${key}breast_seconds_per_day',
                          l10n.trendsPerDay,
                          time,
                          lines: [
                            (l10n.left, time(avg['${key}breast_left_seconds_per_day'])),
                            (l10n.right, time(avg['${key}breast_right_seconds_per_day'])),
                          ],
                        ),
                      _Stat(Kind.breast, l10n.trendsBreastfeedLength, 'avg_breastfeed_seconds', l10n.trendsAverage, time),
                    ],
                    if (either('bottle_ml_per_day')) ...[
                      _Stat(
                        Kind.bottle,
                        l10n.kindBottle,
                        'bottle_ml_per_day',
                        l10n.trendsPerDay,
                        volume,
                        lines: [
                          if (either('breast_milk_ml_per_day')) (l10n.milkBreastMilk, volume(avg['breast_milk_ml_per_day'])),
                          if (either('formula_ml_per_day')) (l10n.milkFormula, volume(avg['formula_ml_per_day'])),
                          if (either('mixed_ml_per_day')) (l10n.milkMixed, volume(avg['mixed_ml_per_day'])),
                        ],
                      ),
                      _Stat(Kind.bottle, l10n.trendsBottleSize, 'avg_bottle_ml', l10n.trendsAverage, volume),
                    ],
                    _Stat(Kind.breast, l10n.trendsFeedInterval, 'feed_interval_seconds', l10n.trendsAverage, time),
                  ],
                  previous: prev,
                  current: avg,
                ),
                const SizedBox(height: 10),
                _Chart(
                  days: days,
                  kind: Kind.breast,
                  legend: [l10n.kindBreastfeed, l10n.kindBottle, l10n.kindSolids],
                  stacks: (d) => [
                    (toDouble(d['feed']['breast_count']) ?? 0),
                    (toDouble(d['feed']['bottle_count']) ?? 0),
                    (toDouble(d['feed']['solids_count']) ?? 0),
                  ],
                  label: (v) => v.toStringAsFixed(0),
                  colors: feedColors,
                ),
                if (days.any((d) => (toDouble(d['feed']['bottle_ml']) ?? 0) > 0)) ...[
                  SectionTitle(l10n.trendsBottleUnit(u.volumeUnit)),
                  _Chart(
                    days: days,
                    kind: Kind.bottle,
                    stacks: (d) => [u.volumeIn(toDouble(d['feed']['bottle_ml']) ?? 0)],
                    label: (v) => v.toStringAsFixed(0),
                  ),
                ],
                if (either('pumps_per_day')) ...[
                  SectionTitle(l10n.kindPump),
                  _AverageGrid(
                    items: [
                      _Stat(Kind.pump, l10n.trendsPumpSessions, 'pumps_per_day', l10n.trendsPerDay, count),
                      _Stat(Kind.pump, l10n.trendsAmountPumped, 'pumped_ml_per_day', l10n.trendsPerDay, volume),
                      _Stat(Kind.pump, l10n.trendsPumpTime, 'pump_seconds_per_day', l10n.trendsPerDay, time),
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
                SectionTitle(l10n.kindDiaper),
                _AverageGrid(
                  items: [
                    for (final (key, title) in [('', l10n.trendsDiapers), ('day_', l10n.trendsDayDiapers), ('night_', l10n.trendsNightDiapers)])
                      _Stat(
                        Kind.diaper,
                        title,
                        '${key}diapers_per_day',
                        l10n.trendsPerDay,
                        count,
                        lines: [(l10n.wet, count(avg['${key}wet_per_day'])), (l10n.dirty, count(avg['${key}dirty_per_day']))],
                      ),
                  ],
                  previous: prev,
                  current: avg,
                ),
                const SizedBox(height: 10),
                _Chart(
                  days: days,
                  kind: Kind.diaper,
                  legend: [l10n.dirty, l10n.trendsWetOnly],
                  stacks: (d) {
                    final count = toDouble(d['diaper']['count']) ?? 0, dirty = toDouble(d['diaper']['dirty']) ?? 0;
                    return [dirty, count - dirty];
                  },
                  label: (v) => v.toStringAsFixed(0),
                ),
                if (either('potty_per_day')) ...[
                  SectionTitle(l10n.kindPotty),
                  _AverageGrid(
                    items: [
                      _Stat(
                        Kind.potty,
                        l10n.trendsPottyTrips,
                        'potty_per_day',
                        l10n.trendsPerDay,
                        count,
                        lines: [(l10n.inThePotty, count(avg['potty_success_per_day'])), (l10n.trendsAccidents, count(avg['potty_accidents_per_day']))],
                      ),
                      _Stat(Kind.potty, l10n.inThePotty, 'potty_success_per_day', l10n.trendsPerDay, count),
                      _Stat(Kind.potty, l10n.trendsAccidents, 'potty_accidents_per_day', l10n.trendsPerDay, count),
                    ],
                    previous: prev,
                    current: avg,
                  ),
                  const SizedBox(height: 10),
                  _Chart(
                    days: days,
                    kind: Kind.potty,
                    legend: [l10n.inThePotty, l10n.pottyAccident, l10n.pottySatDry],
                    stacks: (d) {
                      final all = toDouble(d['diaper']['potty_count']) ?? 0;
                      final ok = toDouble(d['diaper']['potty_success']) ?? 0, oops = toDouble(d['diaper']['potty_accidents']) ?? 0;
                      return [ok, oops, all - ok - oops];
                    },
                    label: (v) => v.toStringAsFixed(0),
                  ),
                ],
                SectionTitle(l10n.kindSleep),
                _AverageGrid(
                  items: [
                    _Stat(Kind.sleep, l10n.kindSleep, 'sleep_seconds_per_day', l10n.trendsPerDay, time),
                    _Stat(Kind.sleep, l10n.trendsDaySleep, 'day_sleep_seconds_per_day', l10n.trendsPerDay, time),
                    _Stat(Kind.sleep, l10n.trendsNightSleep, 'night_sleep_seconds_per_day', l10n.trendsPerDay, time),
                    _Stat(Kind.sleep, l10n.trendsLongestSleep, 'longest_sleep_seconds', l10n.trendsAverage, time),
                    _Stat(Kind.sleep, l10n.trendsNaps, 'naps_per_day', l10n.trendsPerDay, count),
                    _Stat(Kind.sleep, l10n.trendsNapLength, 'avg_nap_seconds', l10n.trendsAverage, time),
                    _Stat(Kind.sleep, l10n.trendsWakeWindow, 'wake_window_seconds', l10n.trendsAverage, time),
                  ],
                  previous: prev,
                  current: avg,
                ),
                const SizedBox(height: 10),
                _Chart(
                  days: days,
                  kind: Kind.sleep,
                  legend: [l10n.trendsNight, l10n.trendsDay],
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
