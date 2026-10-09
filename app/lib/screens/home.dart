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

/// Dashboard: running timers, today's totals and a grid of activity cards (two per row on a
/// phone), each with the latest entry and a small + to log another.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.pal;
    void history(String filter) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TimelineScreen(initialFilter: filter)));
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => showLogMenu(context),
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        tooltip: 'Log something',
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: s.refreshChild,
          child: Constrained(
            maxWidth: 900,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _Header(child: s.child!, live: s.live),
                const SizedBox(height: 16),
                for (final t in s.timers) _TimerBanner(timer: t),
                if (s.summary?['today'] is Map) _TodayStrip(today: s.summary!['today'], units: s.units),
                _CardGrid(cards: _cards(context, s, history)),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () => showEventForm(context, type: 'note'),
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Add a note'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _cards(BuildContext context, AppState s, void Function(String) history) {
    final u = s.units;
    final now = DateTime.now();
    Event? last(String type) {
      final v = s.summary?['last']?[type];
      return v is Map<String, dynamic> ? Event(v) : null;
    }

    TimerModel? timer(String kind) => s.timers.where((t) => t.kind == kind).firstOrNull;
    Event? latest(String type) => s.others.where((e) => e.type == type).firstOrNull;
    String since(DateTime t) => ago(now.difference(t).inSeconds);

    // Feed
    final feed = last('feed'), nursing = timer('breastfeed');
    final feedCard = () {
      if (nursing != null) {
        return _CardData.live(nursing, nursing.running ? 'nursing · ${nursing.side == 'right' ? 'right' : 'left'}' : 'paused');
      }
      if (feed == null) return const _CardData();
      final end = feed.endSide;
      return switch (feed['method'] as String?) {
        'bottle' => _CardData(top: since(feed.start), value: u.volume(toDouble(feed['amount_ml'])).ifEmpty('Bottle'), caption: 'bottle'),
        'solids' => _CardData(top: since(feed.start), value: 'Solids', caption: (feed['foods'] as String?) ?? ''),
        _ => _CardData(
          top: since(feed.start),
          value: end == null ? 'Nursing' : (end == 'left' ? 'Right' : 'Left'),
          caption: end == null ? '' : 'next side',
        ),
      };
    }();

    // Sleep
    final sleep = last('sleep'), sleeping = timer('sleep');
    final sleepCard = sleeping != null
        ? _CardData.live(sleeping, sleeping.running ? 'asleep' : 'paused')
        : sleep == null
        ? const _CardData()
        : _CardData(
            top: 'woke ${since(sleep.end ?? sleep.start)}',
            value: duration(now.difference(sleep.end ?? sleep.start).inSeconds),
            caption: 'awake · last ${duration(sleep.durationSeconds)}',
          );

    // Diaper
    final diaper = last('diaper');
    final diaperCard = diaper == null
        ? const _CardData()
        : _CardData(
            top: since(diaper.start),
            value: diaper['dirty'] == true ? (diaper['wet'] == true ? 'Wet + dirty' : 'Dirty') : (diaper['wet'] == true ? 'Wet' : 'Dry'),
            caption: [cap(diaper['color'] as String?), cap(diaper['consistency'] as String?)].where((x) => x.isNotEmpty).join(' · '),
          );

    // Pump
    final pump = last('pump'), pumping = timer('pump');
    final pumpTotal = (toDouble(pump?['left_ml']) ?? 0) + (toDouble(pump?['right_ml']) ?? 0);
    final pumpCard = pumping != null
        ? _CardData.live(pumping, pumping.running ? 'pumping' : 'paused')
        : pump == null
        ? const _CardData()
        : _CardData(top: since(pump.start), value: pumpTotal > 0 ? u.volume(pumpTotal) : duration(pump.durationSeconds), caption: 'pumped');

    // Growth: latest value of each measure
    final growth = s.others.where((e) => e.type == 'growth').toList();
    Event? withField(String f) => growth.where((e) => e[f] != null).firstOrNull;
    final w = withField('weight_g'), l = withField('length_cm'), h = withField('head_cm');
    final growthCard = growth.isEmpty
        ? const _CardData()
        : _CardData(
            top: DateFormat.MMMd().format(growth.first.start),
            value: w != null
                ? u.weight(toDouble(w['weight_g']))
                : (l != null ? u.length(toDouble(l['length_cm'])) : u.length(toDouble(h?['head_cm']))),
            caption: [
              if (w != null && l != null) u.length(toDouble(l['length_cm'])),
              if (h != null && (w != null || l != null)) 'head ${u.length(toDouble(h['head_cm']))}',
            ].join(' · '),
          );

    _CardData simple(Event? e, String Function(Event) value) =>
        e == null ? const _CardData() : _CardData(top: since(e.start), value: value(e), caption: '');
    final health = latest('health');
    final healthCard = health == null
        ? const _CardData()
        : () {
            final (title, detail) = describe(health, u);
            return _CardData(
              top: since(health.start),
              value: detail.isEmpty ? title : detail.split(' · ').first,
              caption: detail.isEmpty ? '' : title,
            );
          }();

    void open(String timerKind) => TimerScreen.open(context, timerKind);
    return [
      _ActivityCard(
        kind: Kind.breast,
        title: 'Feed',
        data: feedCard,
        onAdd: () => showFeedPicker(context),
        onTap: nursing != null ? () => open('breastfeed') : () => history('feed'),
      ),
      _ActivityCard(
        kind: Kind.sleep,
        title: 'Sleep',
        data: sleepCard,
        onAdd: () => open('sleep'),
        onTap: sleeping != null ? () => open('sleep') : () => history('sleep'),
      ),
      _ActivityCard(
        kind: Kind.diaper,
        title: 'Diaper',
        data: diaperCard,
        onAdd: () => showEventForm(context, type: 'diaper'),
        onTap: () => history('diaper'),
      ),
      _ActivityCard(
        kind: Kind.pump,
        title: 'Pump',
        data: pumpCard,
        onAdd: () => open('pump'),
        onTap: pumping != null ? () => open('pump') : () => history('pump'),
      ),
      _ActivityCard(
        kind: Kind.growth,
        title: 'Growth',
        data: growthCard,
        onAdd: () => showEventForm(context, type: 'growth'),
        onTap: () => history('growth'),
      ),
      _ActivityCard(
        kind: Kind.health,
        title: 'Health',
        data: healthCard,
        onAdd: () => showEventForm(context, type: 'health'),
        onTap: () => history('health'),
      ),
      _ActivityCard(
        kind: Kind.activity,
        title: 'Routine',
        data: simple(latest('activity'), (e) => cap(e['kind'] as String? ?? 'Activity')),
        onAdd: () => showEventForm(context, type: 'activity'),
        onTap: () => history('activity,milestone,note'),
      ),
      _ActivityCard(
        kind: Kind.milestone,
        title: 'Firsts',
        data: simple(latest('milestone'), (e) => (e['name'] as String?) ?? 'Milestone'),
        onAdd: () => showEventForm(context, type: 'milestone'),
        onTap: () => history('activity,milestone,note'),
      ),
    ];
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

/// What a card shows: a small line on top, one big value and a caption. A running timer shows
/// its live clock instead.
class _CardData {
  const _CardData({this.top, this.value, this.caption = ''}) : timer = null;
  const _CardData.live(TimerModel this.timer, this.caption) : top = 'now', value = null;
  final String? top;
  final String? value;
  final String caption;
  final TimerModel? timer;
}

/// Lays cards out two per row on a phone (three or four on wider screens), equal heights per row.
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.cards});
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final cols = box.maxWidth >= 760 ? 4 : (box.maxWidth >= 560 ? 3 : 2);
      const gap = 12.0;
      return Column(
        children: [
          for (var i = 0; i < cards.length; i += cols)
            Padding(
              padding: const EdgeInsets.only(bottom: gap),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = i; j < i + cols; j++) ...[
                      if (j > i) const SizedBox(width: gap),
                      Expanded(child: j < cards.length ? cards[j] : const SizedBox()),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// White rounded card with a pastel header strip (name + small +) and the latest entry.
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.kind, required this.title, required this.data, required this.onAdd, required this.onTap});
  final Kind kind;
  final String title;
  final _CardData data;
  final VoidCallback onAdd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final t = data.timer;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: c.isDark ? null : Border.all(color: c.line),
        boxShadow: c.isDark
            ? null
            : [BoxShadow(color: const Color(0xFF6B5A44).withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: kind.color,
                padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: c.bandInk),
                      ),
                    ),
                    PlusButton(onTap: onAdd, size: 30, tooltip: 'Add ${title.toLowerCase()}'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        BlobIcon(kind, size: 34),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data.value == null && t == null ? 'Nothing yet' : (data.top ?? ''),
                            style: TextStyle(
                              fontSize: 13,
                              color: t != null ? kind.on(c) : c.muted,
                              fontWeight: t != null ? FontWeight.w700 : FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (t != null)
                      Ticking(
                        builder: (_) => Text(
                          clock(t.elapsed),
                          style: serifStyle(28, color: kind.on(c)).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                      )
                    else
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(data.value ?? '—', style: serifStyle(26, color: data.value == null ? c.muted : c.ink)),
                      ),
                    if (data.caption.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          data.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: c.muted),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width pastel banner for a running timer.
class _TimerBanner extends StatelessWidget {
  const _TimerBanner({required this.timer});
  final TimerModel timer;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: k.color,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => TimerScreen.open(context, timer.kind),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
            child: Ticking(
              builder: (_) => Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), shape: BoxShape.circle),
                    child: Icon(k.icon, color: c.bandInk),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          timer.running ? label : '$label · paused',
                          style: TextStyle(fontWeight: FontWeight.w700, color: c.bandInk),
                        ),
                        Text(
                          [
                            if (timer.kind == 'breastfeed' && timer.side != null) '${timer.side == 'left' ? 'Left' : 'Right'} side',
                            'since ${timeOfDay(timer.startedAt)}',
                          ].join(' · '),
                          style: TextStyle(color: c.bandInk.withValues(alpha: 0.75), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    clock(timer.elapsed),
                    style: serifStyle(26, color: c.bandInk).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
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
                      style: TextStyle(color: context.pal.muted, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: live ? 'Live — changes from other caregivers appear instantly' : 'Reconnecting…',
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: live ? Color(0xFF7BC68F) : context.pal.line, shape: BoxShape.circle),
                    ),
                  ),
                ],
              ),
              if (child.age != null) Text(child.age!, style: TextStyle(color: context.pal.muted, fontSize: 13)),
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
                  trailing: ch.id == s.childId ? Icon(Icons.check_rounded, color: context.pal.accent) : null,
                  onTap: () {
                    Navigator.pop(c);
                    s.selectChild(ch.id);
                  },
                ),
            ListTile(
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: context.pal.surface,
                child: Icon(Icons.add, color: context.pal.ink),
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
          border: Border.all(color: context.pal.muted.withValues(alpha: 0.6)),
        ),
        child: Icon(icon, size: 20, color: context.pal.ink),
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
      decoration: BoxDecoration(
        color: context.pal.surface,
        shape: BoxShape.circle,
        border: Border.all(color: context.pal.line),
      ),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(
          child.name.isEmpty ? '?' : child.name.characters.first.toUpperCase(),
          style: serifStyle(size * 0.46, color: context.pal.bandInk),
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
          Text(label, style: TextStyle(color: context.pal.muted, fontSize: 12)),
        ],
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: context.pal.accentSoft, borderRadius: BorderRadius.circular(14)),
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

