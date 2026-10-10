import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Counts and totals per type of entry, for today or the last 24 hours.
/// Opened from the timeline's top bar, so it slides down from the top and stays there.
Future<void> showSummary(BuildContext context) => showGeneralDialog(
  context: context,
  barrierDismissible: true,
  barrierLabel: l10n.summaryClose,
  barrierColor: Colors.black54,
  transitionDuration: const Duration(milliseconds: 280),
  pageBuilder: (context, _, _) => Align(
    alignment: Alignment.topCenter,
    child: Material(
      color: context.pal.background,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: const SafeArea(bottom: false, child: _SummarySheet()),
    ),
  ),
  transitionBuilder: (context, animation, _, child) => SlideTransition(
    position: Tween(begin: const Offset(0, -1), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
    child: child,
  ),
);

class _SummarySheet extends StatefulWidget {
  const _SummarySheet();

  @override
  State<_SummarySheet> createState() => _SummarySheetState();
}

class _SummarySheetState extends State<_SummarySheet> {
  bool _rolling = true; // last 24 hours (else: today since midnight)
  List<Event>? _events;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime get _from {
    final now = DateTime.now();
    return _rolling ? now.subtract(const Duration(hours: 24)) : DateTime(now.year, now.month, now.day);
  }

  Future<void> _load() async {
    final s = context.read<AppState>();
    final now = DateTime.now();
    // Enough for both views; filtered locally when switching.
    final from = DateTime(now.year, now.month, now.day).isBefore(now.subtract(const Duration(hours: 24)))
        ? DateTime(now.year, now.month, now.day)
        : now.subtract(const Duration(hours: 24));
    final res = await guard(context, () => s.api!.get('/children/${s.childId}/events', {'from': formatTime(from), 'limit': '1000'}));
    if (mounted && res != null) setState(() => _events = [for (final e in res['events'] as List) Event(e)]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final u = context.read<AppState>().units;
    final from = _from;
    final events = [
      for (final e in _events ?? const <Event>[])
        if (!e.start.isBefore(from)) e,
    ];
    final groups = _groups(events, u);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 640, maxHeight: MediaQuery.sizeOf(context).height * 0.92),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(
              children: [
                IconButton(tooltip: l10n.close, icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                Expanded(
                  child: Text(l10n.summaryTitle, textAlign: TextAlign.center, style: serifStyle(24)),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(l10n.today)),
                ButtonSegment(value: true, label: Text(l10n.summaryLast24h)),
              ],
              selected: {_rolling},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _rolling = v.first),
            ),
          ),
          Divider(height: 1, color: c.line),
          Flexible(
            child: _events == null
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : groups.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(
                      l10n.summaryNothing,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.muted),
                    ),
                  )
                : ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 24), children: [for (final g in groups) _GroupRow(g)]),
          ),
        ],
      ),
    );
  }
}

class _Group {
  _Group(this.kind, this.title, this.count, this.lines);
  final Kind kind;
  final String title;
  final int count;
  final List<String> lines;
}

int _secs(Event e, String k) => toInt(e[k]) ?? 0;
double _num(Event e, String k) => toDouble(e[k]) ?? 0;

