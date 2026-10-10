import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../l10n/l10n.dart';
import '../local/schedule.dart' show medicineKey;
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'baby_book.dart';
import 'child_form.dart';
import 'event_form.dart';
import 'family.dart';
import 'schedules.dart';
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
                _Header(child: s.child!, sync: _syncStatus(s)),
                const SizedBox(height: 16),
                for (final t in s.timers) _TimerBanner(timer: t),
                // Rolling last 24 hours (older servers: the calendar day).
                if ((s.summary?['last_24h'] ?? s.summary?['today']) case final Map<String, dynamic> stats)
                  _TodayStrip(today: stats, units: s.units, rolling: s.summary?['last_24h'] != null),
                const _ReminderStrip(),
                _CardGrid(cards: _cards(context, s, history)),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () => showEventForm(context, type: 'note'),
                    icon: const Icon(Icons.edit_note_rounded),
                    label: Text(l10n.homeAddNote),
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
        return _CardData.live(nursing, nursing.running ? l10n.homeLiveBreastfeed(nursing.side == 'right' ? 'right' : 'left') : l10n.homePaused);
      }
      if (feed == null) return const _CardData();
      final end = feed.endSide;
      return switch (feed['method'] as String?) {
        'bottle' => _CardData(top: since(feed.start), value: u.volume(toDouble(feed['amount_ml'])).ifEmpty(l10n.kindBottle), caption: l10n.homeCaptionBottle),
        'solids' => _CardData(top: since(feed.start), value: l10n.kindSolids, caption: (feed['foods'] as String?) ?? ''),
        _ => _CardData(
          top: since(feed.start),
          // The side the last feed ended on.
          value: end == null ? l10n.kindBreastfeed : (end == 'left' ? l10n.left : l10n.right),
          caption: end == null ? '' : l10n.homeLastSide,
        ),
      };
    }();

    // Sleep
    final sleep = last('sleep'), sleeping = timer('sleep');
    final sleepCard = sleeping != null
        ? _CardData.live(sleeping, sleeping.running ? l10n.homeAsleep : l10n.homePaused)
        : sleep == null
        ? const _CardData()
        : _CardData(
            top: l10n.homeWoke(since(sleep.end ?? sleep.start)),
            value: duration(now.difference(sleep.end ?? sleep.start).inSeconds),
            caption: l10n.homeAwakeLast(duration(sleep.durationSeconds)),
          );

    // Diaper
    final diaper = last('diaper');
    final diaperCard = diaper == null
        ? const _CardData()
        : diaper['potty'] != null
        ? _CardData(top: since(diaper.start), value: pottyLabel(diaper['potty'])!, caption: diaper['potty'] == 'sat_dry' ? l10n.homeCaptionPotty : wetDirty(diaper).toLowerCase())
        : _CardData(
            top: since(diaper.start),
            value: diaper['dirty'] == true
                ? (diaper['wet'] == true ? l10n.wetAndDirty : l10n.dirty)
                : (diaper['wet'] == true ? l10n.wet : l10n.dry),
            caption: [cap(diaper['color'] as String?), cap(diaper['consistency'] as String?)].where((x) => x.isNotEmpty).join(' · '),
          );

    // Pump
    final pump = last('pump'), pumping = timer('pump');
    final pumpTotal = (toDouble(pump?['left_ml']) ?? 0) + (toDouble(pump?['right_ml']) ?? 0);
    final pumpCard = pumping != null
        ? _CardData.live(pumping, pumping.running ? l10n.homePumping.toLowerCase() : l10n.homePaused)
        : pump == null
        ? const _CardData()
        : _CardData(top: since(pump.start), value: pumpTotal > 0 ? u.volume(pumpTotal) : duration(pump.durationSeconds), caption: l10n.homePumped);

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
              if (h != null && (w != null || l != null)) l10n.homeHead(u.length(toDouble(h['head_cm']))),
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
    void openBook({bool addMemory = false}) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => BabyBookScreen(addMemory: addMemory)));
    // Tapping a card logs one (or opens its running timer); the clock icon opens its history.
    _ActivityCard card(Kind kind, String title, _CardData data, VoidCallback log, String filter, [TimerModel? running]) => _ActivityCard(
      kind: kind,
      title: title,
      data: data,
      onLog: running != null ? () => open(running.kind) : log,
      onHistory: switch (filter) {
        'growth' => () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GrowthChartScreen())),
        'milestone' => () => openBook(),
        _ => () => history(filter),
      },
      // Growth's header button opens the growth charts (its history is listed there too), Firsts'
      // the baby book.
      historyIcon: switch (filter) {
        'growth' => Icons.show_chart_rounded,
        'milestone' => Icons.auto_stories_rounded,
        _ => Icons.history_rounded,
      },
      historyLabel: switch (filter) {
        'growth' => l10n.homeGrowthCharts,
        'milestone' => l10n.homeBabyBook,
        _ => l10n.homeCardHistory(title),
      },
      historyShort: switch (filter) {
        'growth' => l10n.homeChartsShort,
        'milestone' => l10n.homeNavBook,
        _ => l10n.homeHistoryShort,
      },
    );
    return [
      card(Kind.breast, l10n.homeCardFeed, feedCard, () => showFeedPicker(context), 'feed', nursing),
      card(Kind.sleep, l10n.kindSleep, sleepCard, () => open('sleep'), 'sleep', sleeping),
      card(Kind.diaper, l10n.kindDiaper, diaperCard, () => showEventForm(context, type: 'diaper'), 'diaper'),
      card(Kind.pump, l10n.kindPump, pumpCard, () => open('pump'), 'pump', pumping),
      card(Kind.growth, l10n.kindGrowth, growthCard, () => showEventForm(context, type: 'growth'), 'growth'),
      card(Kind.health, l10n.kindHealth, healthCard, () => showEventForm(context, type: 'health'), 'health'),
      card(
        Kind.activity,
        l10n.homeCardRoutine,
        simple(latest('activity'), (e) => e['kind'] is String ? cap(e['kind'] as String) : l10n.kindActivity),
        () => showEventForm(context, type: 'activity'),
        'activity,milestone,note',
      ),
      card(
        Kind.milestone,
        l10n.homeCardFirsts,
        simple(latest('milestone'), (e) => (e['name'] as String?) ?? l10n.kindMilestone),
        // "New memory" over the baby book, which shows once it's saved or closed.
        () => openBook(addMemory: true),
        'milestone',
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
    required this.historyShort,
  });
  final Kind kind;
  final String title;
  final _CardData data;

  /// Tap anywhere on the card: log one (or open the running timer).
  final VoidCallback onLog;
  final VoidCallback onHistory;
  final IconData historyIcon;
  final String historyLabel;

  /// Word on the header button ("History", "Charts", "Book"), so it reads as a button.
  final String historyShort;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final t = data.timer;
    return Semantics(
      button: true,
      label: l10n.homeLogCard(title),
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
                  padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                  child: Row(
                    children: [
                      // One line: a longer word (French, Spanish) shrinks a little instead of breaking.
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            title,
                            maxLines: 1,
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: c.bandInk),
                          ),
                        ),
                      ),
                      // A pill with a word, so it's clearly a button of its own (the rest of the
                      // card logs).
                      Tooltip(
                        message: historyLabel,
                        child: Semantics(
                          button: true,
                          label: historyLabel,
                          excludeSemantics: true,
                          child: Material(
                            color: c.surface.withValues(alpha: c.isDark ? 0.3 : 0.65),
                            shape: StadiumBorder(side: BorderSide(color: c.bandInk.withValues(alpha: 0.18))),
                            child: InkWell(
                              customBorder: const StadiumBorder(),
                              onTap: onHistory,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(historyIcon, color: c.bandInk, size: 17),
                                    const SizedBox(width: 4),
                                    Text(historyShort, style: TextStyle(color: c.bandInk, fontSize: 12.5, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
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
                              data.value == null && t == null ? l10n.homeTapToLog : (data.top ?? ''),
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
      'sleep' => l10n.homeSleeping,
      'pump' => l10n.homePumping,
      _ => l10n.kindBreastfeed,
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
                          timer.running ? label : l10n.homeLabelPaused(label),
                          style: TextStyle(fontWeight: FontWeight.w700, color: c.bandInk),
                        ),
                        Text(
                          [
                            if (timer.kind == 'breastfeed' && timer.side != null) l10n.homeSide(timer.side == 'left' ? 'left' : 'right'),
                            l10n.homeSince(timeOfDay(timer.startedAt)),
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

/// How the header shows the connection: a dot (server: live or reconnecting), or an icon and a
/// word (offline, syncing, serverless).
typedef _Sync = ({bool live, IconData? icon, String? label, String tooltip});

_Sync _syncStatus(AppState s) {
  if (s.serverless) {
    final p = s.peers, last = p?.lastSync;
    final n = p?.peers.length ?? 0;
    return (
      live: false,
      icon: Icons.smartphone_rounded,
      label: n == 0
          ? l10n.homeSyncLocal
          : last == null
          ? l10n.homeNotSyncedYet
          : l10n.homeSynced(ago(DateTime.now().difference(last).inSeconds)),
      tooltip: n == 0 ? l10n.homeServerlessAlone : l10n.homeServerlessPeers(n),
    );
  }
  final pending = s.pendingChanges;
  if (s.offline) {
    return (
      live: false,
      icon: Icons.cloud_off_rounded,
      label: pending > 0 ? l10n.homeOfflinePending(pending) : l10n.homeOffline,
      tooltip: l10n.homeOfflineTooltip(pending),
    );
  }
  if (pending > 0) return (live: false, icon: Icons.cloud_sync_rounded, label: l10n.homeSyncing, tooltip: l10n.homeSyncingTooltip);
  return (
    live: s.live,
    icon: null,
    label: null,
    tooltip: s.live ? l10n.homeLiveTooltip : l10n.homeReconnecting,
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.child, required this.sync});
  final Child child;
  final _Sync sync;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      GestureDetector(
        onTap: () => showChildSwitcher(context),
        child: ChildAvatar(child: child, size: 66),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: GestureDetector(
          onTap: () => showChildSwitcher(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tapping the name (or the photo) switches baby or adds one.
              Row(
                children: [
                  Flexible(child: Text(child.name, style: serifStyle(34), overflow: TextOverflow.ellipsis)),
                  Icon(Icons.expand_more_rounded, color: context.pal.muted, semanticLabel: l10n.homeSwitchBaby),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      capFirst(DateFormat.MMMEd().format(DateTime.now())),
                      style: TextStyle(color: context.pal.muted, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: sync.tooltip,
                    child: sync.label == null
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: sync.live ? Color(0xFF7BC68F) : context.pal.line, shape: BoxShape.circle),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(sync.icon, size: 14, color: context.pal.muted),
                              const SizedBox(width: 4),
                              Text(sync.label!, style: TextStyle(color: context.pal.muted, fontSize: 12)),
                            ],
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
        icon: Icons.notifications_rounded,
        tooltip: l10n.familyMedicines,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SchedulesScreen())),
      ),
      const SizedBox(width: 8),
      _SquareButton(
        icon: Icons.people_rounded,
        tooltip: l10n.familyTitle,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FamilyScreen())),
      ),
      const SizedBox(width: 8),
      _SquareButton(
        icon: Icons.settings_rounded,
        tooltip: l10n.familySettings,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
      ),
    ],
  );
}

/// Picks the baby (of any family) the app shows; "Add a baby" for caregivers.
void showChildSwitcher(BuildContext context) {
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
          if (!s.bookOnly)
            ListTile(
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: context.pal.surface,
                child: Icon(Icons.add, color: context.pal.ink),
              ),
              title: Text(l10n.homeAddBaby),
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

/// What needs doing: the child's medicine schedules (when the next dose is allowed, with a button
/// to log one) and the reminders that are due ("no feed for 3h 10m"). Works without a server's
/// notifications; refreshed every minute so a reminder shows up as soon as it's due.
class _ReminderStrip extends StatefulWidget {
  const _ReminderStrip();

  @override
  State<_ReminderStrip> createState() => _ReminderStripState();
}

class _ReminderStripState extends State<_ReminderStrip> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  static String _medicineStatus(Map m, DateTime now) {
    final next = DateTime.tryParse('${m['next_at']}')?.toLocal();
    if (next == null) return l10n.homeNoDoseYet;
    if (!next.isAfter(now)) return l10n.homeDoseNow;
    final at = DateFormat.Hm().format(next);
    final day = DateTime(next.year, next.month, next.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    final when = day == 0
        ? l10n.homeNextDoseToday(at)
        : (day == 1 ? l10n.homeNextDoseTomorrow(at) : l10n.homeNextDoseOn(DateFormat.MMMd().format(next), at));
    final max = toInt(m['max_per_day']);
    return max == null ? when : '$when · ${l10n.homeDosesIn24h('${m['doses_24h']}', max)}';
  }

  /// The child's reminders that are due now: type, time since, and a key naming the entry it
  /// counts from (like src/reminders.rs, which also sends them to phones when the server can).
  static List<(String, Duration, String)> dueReminders(AppState s, DateTime now) {
    final out = <(String, Duration, String)>[];
    for (final r in s.child?.reminders ?? const <Map<String, dynamic>>[]) {
      final type = r['type'] as String?, after = toInt(r['after_minutes']);
      if (type == null || after == null) continue;
      final timer = type == 'feed' ? 'breastfeed' : type;
      if (s.timers.any((t) => t.kind == timer)) continue;
      final v = s.summary?['last']?[type];
      if (v is! Map<String, dynamic>) continue;
      final e = Event(v);
      final ref = type == 'sleep' ? (e.end ?? e.start) : e.start;
      final since = now.difference(ref);
      if (since.inMinutes >= after) out.add((type, since, '${s.childId}/$type/${ref.millisecondsSinceEpoch}'));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final pal = context.pal, now = DateTime.now();
    // Swiping a row away hides it on this device until what it is about changes (its key).
    Widget row({
      required String key,
      required Kind kind,
      IconData? icon,
      required String title,
      required String status,
      required bool urgent,
      String? action,
      VoidCallback? onTap,
    }) {
      final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
      // Shown under the card while it is swiped, on the side it uncovers.
      Widget behind(Alignment side) => Container(
        alignment: side,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: pal.accentSoft, borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off_rounded, size: 20, color: pal.accent),
            const SizedBox(width: 6),
            Text(l10n.homeHide, style: TextStyle(color: pal.accent, fontWeight: FontWeight.w700)),
          ],
        ),
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Dismissible(
          key: ValueKey(key),
          onDismissed: (_) => s.dismiss(key),
          background: behind(Alignment.centerLeft),
          secondaryBackground: behind(Alignment.centerRight),
          child: Material(
            color: pal.surface,
            shape: shape.copyWith(side: BorderSide(color: pal.line)),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              shape: shape,
              leading: BlobIcon(kind, icon: icon, size: 38),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                status,
                style: TextStyle(color: urgent ? kind.on(pal) : pal.muted, fontWeight: urgent ? FontWeight.w700 : null),
              ),
              trailing: action == null ? null : FilledButton.tonal(onPressed: onTap, child: Text(action)),
              onTap: onTap,
            ),
          ),
        ),
      );
    }
    final rows = <(String, Widget Function(String))>[
      for (final (type, since, key) in dueReminders(s, now))
        (
          key,
          (key) => row(
            key: key,
            kind: switch (type) {
              'feed' => Kind.breast,
              'sleep' => Kind.sleep,
              'diaper' => Kind.diaper,
              _ => Kind.pump,
            },
            title: switch (type) {
              'feed' => l10n.homeFeedReminder,
              'sleep' => l10n.homeSleepReminder,
              'diaper' => l10n.homeDiaperReminder,
              _ => l10n.homePumpReminder,
            },
            status: switch (type) {
              'feed' => l10n.homeNoFeedFor(duration(since.inSeconds)),
              'sleep' => l10n.homeAwakeFor(duration(since.inSeconds)),
              'diaper' => l10n.homeNoDiaperFor(duration(since.inSeconds)),
              _ => l10n.homeNoPumpFor(duration(since.inSeconds)),
            },
            urgent: true,
            action: type == 'sleep' ? l10n.homeStart : l10n.homeLog,
            onTap: () => switch (type) {
              'feed' => showFeedPicker(context),
              'diaper' => showEventForm(context, type: 'diaper'),
              final kind => TimerScreen.open(context, kind),
            },
          ),
        ),
      for (final m in (s.summary?['medicines'] as List? ?? const []))
        if (m is Map)
          () {
            final next = DateTime.tryParse('${m['next_at']}')?.toLocal();
            final canGive = next == null || !next.isAfter(now);
            void give() => showEventForm(
              context,
              type: 'health',
              prefill: {'kind': 'medicine', 'name': m['name'], 'dose': m['dose'], 'dose_unit': m['dose_unit']},
            );
            // Comes back after the next dose, and when the next one becomes allowed.
            final key = '${s.childId}/medicine/${medicineKey('${m['name']}')}/${m['next_at']}/$canGive';
            return (
              key,
              (String key) => row(
                key: key,
                kind: Kind.health,
                icon: Icons.medication_rounded,
                title: '${m['name']}',
                status: _medicineStatus(m, now),
                urgent: canGive,
                action: canGive ? l10n.homeGive : null,
                onTap: give,
              ),
            );
          }(),
    ].where((r) => !s.dismissed.contains(r.$1)).toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    // One card per row, so each one can be swiped away on its own.
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(children: [for (final (key, build) in rows) build(key)]),
    );
  }
}

