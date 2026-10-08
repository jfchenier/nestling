import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'child_form.dart';
import 'event_form.dart';
import 'timeline.dart';
import 'timer_screen.dart';

/// Dashboard: one card per activity with the latest entry and a round + to log another.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    Event? last(String type) {
      final v = s.summary?['last']?[type];
      return v is Map<String, dynamic> ? Event(v) : null;
    }

    TimerModel? timer(String kind) => s.timers.where((t) => t.kind == kind).firstOrNull;
    Event? latest(String type) => s.others.where((e) => e.type == type).firstOrNull;
    void history(String filter) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TimelineScreen(initialFilter: filter)));
    final u = s.units;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: s.refreshChild,
          child: Constrained(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _Header(child: s.child!, live: s.live),
                const SizedBox(height: 20),
                if (s.summary?['today'] is Map) _TodayStrip(today: s.summary!['today'], units: u),
                _FeedCard(last: last('feed'), timer: timer('breastfeed'), onHistory: () => history('feed')),
                _TimedCard(
                  kind: Kind.pump,
                  title: 'Pump',
                  timerKind: 'pump',
                  timer: timer('pump'),
                  last: last('pump'),
                  lastTitle: 'Last pump',
                  empty: 'Track a pumping session',
                  value: (e) => describe(e, u).$2.split(' · ').first,
                  caption: (_) => 'pumped',
                  onHistory: () => history('pump'),
                ),
                _ActivityCard(
                  kind: Kind.diaper,
                  title: 'Diaper',
                  onAdd: () => showEventForm(context, type: 'diaper'),
                  onHistory: last('diaper') == null ? null : () => history('diaper'),
                  child: _diaper(context, last('diaper')),
                ),
                _TimedCard(
                  kind: Kind.sleep,
                  title: 'Sleep',
                  timerKind: 'sleep',
                  timer: timer('sleep'),
                  last: last('sleep'),
                  lastTitle: 'Woke up',
                  since: (e) => e.end ?? e.start,
                  empty: 'Track naps and nights',
                  value: (e) => duration(e.durationSeconds),
                  caption: (_) => 'slept',
                  onHistory: () => history('sleep'),
                ),
                _simpleCard(
                  context,
                  kind: Kind.activity,
                  title: 'Routine',
                  event: latest('activity'),
                  empty: 'Tummy time, baths, outings…',
                  type: 'activity',
                  label: (e) => cap(e['kind'] as String? ?? 'Activity'),
                  onHistory: () => history('activity,milestone,note'),
                ),
                _simpleCard(
                  context,
                  kind: Kind.milestone,
                  title: 'Firsts',
                  event: latest('milestone'),
                  empty: 'Track memorable moments',
                  type: 'milestone',
                  label: (e) => (e['name'] as String?) ?? 'Milestone',
                  onHistory: () => history('activity,milestone,note'),
                ),
                _GrowthCard(events: s.others.where((e) => e.type == 'growth').toList(), units: u, onHistory: () => history('growth')),
                _HealthCard(
                  events: s.others.where((e) => e.type == 'health').take(2).toList(),
                  units: u,
                  onHistory: () => history('health'),
                ),
                const SizedBox(height: 8),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () => showEventForm(context, type: 'note'),
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Add a note'),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Palette.line, width: 1.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _diaper(BuildContext context, Event? e) {
    if (e == null) return const _LastRow(kind: Kind.diaper, title: 'Track a diaper change');
    final value = e['dirty'] == true
        ? 'dirty'
        : e['wet'] == true
        ? 'wet'
        : 'dry';
    return _LastRow(
      kind: Kind.diaper,
      title: 'Last change',
      subtitle: ago(DateTime.now().difference(e.start).inSeconds),
      value: value,
      caption: e['wet'] == true && e['dirty'] == true ? '+ wet' : null,
      onTap: () => showEventForm(context, event: e),
    );
  }

  Widget _simpleCard(
    BuildContext context, {
    required Kind kind,
    required String title,
    required Event? event,
    required String empty,
    required String type,
    required String Function(Event) label,
    required VoidCallback onHistory,
  }) => _ActivityCard(
    kind: kind,
    title: title,
    onAdd: () => showEventForm(context, type: type),
    onHistory: event == null ? null : onHistory,
    child: event == null
        ? _LastRow(kind: kind, title: empty)
        : _LastRow(
            kind: kind,
            title: label(event),
            subtitle: ago(DateTime.now().difference(event.start).inSeconds),
            onTap: () => showEventForm(context, event: event),
          ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.child, required this.live});
  final Child child;
  final bool live;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      GestureDetector(
        onTap: () => _switchChild(context),
        child: ChildAvatar(child: child, size: 66),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: GestureDetector(
          onTap: () => _switchChild(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(child.name, style: serifStyle(34), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      DateFormat('EEE, MMM d').format(DateTime.now()),
                      style: const TextStyle(color: Palette.muted, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: live ? 'Live — changes from other caregivers appear instantly' : 'Reconnecting…',
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: live ? const Color(0xFF7BC68F) : Palette.line, shape: BoxShape.circle),
                    ),
                  ),
                ],
              ),
              if (child.age != null) Text(child.age!, style: const TextStyle(color: Palette.muted, fontSize: 13)),
            ],
          ),
        ),
      ),
      _SquareButton(
        icon: Icons.view_agenda_outlined,
        tooltip: 'Timeline',
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TimelineScreen(initialFilter: null))),
      ),
      const SizedBox(width: 8),
      _SquareButton(icon: Icons.more_horiz_rounded, tooltip: 'Switch baby', onTap: () => _switchChild(context)),
    ],
  );

  void _switchChild(BuildContext context) {
    final s = context.read<AppState>();
    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            for (final f in s.families)
              for (final ch in f.children)
                ListTile(
                  leading: ChildAvatar(child: ch, size: 44),
                  title: Text(ch.name, style: serifStyle(20)),
                  subtitle: Text([?ch.age, if (s.families.length > 1) f.name].join(' · ')),
                  trailing: ch.id == s.childId ? const Icon(Icons.check_rounded, color: Palette.accentLight) : null,
                  onTap: () {
                    Navigator.pop(c);
                    s.selectChild(ch.id);
                  },
                ),
            ListTile(
              leading: const CircleAvatar(
                radius: 22,
                backgroundColor: Palette.surface,
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

class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 46,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Palette.muted.withValues(alpha: 0.6)),
        ),
        child: Icon(icon, size: 20, color: Palette.ink),
      ),
    ),
  );
}

