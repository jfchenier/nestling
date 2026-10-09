import 'dart:typed_data';

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
import 'growth_chart.dart';
import 'timeline.dart';
import 'timer_screen.dart';

/// Dashboard: running timers, today's totals and a grid of activity cards (two per row on a
/// phone), each with the latest entry and a small + to log another.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    void history(String filter) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TimelineScreen(initialFilter: filter)));
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: s.refreshChild,
          child: Constrained(
            maxWidth: 900,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
        return _CardData.live(nursing, nursing.running ? 'breastfeed · ${nursing.side == 'right' ? 'right' : 'left'}' : 'paused');
      }
      if (feed == null) return const _CardData();
      final end = feed.endSide;
      return switch (feed['method'] as String?) {
        'bottle' => _CardData(top: since(feed.start), value: u.volume(toDouble(feed['amount_ml'])).ifEmpty('Bottle'), caption: 'bottle'),
        'solids' => _CardData(top: since(feed.start), value: 'Solids', caption: (feed['foods'] as String?) ?? ''),
        _ => _CardData(
          top: since(feed.start),
          // The side the last feed ended on.
          value: end == null ? 'Breastfeed' : (end == 'left' ? 'Left' : 'Right'),
          caption: end == null ? '' : 'last side',
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
    // Tapping a card logs one (or opens its running timer); the clock icon opens its history.
    _ActivityCard card(Kind kind, String title, _CardData data, VoidCallback log, String filter, [TimerModel? running]) => _ActivityCard(
      kind: kind,
      title: title,
      data: data,
      onLog: running != null ? () => open(running.kind) : log,
      onHistory: filter == 'growth'
          ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GrowthChartScreen()))
          : () => history(filter),
      // Growth's header icon opens the growth charts (its history is listed there too).
      historyIcon: filter == 'growth' ? Icons.show_chart_rounded : Icons.history_rounded,
      historyLabel: filter == 'growth' ? 'Growth charts' : '$title history',
    );
    return [
      card(Kind.breast, 'Feed', feedCard, () => showFeedPicker(context), 'feed', nursing),
      card(Kind.sleep, 'Sleep', sleepCard, () => open('sleep'), 'sleep', sleeping),
      card(Kind.diaper, 'Diaper', diaperCard, () => showEventForm(context, type: 'diaper'), 'diaper'),
      card(Kind.pump, 'Pump', pumpCard, () => open('pump'), 'pump', pumping),
      card(Kind.growth, 'Growth', growthCard, () => showEventForm(context, type: 'growth'), 'growth'),
      card(Kind.health, 'Health', healthCard, () => showEventForm(context, type: 'health'), 'health'),
      card(
        Kind.activity,
        'Routine',
        simple(latest('activity'), (e) => cap(e['kind'] as String? ?? 'Activity')),
        () => showEventForm(context, type: 'activity'),
        'activity,milestone,note',
      ),
      card(
        Kind.milestone,
        'Firsts',
        simple(latest('milestone'), (e) => (e['name'] as String?) ?? 'Milestone'),
        () => showEventForm(context, type: 'milestone'),
        'activity,milestone,note',
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
  const _ActivityCard({
    required this.kind,
    required this.title,
    required this.data,
    required this.onLog,
    required this.onHistory,
    this.historyIcon = Icons.history_rounded,
    required this.historyLabel,
  });
  final Kind kind;
  final String title;
  final _CardData data;

  /// Tap anywhere on the card: log one (or open the running timer).
  final VoidCallback onLog;
  final VoidCallback onHistory;
  final IconData historyIcon;
  final String historyLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final t = data.timer;
    return Semantics(
      button: true,
      label: 'Log $title',
      child: Container(
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
            onTap: onLog,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: kind.fill(c),
                  padding: const EdgeInsets.fromLTRB(14, 2, 2, 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: c.bandInk),
                        ),
                      ),
                      IconButton(
                        onPressed: onHistory,
                        tooltip: historyLabel,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(historyIcon, color: c.bandInk, size: 22),
                      ),
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
                              data.value == null && t == null ? 'Tap to log' : (data.top ?? ''),
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
      _ => 'Breastfeed',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: k.fill(c),
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
                    decoration: BoxDecoration(
                      color: c.isDark ? Colors.black26 : Colors.white.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(k.icon, color: k.iconOn(c)),
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

/// The child's profile picture in a ring, or their initial on a pastel circle.
class ChildAvatar extends StatelessWidget {
  const ChildAvatar({super.key, required this.child, this.size = 48, this.photo, this.showPhoto = true});
  final Child child;
  final double size;

  /// Shown instead of the saved picture (e.g. a new one not uploaded yet).
  final Uint8List? photo;

  /// False shows the initial even if there is a saved picture (e.g. "Remove" before Save).
  final bool showPhoto;

  @override
  Widget build(BuildContext context) {
    final saved = context.watch<AppState>().photoFor(child);
    final picture = showPhoto ? photo ?? saved : null;
    final color = switch (child.sex) {
      'female' => Kind.pump.fill(context.pal),
      'male' => Kind.sleep.fill(context.pal),
      _ => Kind.growth.fill(context.pal),
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
      child: picture != null
          ? ClipOval(
              child: Image.memory(picture, fit: BoxFit.cover, gaplessPlayback: true, semanticLabel: child.name),
            )
          : Container(
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
    Widget stat(String value, String label, Widget extra) => Expanded(
      child: Column(
        children: [
          Text(value, style: serifStyle(24)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: context.pal.muted, fontSize: 12)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: extra),
        ],
      ),
    );
    // A detail line under each total, in the activity's color.
    Widget detail(String text, Kind kind) => Padding(
      padding: const EdgeInsets.only(top: 3),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kind.on(context.pal)),
        ),
      ),
    );
    int n(Map m, String k) => toInt(m[k]) ?? 0;
    final solids = n(feed, 'solids_count');
    final feedDetail = [
      '${n(feed, 'breast_count')} breast',
      units.volume(toDouble(feed['bottle_ml']) ?? 0),
      if (solids > 0) '$solids solids',
    ].join(' · ');
    // Night sleep (18–06, as in Trends) and daytime naps; whichever there is.
    final night = n(sleep, 'night_seconds'), naps = n(sleep, 'nap_count');
    final sleepParts = [if (night > 0) '${duration(night)} night', if (naps > 0) naps == 1 ? '1 nap' : '$naps naps'];
    final sleepDetail = sleepParts.isEmpty ? '0 naps' : sleepParts.join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: context.pal.accentSoft, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          stat('${feed['count'] ?? 0}', 'feeds today', detail(feedDetail, Kind.breast)),
          stat(duration(toInt(sleep['total_seconds']) ?? 0), 'sleep today', detail(sleepDetail, Kind.sleep)),
          // A diaper can be both wet and dirty.
          stat('${diaper['count'] ?? 0}', 'diapers today', detail('${n(diaper, 'wet')} wet · ${n(diaper, 'dirty')} dirty', Kind.diaper)),
        ],
      ),
    );
  }
}

/// Feed card: pick the kind of feed.
void showFeedPicker(BuildContext context) {
  final options = <(Kind, String, VoidCallback)>[
    (Kind.breast, 'Breastfeed', () => TimerScreen.open(context, 'breastfeed')),
    (Kind.bottle, 'Bottle', () => showEventForm(context, type: 'feed', method: 'bottle')),
    (Kind.solids, 'Solids', () => showEventForm(context, type: 'feed', method: 'solids')),
    (Kind.combo, 'Combo', () => showEventForm(context, type: 'feed', method: 'combo')),
  ];
  showModalBottomSheet(
    context: context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 16),
              child: Text('Log a feed', style: serifStyle(22)),
            ),
            Row(
              children: [
                for (final (k, label, onTap) in options)
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.pop(sheet);
                        onTap();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            BlobIcon(k, size: 62),
                            const SizedBox(height: 8),
                            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