/// Floating + : everything that can be logged.
void showLogMenu(BuildContext context) {
  final items = <(Kind, String, VoidCallback)>[
    (Kind.breast, 'Nursing', () => TimerScreen.open(context, 'breastfeed')),
    (Kind.bottle, 'Bottle', () => showEventForm(context, type: 'feed', method: 'bottle')),
    (Kind.solids, 'Solids', () => showEventForm(context, type: 'feed', method: 'solids')),
    (Kind.combo, 'Combo', () => showEventForm(context, type: 'feed', method: 'combo')),
    (Kind.sleep, 'Sleep', () => TimerScreen.open(context, 'sleep')),
    (Kind.diaper, 'Diaper', () => showEventForm(context, type: 'diaper')),
    (Kind.pump, 'Pump', () => TimerScreen.open(context, 'pump')),
    (Kind.growth, 'Growth', () => showEventForm(context, type: 'growth')),
    (Kind.health, 'Health', () => showEventForm(context, type: 'health')),
    (Kind.activity, 'Routine', () => showEventForm(context, type: 'activity')),
    (Kind.milestone, 'First', () => showEventForm(context, type: 'milestone')),
    (Kind.note, 'Note', () => showEventForm(context, type: 'note')),
  ];
  showModalBottomSheet(
    context: context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: Text('Log', style: serifStyle(22)),
            ),
            LayoutBuilder(
              builder: (context, box) => Wrap(
                runSpacing: 12,
                children: [
                  for (final (k, label, onTap) in items)
                    SizedBox(
                      width: box.maxWidth / 4,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.pop(sheet);
                          onTap();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(color: k.color, shape: BoxShape.circle),
                                child: Icon(k.icon, color: context.pal.bandInk, size: 26),
                              ),
                              const SizedBox(height: 6),
                              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