class ChildAvatar extends StatelessWidget {
  const ChildAvatar({super.key, required this.child, this.size = 48});
  final Child child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = switch (child.sex) {
      'female' => Kind.pump.color,
      'male' => Kind.sleep.color,
      _ => Kind.growth.color,
    };
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      decoration: BoxDecoration(color: Palette.ink, shape: BoxShape.circle),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(
          child.name.isEmpty ? '?' : child.name.characters.first.toUpperCase(),
          style: serifStyle(size * 0.46, color: Palette.bandInk),
        ),
      ),
    );
  }
}

class _TodayStrip extends StatelessWidget {
  const _TodayStrip({required this.today, required this.units});
  final Map<String, dynamic> today;
  final Units units;

  @override
  Widget build(BuildContext context) {
    final feed = today['feed'] as Map? ?? {}, sleep = today['sleep'] as Map? ?? {};
    final diaper = today['diaper'] as Map? ?? {};
    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(value, style: serifStyle(24)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Palette.muted, fontSize: 12)),
        ],
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: const Color(0xFF243552), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          stat('${feed['count'] ?? 0}', 'feeds today'),
          stat(duration(toInt(sleep['total_seconds']) ?? 0), 'sleep today'),
          stat('${diaper['count'] ?? 0}', 'diapers today'),
        ],
      ),
    );
  }
}

/// Card with a pastel header band, an overlapping round + and a dark body.
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.kind,
    required this.title,
    required this.onAdd,
    required this.child,
    this.onHistory,
    this.historyLabel = 'View history',
  });
  final Kind kind;
  final String title;
  final VoidCallback onAdd;
  final Widget child;
  final VoidCallback? onHistory;
  final String historyLabel;

  static const _band = 50.0;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: _band,
                color: kind.color,
                padding: const EdgeInsets.only(left: 16),
                alignment: Alignment.centerLeft,
                child: Text(title, style: serifStyle(26, color: Palette.bandInk)),
              ),
              Container(
                color: Palette.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    child,
                    if (onHistory != null)
                      InkWell(
                        onTap: onHistory,
                        child: Container(
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: Palette.line)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Text(historyLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              const Spacer(),
                              const Icon(Icons.chevron_right_rounded, color: Palette.muted),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 14,
          top: _band - 23,
          child: PlusButton(onTap: onAdd, tooltip: 'Add ${title.toLowerCase()}'),
        ),
      ],
    ),
  );
}