class _TodayStrip extends StatelessWidget {
  const _TodayStrip({required this.today, required this.units, required this.rolling});
  final Map<String, dynamic> today;
  final Units units;

  /// Totals for the last 24 hours rather than the calendar day.
  final bool rolling;

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
      l10n.homeBreastCount(n(feed, 'breast_count')),
      units.volume(toDouble(feed['bottle_ml']) ?? 0),
      if (solids > 0) l10n.homeSolidsCount(solids),
    ].join(' · ');
    // Night sleep (18–06, as in Trends) and daytime naps; whichever there is.
    final night = n(sleep, 'night_seconds'), naps = n(sleep, 'nap_count');
    final sleepParts = [if (night > 0) l10n.homeNightSleep(duration(night)), if (naps > 0) l10n.homeNaps(naps)];
    final sleepDetail = sleepParts.isEmpty ? l10n.homeNaps(0) : sleepParts.join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: context.pal.accentSoft, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          stat('${feed['count'] ?? 0}', rolling ? l10n.homeFeedsIn24h : l10n.homeFeedsToday, detail(feedDetail, Kind.breast)),
          stat(duration(toInt(sleep['total_seconds']) ?? 0), rolling ? l10n.homeSleepIn24h : l10n.homeSleepToday, detail(sleepDetail, Kind.sleep)),
          // A diaper can be both wet and dirty.
          stat(
            '${diaper['count'] ?? 0}',
            rolling ? l10n.homeDiapersIn24h : l10n.homeDiapersToday,
            detail(
              [
                l10n.homeWetDirtyCounts(n(diaper, 'dirty'), n(diaper, 'wet')),
                if (n(diaper, 'potty_count') > 0) l10n.homePottyCount(n(diaper, 'potty_count')),
              ].join(' · '),
              Kind.diaper,
            ),
          ),
        ],
      ),
    );
  }
}

/// Feed card: pick the kind of feed.
void showFeedPicker(BuildContext context) {
  final options = <(Kind, String, VoidCallback)>[
    (Kind.breast, l10n.kindBreastfeed, () => TimerScreen.open(context, 'breastfeed')),
    (Kind.bottle, l10n.kindBottle, () => showEventForm(context, type: 'feed', method: 'bottle')),
    (Kind.solids, l10n.kindSolids, () => showEventForm(context, type: 'feed', method: 'solids')),
    (Kind.combo, l10n.kindCombo, () => showEventForm(context, type: 'feed', method: 'combo')),
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
              child: Text(l10n.homeLogFeed, style: serifStyle(22)),
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