/// One group per type that has entries, in the home cards' order.
List<_Group> _groups(List<Event> events, Units u) {
  List<Event> of(bool Function(Event) test) => [
    for (final e in events)
      if (test(e)) e,
  ];
  String names(List<Event> list, String key) {
    final counts = <String, int>{};
    for (final e in list) {
      final n = (e[key] as String?)?.trim();
      if (n != null && n.isNotEmpty) counts[n] = (counts[n] ?? 0) + 1;
    }
    return counts.entries.map((e) => e.value > 1 ? '${e.key} ×${e.value}' : e.key).join(', ');
  }

  final out = <_Group>[];
  void add(Kind kind, String title, List<Event> list, List<String> lines) {
    if (list.isEmpty) return;
    out.add(
      _Group(kind, title, list.length, [
        for (final l in lines)
          if (l.isNotEmpty) l,
      ]),
    );
  }

  final breast = of((e) => e.type == 'feed' && (e['method'] == 'breast' || e['method'] == null || e['method'] == 'combo'));
  final left = breast.fold<int>(0, (a, e) => a + _secs(e, 'left_seconds')),
      right = breast.fold<int>(0, (a, e) => a + _secs(e, 'right_seconds'));
  add(Kind.breast, l10n.kindBreastfeed, breast, [
    l10n.summaryTotal(duration(left + right)),
    [if (left > 0) l10n.summaryLeft(duration(left)), if (right > 0) l10n.summaryRight(duration(right))].join(' · '),
  ]);

  final bottle = of((e) => e.type == 'feed' && (e['method'] == 'bottle' || e['method'] == 'combo') && toDouble(e['amount_ml']) != null);
  final breastMilk = bottle.where((e) => e['milk'] == 'breast_milk').fold<double>(0.0, (a, e) => a + _num(e, 'amount_ml'));
  final formula = bottle.where((e) => e['milk'] == 'formula').fold<double>(0.0, (a, e) => a + _num(e, 'amount_ml'));
  add(Kind.bottle, l10n.kindBottle, bottle, [
    l10n.summaryTotal(u.volume(bottle.fold<double>(0.0, (a, e) => a + _num(e, 'amount_ml')))),
    [if (breastMilk > 0) l10n.summaryBreastMilk(u.volume(breastMilk)), if (formula > 0) l10n.summaryFormula(u.volume(formula))].join(' · '),
  ]);

  final solids = of((e) => e.type == 'feed' && e['method'] == 'solids');
  add(Kind.solids, l10n.kindSolids, solids, [names(solids, 'foods')]);

  final sleeps = of((e) => e.type == 'sleep');
  final slept = sleeps.fold(0, (a, e) => a + (e.durationSeconds ?? 0));
  final longest = sleeps.fold(0, (a, e) => (e.durationSeconds ?? 0) > a ? e.durationSeconds! : a);
  add(Kind.sleep, l10n.kindSleep, sleeps, [l10n.summaryTotal(duration(slept)), if (sleeps.length > 1) l10n.summaryLongest(duration(longest))]);

  final diapers = of((e) => e.type == 'diaper' && e['potty'] == null);
  final wet = diapers.where((e) => e['wet'] == true).length, dirty = diapers.where((e) => e['dirty'] == true).length;
  add(Kind.diaper, l10n.kindDiaper, diapers, [l10n.summaryWetDirty(dirty, wet)]);

  final potty = of((e) => e.type == 'diaper' && e['potty'] != null);
  final inPotty = potty.where((e) => e['potty'] == 'success').length, accidents = potty.where((e) => e['potty'] == 'accident').length;
  add(Kind.potty, l10n.kindPotty, potty, [l10n.summaryPotty(accidents, inPotty)]);

  final pumps = of((e) => e.type == 'pump');
  final pumped = pumps.fold<double>(0.0, (a, e) => a + _num(e, 'left_ml') + _num(e, 'right_ml'));
  final pumpTime = pumps.fold(0, (a, e) => a + (e.durationSeconds ?? 0));
  add(Kind.pump, l10n.kindPump, pumps, [if (pumped > 0) l10n.summaryTotal(u.volume(pumped)), if (pumpTime > 0) l10n.summaryPumping(duration(pumpTime))]);

  final growth = of((e) => e.type == 'growth');
  add(Kind.growth, l10n.kindGrowth, growth, [
    if (growth.isNotEmpty)
      [
        if (toDouble(growth.first['weight_g']) case final g?) u.weight(g),
        if (toDouble(growth.first['length_cm']) case final l?) u.length(l),
        if (toDouble(growth.first['head_cm']) case final h?) l10n.summaryHead(u.length(h)),
      ].join(' · '),
  ]);

  final health = of((e) => e.type == 'health');
  final temps = [for (final e in health) ?toDouble(e['temperature_c'])];
  add(Kind.health, l10n.kindHealth, health, [
    names([
      for (final e in health)
        if (e['kind'] != 'temperature') e,
    ], 'name'),
    if (temps.isNotEmpty) l10n.summaryTemperature(temps.map(u.temp).join(', ')),
  ]);

  final activities = of((e) => e.type == 'activity');
  final activityTime = activities.fold(0, (a, e) => a + (e.durationSeconds ?? 0));
  final kinds = <String, int>{};
  for (final e in activities) {
    final k = cap(e['kind'] as String?);
    kinds[k] = (kinds[k] ?? 0) + 1;
  }
  add(Kind.activity, l10n.summaryRoutine, activities, [
    kinds.entries.map((e) => e.value > 1 ? '${e.key} ×${e.value}' : e.key).join(', '),
    if (activityTime > 0) l10n.summaryTotal(duration(activityTime)),
  ]);

  final milestones = of((e) => e.type == 'milestone');
  add(Kind.milestone, l10n.summaryFirsts, milestones, [names(milestones, 'name')]);

  final notes = of((e) => e.type == 'note');
  add(Kind.note, l10n.summaryNotes, notes, [names(notes, 'note')]);
  return out;
}

class _GroupRow extends StatelessWidget {
  const _GroupRow(this.g);
  final _Group g;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlobIcon(g.kind, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(g.title, style: serifStyle(19))),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(color: g.kind.fill(c), borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        '${g.count}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: c.bandInk),
                      ),
                    ),
                  ],
                ),
                for (final l in g.lines)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(l, style: TextStyle(color: c.ink, fontSize: 15)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