/// Blob icon · title/subtitle · big serif value on the right.
class _LastRow extends StatelessWidget {
  const _LastRow({required this.kind, required this.title, this.subtitle, this.value, this.caption, this.onTap});
  final Kind kind;
  final String title;
  final String? subtitle;
  final String? value;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 18),
      child: Row(
        children: [
          BlobIcon(kind, size: 62),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: serifStyle(20), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: const TextStyle(fontSize: 14, color: Palette.ink)),
                ],
              ],
            ),
          ),
          if (value != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value!, style: serifStyle(40, height: 1.1)),
                ),
                if (caption != null) Text(caption!, style: serifStyle(15, color: Palette.muted)),
              ],
            ),
        ],
      ),
    ),
  );
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.last, required this.timer, required this.onHistory});
  final Event? last;
  final TimerModel? timer;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final u = context.select<AppState, Units>((s) => s.units);
    Widget body;
    final t = timer, e = last;
    if (t != null) {
      body = Ticking(
        builder: (_) => _LastRow(
          kind: Kind.breast,
          title: t.running ? 'Nursing now' : 'Nursing paused',
          subtitle: '${t.side == 'right' ? 'Right' : 'Left'} side · since ${timeOfDay(t.startedAt)}',
          value: clock(t.elapsed),
          caption: t.running ? 'running' : 'paused',
          onTap: () => TimerScreen.open(context, 'breastfeed'),
        ),
      );
    } else if (e == null) {
      body = const _LastRow(kind: Kind.breast, title: 'Track a feeding');
    } else {
      final method = e['method'] as String?;
      final end = e.endSide;
      final (value, caption) = switch (method) {
        'bottle' => (u.volume(toDouble(e['amount_ml'])), 'bottle'),
        'solids' => ('solids', null),
        _ when end != null => (end == 'left' ? 'right' : 'left', 'next side'),
        _ => (null, null),
      };
      body = _LastRow(
        kind: Kind.of('feed', method),
        title: 'Last feeding',
        subtitle: ago(DateTime.now().difference(e.start).inSeconds),
        value: value,
        caption: caption,
        onTap: () => showEventForm(context, event: e),
      );
    }
    return _ActivityCard(
      kind: Kind.breast,
      title: 'Feed',
      onAdd: () => showFeedPicker(context),
      onHistory: e == null ? null : onHistory,
      child: body,
    );
  }
}

/// Pump and sleep: a running timer shows live; otherwise the last entry.
class _TimedCard extends StatelessWidget {
  const _TimedCard({
    required this.kind,
    required this.title,
    required this.timerKind,
    required this.timer,
    required this.last,
    required this.lastTitle,
    required this.empty,
    required this.value,
    required this.caption,
    required this.onHistory,
    this.since,
  });
  final Kind kind;
  final String title, timerKind, lastTitle, empty;
  final TimerModel? timer;
  final Event? last;
  final String Function(Event) value;
  final String? Function(Event) caption;
  final DateTime Function(Event)? since;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final t = timer, e = last;
    final Widget body;
    if (t != null) {
      body = Ticking(
        builder: (_) => _LastRow(
          kind: kind,
          title: timerKind == 'sleep' ? (t.running ? 'Sleeping now' : 'Sleep paused') : (t.running ? 'Pumping now' : 'Pumping paused'),
          subtitle: 'since ${timeOfDay(t.startedAt)}',
          value: clock(t.elapsed),
          caption: t.running ? 'running' : 'paused',
          onTap: () => TimerScreen.open(context, timerKind),
        ),
      );
    } else if (e == null) {
      body = _LastRow(kind: kind, title: empty, onTap: () => TimerScreen.open(context, timerKind));
    } else {
      final v = value(e);
      body = _LastRow(
        kind: kind,
        title: lastTitle,
        subtitle: ago(DateTime.now().difference(since?.call(e) ?? e.start).inSeconds),
        value: v.isEmpty ? null : v,
        caption: caption(e),
        onTap: () => showEventForm(context, event: e),
      );
    }
    return _ActivityCard(
      kind: kind,
      title: title,
      onAdd: () => TimerScreen.open(context, timerKind),
      onHistory: e == null ? null : onHistory,
      child: body,
    );
  }
}

