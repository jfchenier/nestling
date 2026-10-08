import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/event_tile.dart';
import 'child_form.dart';
import 'event_form.dart';
import 'timer_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final child = s.child!;
    final today = s.summary?['today'] as Map<String, dynamic>?;
    final todays = s.recent.where((e) {
      final now = DateTime.now();
      return e.start.isAfter(DateTime(now.year, now.month, now.day));
    }).toList();
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: s.refreshChild,
          child: Constrained(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _Header(child: child, live: s.live),
                if (s.timers.isNotEmpty) ...[const SizedBox(height: 16), for (final t in s.timers) _TimerCard(timer: t)],
                const SizedBox(height: 16),
                const _SinceRow(),
                const SectionTitle('Track'),
                const _ActionGrid(),
                if (today != null) ...[const SectionTitle('Today'), _TodayTotals(today: today, units: s.units)],
                SectionTitle(
                  'Latest',
                  trailing: Text('${todays.length} today', style: const TextStyle(color: Palette.muted)),
                ),
                if (s.recent.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Nothing logged in the last 24 hours.\nTap a button above to start.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Palette.muted, height: 1.5),
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (final (i, e) in s.recent.take(12).indexed) ...[
                          if (i > 0) const Divider(height: 1, indent: 72, color: Palette.line),
                          EventTile(event: e),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.child, required this.live});
  final Child child;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _switchChild(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            ChildAvatar(child: child, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(child.name, style: t.headlineSmall, overflow: TextOverflow.ellipsis),
                      ),
                      const Icon(Icons.expand_more_rounded, color: Palette.muted),
                    ],
                  ),
                  if (child.age != null) Text(child.age!, style: t.bodyMedium?.copyWith(color: Palette.muted)),
                ],
              ),
            ),
            Tooltip(
              message: live ? 'Live — changes from other caregivers appear instantly' : 'Reconnecting…',
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: live ? const Color(0xFF5CB176) : Palette.line, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _switchChild(BuildContext context) {
    final s = context.read<AppState>();
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final f in s.families)
              for (final ch in f.children)
                ListTile(
                  leading: ChildAvatar(child: ch, size: 40),
                  title: Text(ch.name),
                  subtitle: Text([if (ch.age != null) ch.age!, if (s.families.length > 1) f.name].join(' · ')),
                  trailing: ch.id == s.childId ? const Icon(Icons.check_rounded) : null,
                  onTap: () {
                    Navigator.pop(c);
                    s.selectChild(ch.id);
                  },
                ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Palette.line,
                child: Icon(Icons.add, color: Palette.ink),
              ),
              title: const Text('Add a baby'),
              onTap: () {
                Navigator.pop(c);
                showChildForm(context, familyId: s.familyId!);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class ChildAvatar extends StatelessWidget {
  const ChildAvatar({super.key, required this.child, this.size = 48});
  final Child child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = switch (child.sex) {
      'female' => (const Color(0xFFF9D5CC), const Color(0xFFC4604A)),
      'male' => (const Color(0xFFD8DDF5), const Color(0xFF5162A8)),
      _ => (const Color(0xFFD3EBDD), const Color(0xFF3E8A62)),
    };
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.$1,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Text(
        child.name.isEmpty ? '?' : child.name.characters.first.toUpperCase(),
        style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w700, color: colors.$2),
      ),
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({required this.timer});
  final TimerModel timer;

  @override
  Widget build(BuildContext context) {
    final k = switch (timer.kind) {
      'sleep' => Kind.sleep,
      'pump' => Kind.pump,
      _ => Kind.breast,
    };
    final label = switch (timer.kind) {
      'sleep' => 'Sleeping',
      'pump' => 'Pumping',
      _ => 'Nursing',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: k.color,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => TimerScreen.open(context, timer.kind),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Ticking(
              builder: (_) => Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), shape: BoxShape.circle),
                    child: Icon(k.icon, color: k.deep),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          timer.running ? label : '$label · paused',
                          style: TextStyle(fontWeight: FontWeight.w700, color: k.deep),
                        ),
                        Text(
                          [
                            if (timer.side != null && timer.kind == 'breastfeed') '${timer.side == 'left' ? 'Left' : 'Right'} side',
                            'since ${timeOfDay(timer.startedAt)}',
                          ].join(' · '),
                          style: const TextStyle(color: Palette.ink),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    clock(timer.elapsed),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w300,
                      color: k.deep,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Time since" cards for feed, sleep and diaper, like Nara's dashboard.
class _SinceRow extends StatelessWidget {
  const _SinceRow();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    Event? last(String type) {
      final v = s.summary?['last']?[type];
      return v is Map<String, dynamic> ? Event(v) : null;
    }

    final feed = last('feed'), sleep = last('sleep'), diaper = last('diaper');
    final sleeping = s.timers.where((t) => t.kind == 'sleep').firstOrNull;
    return Ticking(
      builder: (context) {
        final now = DateTime.now();
        String? feedSub;
        if (feed != null) {
          final (title, detail) = describe(feed, s.units);
          final end = feed.endSide;
          feedSub = end != null ? 'Next: ${end == 'left' ? 'Right' : 'Left'}' : (detail.isEmpty ? title : detail);
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SinceCard(
                  kind: Kind.breast,
                  title: 'Feed',
                  value: feed == null ? null : now.difference(feed.start).inSeconds,
                  sub: feedSub,
                  onTap: () => showEventForm(context, type: 'feed', method: feed?['method'] ?? 'bottle'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SinceCard(
                  kind: Kind.sleep,
                  title: sleeping != null ? 'Asleep' : 'Awake',
                  value: sleeping != null
                      ? sleeping.elapsed
                      : sleep == null
                      ? null
                      : now.difference(sleep.end ?? sleep.start).inSeconds,
                  sub: sleeping != null ? 'so far' : (sleep == null ? null : 'Last nap ${duration(sleep.durationSeconds)}'),
                  ago: sleeping == null,
                  onTap: () => TimerScreen.open(context, 'sleep'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SinceCard(
                  kind: Kind.diaper,
                  title: 'Diaper',
                  value: diaper == null ? null : now.difference(diaper.start).inSeconds,
                  sub: diaper == null ? null : describe(diaper, s.units).$2.split(' · ').first,
                  onTap: () => showEventForm(context, type: 'diaper'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SinceCard extends StatelessWidget {
  const _SinceCard({required this.kind, required this.title, required this.value, this.sub, this.ago = true, required this.onTap});
  final Kind kind;
  final String title;
  final int? value;
  final String? sub;
  final bool ago;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(kind.icon, size: 18, color: kind.deep),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w700, color: kind.deep, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value == null ? '—' : duration(value),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Palette.ink),
              ),
            ),
            Text(
              value == null ? 'No entries yet' : (ago ? 'ago' : (sub ?? '')),
              style: const TextStyle(color: Palette.muted, fontSize: 12),
            ),
            if (ago && sub != null && sub!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                sub!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Palette.ink),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Big round buttons, one per activity.
class _ActionGrid extends StatelessWidget {
  const _ActionGrid();

  @override
  Widget build(BuildContext context) {
    final actions = <(Kind, VoidCallback)>[
      (Kind.breast, () => TimerScreen.open(context, 'breastfeed')),
      (Kind.bottle, () => showEventForm(context, type: 'feed', method: 'bottle')),
      (Kind.sleep, () => TimerScreen.open(context, 'sleep')),
      (Kind.diaper, () => showEventForm(context, type: 'diaper')),
      (Kind.pump, () => TimerScreen.open(context, 'pump')),
      (Kind.solids, () => showEventForm(context, type: 'feed', method: 'solids')),
      (Kind.growth, () => showEventForm(context, type: 'growth')),
      (Kind.health, () => showEventForm(context, type: 'health')),
      (Kind.activity, () => showEventForm(context, type: 'activity')),
      (Kind.milestone, () => showEventForm(context, type: 'milestone')),
      (Kind.note, () => showEventForm(context, type: 'note')),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final perRow = box.maxWidth > 520 ? 6 : 4;
        final w = box.maxWidth / perRow;
        return Wrap(
          runSpacing: 14,
          children: [
            for (final (k, onTap) in actions)
              SizedBox(
                width: w,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            color: k.color,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: k.deep.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 3))],
                          ),
                          child: Icon(k.icon, color: k.deep, size: 28),
                        ),
                        const SizedBox(height: 8),
                        Text(k.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TodayTotals extends StatelessWidget {
  const _TodayTotals({required this.today, required this.units});
  final Map<String, dynamic> today;
  final Units units;

  @override
  Widget build(BuildContext context) {
    final feed = today['feed'] as Map? ?? {}, sleep = today['sleep'] as Map? ?? {};
    final diaper = today['diaper'] as Map? ?? {}, pump = today['pump'] as Map? ?? {};
    final bottleMl = toDouble(feed['bottle_ml']) ?? 0;
    final pumped = toDouble(pump['total_ml']) ?? 0;
    final tiles = <(Kind, String, String)>[
      (
        Kind.breast,
        '${feed['count'] ?? 0}',
        [
          'feeds',
          if ((toInt(feed['breast_seconds']) ?? 0) > 0) duration(toInt(feed['breast_seconds'])),
          if (bottleMl > 0) units.volume(bottleMl),
        ].join(' · '),
      ),
      (Kind.sleep, duration(toInt(sleep['total_seconds']) ?? 0), '${sleep['nap_count'] ?? 0} naps'),
      (Kind.diaper, '${diaper['count'] ?? 0}', '${diaper['wet'] ?? 0} wet · ${diaper['dirty'] ?? 0} dirty'),
      if (pumped > 0 || (pump['count'] ?? 0) > 0) (Kind.pump, units.volume(pumped), '${pump['count']} sessions'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            for (final (k, big, small) in tiles)
              ListTile(
                leading: KindBadge(k, size: 38),
                title: Text(big, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                subtitle: Text(small),
                dense: true,
              ),
          ],
        ),
      ),
    );
  }
}