class _GrowthCard extends StatelessWidget {
  const _GrowthCard({required this.events, required this.units, required this.onHistory});
  final List<Event> events;
  final Units units;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    Event? latestWith(String field) => events.where((e) => e[field] != null).firstOrNull;
    final rows = [
      ('Weight', Icons.monitor_weight_outlined, latestWith('weight_g'), (Event e) => units.weight(toDouble(e['weight_g']))),
      ('Height', Icons.height_rounded, latestWith('length_cm'), (Event e) => units.length(toDouble(e['length_cm']))),
      ('Head size', Icons.face_outlined, latestWith('head_cm'), (Event e) => units.length(toDouble(e['head_cm']))),
    ];
    return _ActivityCard(
      kind: Kind.growth,
      title: 'Growth',
      onAdd: () => showEventForm(context, type: 'growth'),
      onHistory: events.isEmpty ? null : onHistory,
      historyLabel: 'Show all',
      child: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(
          children: [
            for (final (i, (label, icon, e, fmt)) in rows.indexed) ...[
              if (i > 0) const Divider(indent: 16, endIndent: 16),
              _ListRow(
                kind: Kind.growth,
                icon: icon,
                title: label,
                subtitle: e == null ? 'Not measured yet' : DateFormat.yMMMd().format(e.start),
                trailing: e == null ? null : fmt(e),
                onTap: e == null ? () => showEventForm(context, type: 'growth') : () => showEventForm(context, event: e),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.events, required this.units, required this.onHistory});
  final List<Event> events;
  final Units units;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) => _ActivityCard(
    kind: Kind.health,
    title: 'Health',
    onAdd: () => showEventForm(context, type: 'health'),
    onHistory: events.isEmpty ? null : onHistory,
    historyLabel: 'Show all',
    child: events.isEmpty
        ? const _LastRow(kind: Kind.health, title: 'Medicine, temperature, vaccines…')
        : Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Column(
              children: [
                for (final (i, e) in events.indexed) ...[
                  if (i > 0) const Divider(indent: 16, endIndent: 16),
                  () {
                    final (title, detail) = describe(e, units);
                    return _ListRow(
                      kind: Kind.health,
                      icon: switch (e['kind']) {
                        'temperature' => Icons.thermostat_rounded,
                        'vaccine' => Icons.vaccines_outlined,
                        'appointment' => Icons.event_outlined,
                        _ => Icons.medication_outlined,
                      },
                      title: title,
                      subtitle: [if (detail.isNotEmpty) detail, DateFormat.MMMd().format(e.start)].join('\n'),
                      onTap: () => showEventForm(context, event: e),
                    );
                  }(),
                ],
              ],
            ),
          ),
  );
}

class _ListRow extends StatelessWidget {
  const _ListRow({required this.kind, required this.icon, required this.title, required this.subtitle, this.trailing, this.onTap});
  final Kind kind;
  final IconData icon;
  final String title, subtitle;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          BlobIcon(kind, size: 46, icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: serifStyle(19)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 13, color: Palette.ink)),
              ],
            ),
          ),
          if (trailing != null) Text(trailing!, style: const TextStyle(fontSize: 16)),
          const Icon(Icons.chevron_right_rounded, color: Palette.muted),
        ],
      ),
    ),
  );
}

/// Bottom sheet listing the kinds of feed (the Feed card's +).
void showFeedPicker(BuildContext context) {
  final options = <(Kind, String, VoidCallback)>[
    (Kind.breast, 'Breastfeed', () => TimerScreen.open(context, 'breastfeed')),
    (Kind.bottle, 'Bottle feed', () => showEventForm(context, type: 'feed', method: 'bottle')),
    (Kind.solids, 'Solids', () => showEventForm(context, type: 'feed', method: 'solids')),
    (Kind.combo, 'Combo feed', () => showEventForm(context, type: 'feed', method: 'combo')),
  ];
  showModalBottomSheet(
    context: context,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (kind, label, onTap) in options)
              InkWell(
                onTap: () {
                  Navigator.pop(c);
                  onTap();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      BlobIcon(kind, size: 64),
                      const SizedBox(width: 28),
                      Text(label, style: serifStyle(28)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
