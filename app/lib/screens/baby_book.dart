import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/date_time.dart';
import '../widgets/photo.dart';
import 'book_pages.dart';
import 'family.dart' show SettingsScreen;
import 'home.dart' show ChildAvatar, showChildSwitcher;
import 'teeth_chart.dart';

/// The book's chapters, in order (`BOOK_CHAPTERS` in src/model.rs).
enum BookChapter {
  waiting('waiting', Icons.pregnant_woman_rounded),
  hello('hello', Icons.child_friendly_rounded),
  firsts('firsts', Icons.auto_awesome_rounded),
  growing('growing', Icons.straighten_rounded),
  celebrations('celebrations', Icons.celebration_rounded);

  const BookChapter(this.id, this.icon);

  /// Saved on a memory (`chapter`); never translated.
  final String id;
  final IconData icon;

  String get title => switch (this) {
    waiting => l10n.bookChapterWaiting,
    hello => l10n.bookChapterHello,
    firsts => l10n.bookChapterFirsts,
    growing => l10n.bookChapterGrowing,
    celebrations => l10n.bookChapterCelebrations,
  };

  /// The short name on the contents tabs.
  String get tab => switch (this) {
    waiting => l10n.bookTabWaiting,
    hello => l10n.bookTabHello,
    firsts => l10n.bookTabFirsts,
    growing => l10n.bookTabGrowing,
    celebrations => l10n.bookTabCelebrations,
  };

  String get subtitle => switch (this) {
    waiting => l10n.bookChapterSubWaiting,
    hello => l10n.bookChapterSubHello,
    firsts => l10n.bookChapterSubFirsts,
    growing => l10n.bookChapterSubGrowing,
    celebrations => l10n.bookChapterSubCelebrations,
  };

  static BookChapter? byId(Object? id) => values.where((c) => c.id == id).firstOrNull;
}

/// A first worth remembering, offered in the baby book and the memory form.
class MilestoneIdea {
  const MilestoneIdea(this.id, this._label, this.icon, this._when, [this.chapter = BookChapter.firsts, this.repeats = false]);

  /// The English name: what a memory picked from this idea is saved as (the teeth chart saves
  /// "First tooth" too), so the book finds it again in any language.
  final String id;
  final String Function(AppLocalizations) _label, _when;
  final IconData icon;
  final BookChapter chapter;

  /// Stays offered once in the book (a belly photo at 20 weeks, another at 36).
  final bool repeats;

  /// The name shown, in the app's language.
  String get label => _label(l10n);

  /// Roughly when it happens, as a hint.
  String get when => _when(l10n);
}

/// A month's name ("December"), as a "when" hint.
String _month(int month) => DateFormat.LLLL().format(DateTime(2000, month));

/// Ideas for the baby book, by chapter, in about the order they come. Any other name works too.
final milestoneIdeas = [
  MilestoneIdea('We found out', (t) => t.bookIdeaFoundOut, Icons.favorite_border_rounded, (t) => t.bookWhenTest, BookChapter.waiting),
  MilestoneIdea('First ultrasound', (t) => t.bookIdeaUltrasound, Icons.monitor_heart_rounded, (t) => t.bookWhenAroundWeeksRange(8, 12), BookChapter.waiting),
  MilestoneIdea('Heard the heartbeat', (t) => t.bookIdeaHeartbeat, Icons.graphic_eq_rounded, (t) => t.bookWhenAroundWeeksRange(10, 12), BookChapter.waiting),
  MilestoneIdea('Boy or girl?', (t) => t.bookIdeaBoyOrGirl, Icons.help_outline_rounded, (t) => t.bookWhenAroundWeeks(20), BookChapter.waiting),
  MilestoneIdea('The belly', (t) => t.bookIdeaBelly, Icons.pregnant_woman_rounded, (t) => t.bookWhenNowAndThen, BookChapter.waiting, true),
  MilestoneIdea('Baby shower', (t) => t.bookIdeaBabyShower, Icons.card_giftcard_rounded, (t) => t.bookWhenLastWeeks, BookChapter.waiting),
  MilestoneIdea('Came home', (t) => t.bookIdeaCameHome, Icons.home_rounded, (t) => t.bookWhenFirstDays, BookChapter.hello),
  MilestoneIdea('First bath', (t) => t.bookIdeaFirstBath, Icons.bathtub_rounded, (t) => t.bookWhenFirstWeeks, BookChapter.hello),
  MilestoneIdea('Met the grandparents', (t) => t.bookIdeaGrandparents, Icons.diversity_1_rounded, (t) => t.bookWhenFirstWeeks, BookChapter.hello),
  MilestoneIdea('First walk outside', (t) => t.bookIdeaFirstWalk, Icons.park_rounded, (t) => t.bookWhenFirstWeeks, BookChapter.hello),
  // Firsts: talking and listening, moving, eating, the rest.
  MilestoneIdea('Cooed', (t) => t.bookIdeaCooed, Icons.music_note_rounded, (t) => t.bookWhenWeeksRange(6, 8)),
  MilestoneIdea('First smile', (t) => t.bookIdeaFirstSmile, Icons.sentiment_very_satisfied_rounded, (t) => t.bookWhenAroundWeeks(6)),
  MilestoneIdea('Found hands', (t) => t.bookIdeaFoundHands, Icons.back_hand_rounded, (t) => t.bookWhenMonthsRange(2, 3)),
  MilestoneIdea('Held head up', (t) => t.bookIdeaHeldHead, Icons.face_rounded, (t) => t.bookWhenMonthsRange(2, 4)),
  MilestoneIdea('Turned toward sounds', (t) => t.bookIdeaSounds, Icons.hearing_rounded, (t) => t.bookWhenMonthsRange(3, 4)),
  MilestoneIdea('First laugh', (t) => t.bookIdeaFirstLaugh, Icons.emoji_emotions_rounded, (t) => t.bookWhenMonthsRange(3, 4)),
  MilestoneIdea('Reached for a toy', (t) => t.bookIdeaReachedToy, Icons.toys_rounded, (t) => t.bookWhenMonthsRange(3, 5)),
  MilestoneIdea('Found toes', (t) => t.bookIdeaFoundToes, Icons.do_not_step_rounded, (t) => t.bookWhenMonthsRange(4, 6)),
  MilestoneIdea('Rolled over', (t) => t.bookIdeaRolledOver, Icons.sync_rounded, (t) => t.bookWhenMonthsRange(4, 6)),
  MilestoneIdea('First bottle', (t) => t.bookIdeaFirstBottle, Icons.local_drink_rounded, (t) => t.bookWhenAnyTime),
  MilestoneIdea('Slept through the night', (t) => t.bookIdeaSleptNight, Icons.nights_stay_rounded, (t) => t.bookWhenAnyTime),
  MilestoneIdea('First solid food', (t) => t.bookIdeaFirstSolid, Icons.restaurant_rounded, (t) => t.bookWhenAroundMonths(6)),
  MilestoneIdea('Knew own name', (t) => t.bookIdeaOwnName, Icons.record_voice_over_rounded, (t) => t.bookWhenMonthsRange(5, 7)),
  MilestoneIdea('Sat up alone', (t) => t.bookIdeaSatUp, Icons.event_seat_rounded, (t) => t.bookWhenMonthsRange(6, 8)),
  MilestoneIdea('Held own bottle', (t) => t.bookIdeaOwnBottle, Icons.sports_bar_rounded, (t) => t.bookWhenMonthsRange(6, 10)),
  MilestoneIdea('Crawled', (t) => t.bookIdeaCrawled, Icons.child_care_rounded, (t) => t.bookWhenMonthsRange(7, 10)),
  MilestoneIdea('Waved bye-bye', (t) => t.bookIdeaWaved, Icons.waving_hand_rounded, (t) => t.bookWhenMonthsRange(8, 10)),
  MilestoneIdea('Clapped hands', (t) => t.bookIdeaClapped, Icons.front_hand_rounded, (t) => t.bookWhenMonthsRange(8, 10)),
  MilestoneIdea('Said "mama"', (t) => t.bookIdeaMama, Icons.chat_bubble_rounded, (t) => t.bookWhenMonthsRange(8, 12)),
  MilestoneIdea('Said "dada"', (t) => t.bookIdeaDada, Icons.chat_rounded, (t) => t.bookWhenMonthsRange(8, 12)),
  MilestoneIdea('Pulled to stand', (t) => t.bookIdeaPulledStand, Icons.accessibility_new_rounded, (t) => t.bookWhenMonthsRange(9, 12)),
  MilestoneIdea('First drink from a cup', (t) => t.bookIdeaCup, Icons.coffee_rounded, (t) => t.bookWhenMonthsRange(9, 12)),
  MilestoneIdea('Gave a kiss', (t) => t.bookIdeaKiss, Icons.favorite_rounded, (t) => t.bookWhenMonthsRange(10, 14)),
  MilestoneIdea('First word', (t) => t.bookIdeaFirstWord, Icons.forum_rounded, (t) => t.bookWhenMonthsRange(10, 14)),
  MilestoneIdea('Stood alone', (t) => t.bookIdeaStoodAlone, Icons.man_rounded, (t) => t.bookWhenMonthsRange(10, 14)),
  MilestoneIdea('First steps', (t) => t.bookIdeaFirstSteps, Icons.directions_walk_rounded, (t) => t.bookWhenMonthsRange(9, 15)),
  MilestoneIdea('Fed self with a spoon', (t) => t.bookIdeaSpoon, Icons.soup_kitchen_rounded, (t) => t.bookWhenMonthsRange(12, 18)),
  MilestoneIdea('First dance', (t) => t.bookIdeaFirstDance, Icons.nightlife_rounded, (t) => t.bookWhenAnyTime),
  MilestoneIdea('First haircut', (t) => t.bookIdeaHaircut, Icons.content_cut_rounded, (t) => t.bookWhenAnyTime),
  MilestoneIdea('First swim', (t) => t.bookIdeaSwim, Icons.pool_rounded, (t) => t.bookWhenAnyTime),
  MilestoneIdea('First snow', (t) => t.bookIdeaSnow, Icons.ac_unit_rounded, (t) => t.bookWhenAnyTime),
  MilestoneIdea('First day at daycare', (t) => t.bookIdeaDaycare, Icons.school_rounded, (t) => t.bookWhenAnyTime),
  MilestoneIdea('First tooth', (t) => t.bookIdeaFirstTooth, Icons.auto_awesome_rounded, (t) => t.bookWhenMonthsRange(6, 10), BookChapter.growing),
  MilestoneIdea('Up a diaper size', (t) => t.bookIdeaDiaperSize, Icons.baby_changing_station_rounded, (t) => t.bookWhenNowAndThen, BookChapter.growing, true),
  MilestoneIdea('Up a clothes size', (t) => t.bookIdeaClothesSize, Icons.checkroom_rounded, (t) => t.bookWhenNowAndThen, BookChapter.growing, true),
  MilestoneIdea('Outgrew the bassinet', (t) => t.bookIdeaBassinet, Icons.crib_rounded, (t) => t.bookWhenMonthsRange(3, 6), BookChapter.growing),
  MilestoneIdea('Own room', (t) => t.bookIdeaOwnRoom, Icons.bedroom_baby_rounded, (t) => t.bookWhenAnyTime, BookChapter.growing),
  MilestoneIdea('Forward-facing car seat', (t) => t.bookIdeaCarSeat, Icons.directions_car_rounded, (t) => t.bookWhenAfterYears(2), BookChapter.growing),
  MilestoneIdea('First shoes', (t) => t.bookIdeaFirstShoes, Icons.directions_run_rounded, (t) => t.bookWhenWithFirstSteps, BookChapter.growing),
  MilestoneIdea('First Christmas', (t) => t.bookIdeaChristmas, Icons.park_rounded, (t) => _month(12), BookChapter.celebrations),
  MilestoneIdea('First Halloween', (t) => t.bookIdeaHalloween, Icons.dark_mode_rounded, (t) => _month(10), BookChapter.celebrations),
  MilestoneIdea('First Easter', (t) => t.bookIdeaEaster, Icons.egg_rounded, (t) => t.bookWhenSpring, BookChapter.celebrations),
  MilestoneIdea("First Mother's Day", (t) => t.bookIdeaMothersDay, Icons.local_florist_rounded, (t) => _month(5), BookChapter.celebrations),
  MilestoneIdea("First Father's Day", (t) => t.bookIdeaFathersDay, Icons.redeem_rounded, (t) => _month(6), BookChapter.celebrations),
  MilestoneIdea('Baptism or naming day', (t) => t.bookIdeaBaptism, Icons.water_drop_rounded, (t) => t.bookWhenAnyTime, BookChapter.celebrations),
  MilestoneIdea('First trip', (t) => t.bookIdeaTrip, Icons.luggage_rounded, (t) => t.bookWhenAnyTime, BookChapter.celebrations),
  MilestoneIdea('First birthday', (t) => t.bookIdeaBirthday, Icons.cake_rounded, (t) => t.ageYears(1), BookChapter.celebrations),
];

String _key(String name) => name.trim().toLowerCase();

/// Every language's name of each idea (and the English id) → the idea.
final Map<String, MilestoneIdea> _ideasByKey = {
  for (final locale in AppLocalizations.supportedLocales)
    for (final i in milestoneIdeas) _key(i._label(lookupAppLocalizations(locale))): i,
  for (final i in milestoneIdeas) _key(i.id): i,
};

/// The idea a memory's name is, whichever language it was typed in.
MilestoneIdea? ideaFor(String? name) => name == null ? null : _ideasByKey[_key(name)];

/// Whether [name] is the "First tooth" memory (saved in English, typed in any language).
bool isFirstTooth(String? name) => ideaFor(name)?.id == 'First tooth';

/// A memory's name as shown: an idea's (or the banana's) in the app's language, else as typed.
String memoryLabel(String name) => ideaFor(name)?.label ?? (_isBananaName(name) ? l10n.bookBananaName : name);

/// The monthly photo next to a banana, to see how much they grew: any number of these, shown as
/// a strip in Growing up rather than as memories. Saved under this English name.
const bananaName = 'Banana for scale';

final Set<String> _bananaKeys = {
  _key(bananaName),
  for (final locale in AppLocalizations.supportedLocales) _key(lookupAppLocalizations(locale).bookBananaName),
};

bool _isBananaName(String? name) => name != null && _bananaKeys.contains(_key(name));

bool isBanana(Event e) => _isBananaName(e['name'] as String?);

/// The name a memory is saved under: an idea's (or the banana's) English id when it is one,
/// in whatever language it was typed, else the name as typed.
String storedMemoryName(String name) => ideaFor(name)?.id ?? (_isBananaName(name) ? bananaName : name);

/// The chapter a memory goes in when none was picked: its idea's, Waiting for you before the
/// [birth] day, else Firsts.
BookChapter autoChapter(String? name, {DateTime? at, DateTime? birth}) {
  final idea = ideaFor(name);
  if (idea != null) return idea.chapter;
  if (_isBananaName(name)) return BookChapter.growing;
  if (at != null && birth != null && at.isBefore(DateTime(birth.year, birth.month, birth.day))) return BookChapter.waiting;
  return BookChapter.firsts;
}

/// The chapter a memory is in: the one saved with it (the app saves it always; older entries and
/// imports may have none).
BookChapter chapterOf(Event e, {DateTime? birth}) =>
    BookChapter.byId(e['chapter']) ?? autoChapter(e['name'] as String?, at: e.start, birth: birth);

/// The selected child's memories (milestones), oldest first, reloaded whenever data changes.
mixin _Memories<T extends StatefulWidget> on State<T> {
  List<Event>? memories;
  (String?, int)? _loadedFor;

  /// Also loads the Growth entries (the book's growth pages).
  bool get wantsGrowth => false;
  List<Event> growth = const [];

  void watchMemories(AppState s) {
    final key = (s.childId, s.revision);
    if (_loadedFor == key) return;
    _loadedFor = key;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (s.childId == null || s.api == null) return;
      final path = '/children/${s.childId}/events';
      final res = await guard(context, () => s.api!.get(path, {'type': 'milestone', 'limit': '1000'}));
      if (!mounted) return;
      final grown = wantsGrowth ? await guard(context, () => s.api!.get(path, {'type': 'growth', 'limit': '1000'})) : null;
      if (!mounted || res == null) return;
      setState(() {
        memories = [for (final e in res['events'] as List) Event(e)]..sort((a, b) => a.start.compareTo(b.start));
        if (grown != null) growth = [for (final e in grown['events'] as List) Event(e)];
      });
    });
  }

  /// Ids of the ideas already in the book.
  Set<String> get loggedIdeas => {for (final e in memories ?? const <Event>[]) ?ideaFor(e['name'] as String?)?.id};
}

/// The baby book: a cover, then four chapters (Hello world, Firsts, Growing up, Celebrations)
/// with the memories as taped-in prints, the book's own pages (birth day, name, the world, growth),
/// the teeth chart and ideas still to come. Tabs under the title jump between chapters.
class BabyBookScreen extends StatefulWidget {
  const BabyBookScreen({super.key, this.addMemory = false, this.asTab = false});

  /// Opens "New memory" over the book right away (the Firsts card), so closing it shows the book.
  final bool addMemory;

  /// Shown as a tab of the main screen (no back button).
  final bool asTab;

  @override
  State<BabyBookScreen> createState() => _BabyBookScreenState();
}

class _BabyBookScreenState extends State<BabyBookScreen> with _Memories {
  final _scroll = ScrollController();
  final _keys = {for (final c in BookChapter.values) c: GlobalKey()};
  BookChapter _current = BookChapter.values.first;

  @override
  bool get wantsGrowth => true;

  @override
  void initState() {
    super.initState();
    if (widget.addMemory) WidgetsBinding.instance.addPostFrameCallback((_) => showMemoryForm(context));
    _scroll.addListener(_track);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scroll offset at which each chapter's heading reaches the tabs (the pinned tabs are already
  /// counted; +20 trims the heading's top margin), noted while it is built
  /// (a heading far away isn't; the ones above were all built on the way down).
  final _offsets = <BookChapter, double>{};

  double? _headingOffset(BookChapter c) {
    final box = _keys[c]!.currentContext?.findRenderObject();
    if (box == null || !box.attached) return _offsets[c];
    return _offsets[c] = RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset + 20;
  }

  /// Highlights the chapter being read: the last one whose heading has reached the tabs.
  void _track() {
    var current = BookChapter.values.first;
    for (final c in BookChapter.values) {
      final at = _headingOffset(c);
      if (at != null && at <= _scroll.offset + 24) current = c;
      // At the very end the last chapter can't scroll up to the tabs: on screen is enough.
      final end = _scroll.position.maxScrollExtent;
      if (at != null && _scroll.offset >= end - 4 && at <= end + _scroll.position.viewportDimension / 2) current = c;
    }
    if (current != _current) setState(() => _current = current);
  }

  /// Scrolls so the chapter's heading sits under the tabs (building the chapters on the way).
  Future<void> _jump(BookChapter c) async {
    final from = _current;
    setState(() => _current = c);
    // Build the chapters on the way until the heading exists.
    for (var i = 0; i < 40 && _keys[c]!.currentContext == null; i++) {
      final step = MediaQuery.sizeOf(context).height * (c.index > from.index ? 1.5 : -1.5);
      _scroll.jumpTo((_scroll.offset + step).clamp(0.0, _scroll.position.maxScrollExtent));
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    final at = _headingOffset(c);
    if (at == null) return;
    await _scroll.animateTo(at.clamp(0.0, _scroll.position.maxScrollExtent), duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    // Rows built on the way (and photos arriving) move the heading: settle on it.
    for (var i = 0; i < 4 && mounted; i++) {
      await WidgetsBinding.instance.endOfFrame;
      final now = _headingOffset(c)?.clamp(0.0, _scroll.position.maxScrollExtent);
      if (!mounted || now == null || (now - _scroll.offset).abs() < 2) break;
      _scroll.jumpTo(now);
    }
    if (mounted) setState(() => _current = c);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final child = s.child;
    watchMemories(s);
    if (child == null) return const Scaffold();
    // Teeth are on the chart; only the first one is a memory of its own.
    final list = memories?.where((e) => e['tooth'] == null || isFirstTooth(e['name'] as String?)).toList();
    final byChapter = {for (final c in BookChapter.values) c: <Event>[]};
    final bananas = <Event>[];
    for (final e in list ?? const <Event>[]) {
      (isBanana(e) ? bananas : byChapter[chapterOf(e, birth: child.birthDate)]!).add(e);
    }
    final logged = loggedIdeas;
    // Book viewers (e.g. grandparents) read it: no ideas, nothing to add or edit.
    final readOnly = s.bookOnly;
    var printIndex = 0;

    List<Widget> prints(List<Event> events, {bool byAge = false}) {
      final out = <Widget>[];
      String? age;
      for (final e in events) {
        if (byAge) {
          final a = _chapter(child, e.start);
          if (a != age) {
            age = a;
            out.add(_ChapterTitle(a));
          }
        }
        out.add(_MemoryCard(event: e, child: child, index: printIndex++));
      }
      return out;
    }

    Widget ideas(BookChapter chapter, {bool seeAll = false}) {
      if (readOnly) return const SizedBox.shrink();
      final left = milestoneIdeas.where((i) => i.chapter == chapter && (i.repeats || !logged.contains(i.id))).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            chapter == BookChapter.firsts ? l10n.bookIdeasToRemember : l10n.bookIdeasForChapter,
            trailing: seeAll ? TextButton(onPressed: () => _showAllIdeas(context), child: Text(l10n.bookSeeAll)) : null,
          ),
          SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: left.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => i == 0
                  ? _IdeaSticker(
                      name: l10n.bookYourOwn,
                      icon: Icons.add_rounded,
                      when: l10n.bookWhenAnythingSpecial,
                      onTap: () => showMemoryForm(context, chapter: chapter),
                    )
                  : _IdeaSticker(
                      name: left[i - 1].label,
                      icon: left[i - 1].icon,
                      when: left[i - 1].when,
                      onTap: () => showMemoryForm(context, name: left[i - 1].label),
                    ),
            ),
          ),
        ],
      );
    }

    Widget heading(BookChapter c) => _ChapterHeading(key: _keys[c], chapter: c);

    final loading = list == null
        ? [
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
          ]
        : null;

    final rows = <Widget>[
      // Waiting for you (the pregnancy)
      heading(BookChapter.waiting),
      if (!readOnly || child.book['due_date'] != null) _DueDate(child: child),
      ...prints(byChapter[BookChapter.waiting]!),
      ideas(BookChapter.waiting),
      // Hello, world
      heading(BookChapter.hello),
      BornPage(child: child, growth: growth),
      NamePage(child: child),
      if (!readOnly || WorldPage.hasText(child)) WorldPage(child: child),
      ...?loading,
      ...prints(byChapter[BookChapter.hello]!),
      ideas(BookChapter.hello),
      // Firsts
      heading(BookChapter.firsts),
      if (list != null && byChapter[BookChapter.firsts]!.isEmpty) _EmptyBook(readOnly: readOnly),
      ...prints(byChapter[BookChapter.firsts]!, byAge: true),
      ideas(BookChapter.firsts, seeAll: true),
      // Growing up
      heading(BookChapter.growing),
      SectionTitle(
        l10n.bookTeeth,
        trailing: Text(l10n.bookAsYouLookAt(child.name), style: TextStyle(color: context.pal.muted, fontSize: 13)),
      ),
      TeethChart(child: child, milestones: memories ?? const []),
      if (!readOnly || bananas.isNotEmpty) ...[
        SectionTitle('${l10n.bookBananaName} 🍌', trailing: Text(l10n.bookPhotoAMonth, style: TextStyle(color: context.pal.muted, fontSize: 13))),
        _BananaStrip(child: child, photos: bananas),
      ],
      ...prints(byChapter[BookChapter.growing]!),
      if (!readOnly || growth.isNotEmpty) GrowthPage(child: child, growth: growth),
      ideas(BookChapter.growing),
      // Celebrations
      heading(BookChapter.celebrations),
      ...prints(byChapter[BookChapter.celebrations]!),
      ideas(BookChapter.celebrations),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.bookTitle(child.name)), automaticallyImplyLeading: !widget.asTab, actions: [if (readOnly) const BookViewerActions()]),
      body: Constrained(
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _Cover(child: child, memories: list ?? const []),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _ContentsBar(height: _ContentsBar.heightFor(context, math.min(MediaQuery.sizeOf(context).width, 640)), current: _current, onTap: _jump, background: context.pal.background),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
              sliver: SliverList.list(children: rows),
            ),
          ],
        ),
      ),
    );
  }

  /// Every idea by chapter, ticked when it's in the book.
  void _showAllIdeas(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.pal.background,
    builder: (sheet) {
      final c = context.pal;
      final byId = {
        for (final e in memories ?? const <Event>[])
          if (ideaFor(e['name'] as String?) case final idea?) idea.id: e,
      };
      final done = milestoneIdeas.where((i) => byId.containsKey(i.id)).length;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(l10n.bookIdeasToRemember, style: serifStyle(24)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(l10n.bookIdeasProgress(done, milestoneIdeas.length), style: TextStyle(color: c.muted)),
            ),
            Divider(height: 1, color: c.line),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final chapter in BookChapter.values) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                      child: Text(chapter.title, style: serifStyle(18, color: Kind.milestone.on(c))),
                    ),
                    for (final idea in milestoneIdeas.where((i) => i.chapter == chapter))
                      () {
                        final e = byId[idea.id];
                        return ListTile(
                          leading: BlobIcon(Kind.milestone, size: 40, icon: idea.icon),
                          title: Text(idea.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(e == null ? idea.when : DateFormat.yMMMd().format(e.start)),
                          trailing: e == null
                              ? Icon(Icons.add_circle_outline_rounded, color: c.accent)
                              : Icon(Icons.check_circle_rounded, color: Kind.milestone.on(c)),
                          onTap: () {
                            Navigator.pop(sheet);
                            showMemoryForm(context, event: e, name: idea.label);
                          },
                        );
                      }(),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// The due date under "Waiting for you" (memories then say how many weeks along), tap to set it.
class _DueDate extends StatelessWidget {
  const _DueDate({required this.child});
  final Child child;

  Future<void> _pick(BuildContext context) async {
    final s = context.read<AppState>();
    final current = DateTime.tryParse(child.book['due_date'] ?? '');
    final born = child.birthDate ?? DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: current ?? born,
      firstDate: born.subtract(const Duration(days: 120)),
      lastDate: born.add(const Duration(days: 120)),
      helpText: l10n.bookDueDate,
    );
    if (day == null || !context.mounted) return;
    final book = {...child.book, 'due_date': DateFormat('yyyy-MM-dd').format(day)};
    await guard(context, () => s.act((api) => api.patch('/children/${child.id}', {'book': book}), families: true));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final due = DateTime.tryParse(child.book['due_date'] ?? '');
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: context.select<AppState, bool>((s) => s.bookOnly)
            ? Chip(
                avatar: Icon(Icons.event_rounded, size: 18, color: Kind.milestone.on(c)),
                label: Text(due == null ? l10n.bookSetDueDate : l10n.bookDueOn(DateFormat.yMMMMd().format(due))),
              )
            : ActionChip(
                avatar: Icon(Icons.event_rounded, size: 18, color: Kind.milestone.on(c)),
                label: Text(due == null ? l10n.bookSetDueDate : l10n.bookDueOn(DateFormat.yMMMMd().format(due))),
                onPressed: () => _pick(context),
              ),
      ),
    );
  }
}

/// The "banana for scale" photos side by side, oldest first, each with the age it was taken at,
/// after the button that adds this month's.
class _BananaStrip extends StatelessWidget {
  const _BananaStrip({required this.child, required this.photos});
  final Child child;
  final List<Event> photos;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final k = Kind.milestone;
    final s = context.watch<AppState>();
    final readOnly = s.bookOnly;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
            l10n.bookBananaIntro(child.name),
            style: TextStyle(color: c.muted, height: 1.35),
          ),
        ),
        SizedBox(
          height: 206,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: photos.length + (readOnly ? 0 : 1),
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              if (!readOnly && i == 0) {
                return SizedBox(
                  width: 128,
                  child: Material(
                    color: k.fill(c).withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: k.on(c).withValues(alpha: 0.45), width: 1.5),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => showMemoryForm(context, name: l10n.bookBananaName),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_rounded, size: 32, color: k.on(c)),
                          const SizedBox(height: 10),
                          Text(
                            photos.isEmpty ? l10n.bookTakeFirst : l10n.bookThisMonth,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w700, color: k.on(c)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              final e = photos[readOnly ? i : i - 1];
              final bytes = e['photo_version'] == null ? null : s.eventPhoto(e);
              return SizedBox(
                width: 128,
                child: Material(
                  color: c.surface,
                  elevation: 1.5,
                  shadowColor: c.ink.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: readOnly ? (bytes == null ? null : () => _showPhoto(context, bytes, bananaName)) : () => showMemoryForm(context, event: e),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(7, 7, 7, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: bytes == null
                                  ? Container(
                                      color: k.fill(c).withValues(alpha: 0.5),
                                      alignment: Alignment.center,
                                      child: Icon(Icons.photo_rounded, size: 32, color: k.iconOn(c)),
                                    )
                                  : Image.memory(bytes, fit: BoxFit.cover, cacheWidth: 300, gaplessPlayback: true, semanticLabel: l10n.bookBananaName),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _chapter(child, e.start),
                            textAlign: TextAlign.center,
                            style: serifStyle(15, color: k.on(c)),
                          ),
                          Text(
                            DateFormat.yMMMd().format(e.start),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: c.muted, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The contents tabs, pinned under the title: one per chapter, the one being read highlighted.
class _ContentsBar extends SliverPersistentHeaderDelegate {
  _ContentsBar({required this.height, required this.current, required this.onTap, required this.background});
  final double height;
  final BookChapter current;
  final void Function(BookChapter) onTap;
  final Color background;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  bool shouldRebuild(_ContentsBar old) => old.current != current || old.background != background || old.height != height;

  static const _pad = EdgeInsets.fromLTRB(16, 6, 16, 6), _pillPad = EdgeInsets.symmetric(horizontal: 14, vertical: 9);
  static const _gap = 8.0, _icon = 17.0, _iconGap = 6.0;
  static const _label = TextStyle(fontWeight: FontWeight.w700);

  /// The bar's height for a [width]: as many rows as the pills wrap onto (one on a computer,
  /// two on most phones).
  static double heightFor(BuildContext context, double width) {
    // The theme's body text, as the pills get it inside the Scaffold: [context] may sit above any
    // Material (a pushed route), where the default text style is Flutter's oversized fallback.
    final style = Theme.of(context).textTheme.bodyMedium!.merge(_label);
    final scaler = MediaQuery.textScalerOf(context);
    final room = width - _pad.horizontal;
    var rows = 1, x = 0.0, pill = 0.0;
    for (final ch in BookChapter.values) {
      final text = TextPainter(text: TextSpan(text: ch.tab, style: style), textScaler: scaler, textDirection: Directionality.of(context))..layout();
      final w = _pillPad.horizontal + _icon + _iconGap + text.width;
      pill = math.max(pill, _pillPad.vertical + math.max(_icon, text.height));
      if (x > 0 && x + _gap + w > room) {
        rows++;
        x = w;
      } else {
        x += (x > 0 ? _gap : 0) + w;
      }
    }
    return _pad.vertical + rows * pill + (rows - 1) * _gap + 1;
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final c = context.pal;
    final k = Kind.milestone;
    // Pills with the icon on the left, wrapping onto a second row when they don't fit.
    return Container(
      color: background,
      alignment: Alignment.centerLeft,
      padding: _pad,
      child: Wrap(
        spacing: _gap,
        runSpacing: _gap,
        children: [
          for (final ch in BookChapter.values)
            Semantics(
              selected: ch == current,
              button: true,
              child: Material(
                color: ch == current ? k.fill(c) : c.surface,
                shape: StadiumBorder(side: BorderSide(color: ch == current ? k.fill(c) : c.line)),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => onTap(ch),
                  child: Padding(
                    padding: _pillPad,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(ch.icon, size: _icon, color: ch == current ? c.bandInk : k.on(c)),
                        const SizedBox(width: _iconGap),
                        Text(ch.tab, style: _label.copyWith(color: ch == current ? c.bandInk : c.ink)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A chapter's opening: "Chapter 2", its title and what's in it.
class _ChapterHeading extends StatelessWidget {
  const _ChapterHeading({super.key, required this.chapter});
  final BookChapter chapter;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final k = Kind.milestone;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 34, 4, 6),
      child: Row(
        children: [
          BlobIcon(k, size: 54, icon: chapter.icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.bookChapterNumber(chapter.index + 1),
                  style: TextStyle(color: k.on(c), fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.4),
                ),
                Text(chapter.title, style: serifStyle(28)),
                Text(chapter.subtitle, style: TextStyle(color: c.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chapter of the book a day falls in: "Newborn", "3 months", "2 years" (or the month, without
/// a birth date).
String _chapter(Child child, DateTime day) {
  final b = child.birthDate;
  if (b == null) return DateFormat.yMMMM().format(day);
  if (day.isBefore(b)) return l10n.bookBeforeBirth;
  var months = (day.year - b.year) * 12 + day.month - b.month;
  if (day.day < b.day) months--;
  if (months < 1) return l10n.bookNewborn;
  if (months < 24) return l10n.ageMonths(months);
  return l10n.ageYears(months ~/ 12);
}

/// "Saturday 12 July 2026 · 6 weeks old".
String _dateLine(Child child, DateTime day) {
  final born = child.birthDate;
  final age = born == null || day.isBefore(born) ? null : l10n.bookAgeOld(child.ageAt(day)!);
  return [DateFormat.yMMMMEEEEd().format(day), ?age ?? pregnancyWeeks(child, day)].join(' · ');
}

/// Before birth: "22 weeks along" from the due date (`book.due_date`, 40 weeks), else
/// "18 weeks before birth"; null on or after the birth date, or without one.
String? pregnancyWeeks(Child child, DateTime day) {
  final born = child.birthDate;
  final d = DateTime(day.year, day.month, day.day);
  if (born == null || !d.isBefore(born)) return null;
  final due = DateTime.tryParse(child.book['due_date'] ?? '');
  if (due != null) {
    final weeks = 40 - (due.difference(d).inDays / 7).ceil();
    if (weeks >= 1 && weeks <= 44) return l10n.bookWeeksAlong(weeks);
  }
  final before = born.difference(d).inDays ~/ 7;
  return before == 0 ? l10n.bookDaysBeforeBirth : l10n.bookWeeksBeforeBirth(before);
}

/// The book's first page: the baby, how many memories and photos, and the button to add one.
class _Cover extends StatelessWidget {
  const _Cover({required this.child, required this.memories});
  final Child child;
  final List<Event> memories;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final k = Kind.milestone;
    final photos = memories.where((e) => e['photo_version'] != null).length;
    final born = child.birthDate;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        color: k.fill(c),
        child: Stack(
          children: [
            // Soft shapes in the corners, like the home cards' blobs.
            Positioned(right: -40, top: -50, child: _blob(c.surface.withValues(alpha: 0.28), 170, 3)),
            Positioned(left: -30, bottom: -60, child: _blob(c.surface.withValues(alpha: 0.18), 150, 8)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ChildAvatar(child: child, size: 76),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.bookTheBookOf,
                              style: TextStyle(color: c.bandInk.withValues(alpha: 0.75), fontWeight: FontWeight.w600),
                            ),
                            Text(child.name, style: serifStyle(32, color: c.bandInk)),
                            if (born != null) Text(l10n.bookBorn(DateFormat.yMMMMd().format(born)), style: TextStyle(color: c.bandInk.withValues(alpha: 0.8))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          memories.isEmpty
                              ? l10n.bookNoMemories
                              : '${l10n.bookMemoryCount(memories.length)} · ${l10n.bookPhotoCount(photos)}',
                          style: TextStyle(color: c.bandInk, fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                      if (!context.select<AppState, bool>((s) => s.bookOnly))
                        FilledButton.icon(
                          onPressed: () => showMemoryForm(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: c.accent,
                            foregroundColor: c.onAccent,
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(l10n.bookAddMemory),
                        ),
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

  Widget _blob(Color color, double size, int seed) => CustomPaint(size: Size.square(size), painter: BlobPainter(color, seed));
}

/// A book viewer's buttons in the book's top bar: switch baby (when there are several) and
/// Settings (account, appearance, joining another family, signing out).
class BookViewerActions extends StatelessWidget {
  const BookViewerActions({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final babies = s.families.fold(0, (n, f) => n + f.children.length);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (babies > 1) IconButton(tooltip: l10n.homeSwitchBaby, icon: const Icon(Icons.swap_horiz_rounded), onPressed: () => showChildSwitcher(context)),
        IconButton(
          tooltip: l10n.familySettings,
          icon: const Icon(Icons.settings_rounded),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// One idea in the strip: a little card with its icon, tapped to log it.
class _IdeaSticker extends StatelessWidget {
  const _IdeaSticker({required this.name, required this.icon, required this.when, required this.onTap});
  final String name, when;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return SizedBox(
      width: 128,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BlobIcon(Kind.milestone, size: 38, icon: icon),
                const Spacer(),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, height: 1.15),
                ),
                const SizedBox(height: 2),
                Text(
                  when,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChapterTitle extends StatelessWidget {
  const _ChapterTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final line = Expanded(child: Divider(color: Kind.milestone.on(c).withValues(alpha: 0.35), thickness: 1.2));
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 30, 8, 18),
      child: Row(
        children: [
          line,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(text, style: serifStyle(19, color: Kind.milestone.on(c))),
          ),
          line,
        ],
      ),
    );
  }
}

class _EmptyBook extends StatelessWidget {
  const _EmptyBook({this.readOnly = false});
  final bool readOnly;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
    child: Column(
      children: [
        const BlobIcon(Kind.milestone, size: 84, icon: Icons.auto_stories_rounded),
        const SizedBox(height: 16),
        Text(l10n.bookEmptyTitle, style: serifStyle(22), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
          readOnly ? l10n.bookEmptyReadOnly : l10n.bookEmptyBody,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.pal.muted, height: 1.35),
        ),
      ],
    ),
  );
}

/// A memory as a scrapbook page: a photo print taped in (slightly tilted, alternating sides),
/// the title, the day with the baby's age, and the story.
class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.event, required this.child, required this.index});
  final Event event;
  final Child child;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final k = Kind.milestone;
    final s = context.watch<AppState>();
    final hasPhoto = event['photo_version'] != null;
    final bytes = hasPhoto ? s.eventPhoto(event) : null;
    final left = index.isEven;
    final name = memoryLabel((event['name'] as String?) ?? l10n.kindMilestone);
    final note = event.note;
    final idea = ideaFor(name);

    final page = Material(
      color: c.surface,
      elevation: 1.5,
      shadowColor: c.ink.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: s.bookOnly ? null : () => showMemoryForm(context, event: event),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasPhoto) ...[
                GestureDetector(
                  onTap: bytes == null ? null : () => _showPhoto(context, bytes, name),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: bytes == null
                        ? Container(
                            height: 220,
                            color: k.fill(c).withValues(alpha: 0.5),
                            alignment: Alignment.center,
                            child: Icon(Icons.photo_rounded, size: 40, color: k.iconOn(c)),
                          )
                        : ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 460),
                            child: Image.memory(
                              bytes,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              cacheWidth: 1000,
                              gaplessPlayback: true,
                              semanticLabel: l10n.bookPhotoOf(name),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!hasPhoto) ...[BlobIcon(k, size: 40, icon: idea?.icon), const SizedBox(width: 12)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: serifStyle(21)),
                        const SizedBox(height: 2),
                        Text(_dateLine(child, event.start), style: TextStyle(color: c.muted, fontSize: 13.5)),
                        if (toothFor(event['tooth'] as String?) case final tooth?)
                          Text(
                            tooth.name,
                            style: TextStyle(color: k.on(c), fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (note != null && note.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  note,
                  style: TextStyle(color: c.ink, fontSize: 15.5, height: 1.4, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    // A strip of tape holding the print on the page.
    final tape = Transform.rotate(
      angle: left ? -0.06 : 0.05,
      child: Container(width: 84, height: 22, color: k.fill(c).withValues(alpha: c.isDark ? 0.85 : 0.7)),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(left ? 2 : 22, 14, left ? 22 : 2, 18),
      child: Transform.rotate(
        angle: (left ? -1 : 1) * (hasPhoto ? 0.012 : 0.008),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            page,
            Positioned(top: -11, left: 0, right: 0, child: Center(child: tape)),
          ],
        ),
      ),
    );
  }
}

/// The photo on its own, zoomable.
void _showPhoto(BuildContext context, Uint8List bytes, String name) => Navigator.of(context).push(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (context) => Scaffold(
      appBar: AppBar(title: Text(name)),
      body: SafeArea(
        child: InteractiveViewer(
          maxScale: 5,
          child: Center(child: Image.memory(bytes, semanticLabel: l10n.bookPhotoOf(name))),
        ),
      ),
    ),
  ),
);

/// Add a memory (optionally starting from an idea's [name], or in a [chapter]) or edit [event].
Future<void> showMemoryForm(BuildContext context, {Event? event, String? name, BookChapter? chapter}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: context.pal.background,
  builder: (_) => MemoryForm(event: event, name: name, chapter: chapter),
);

class MemoryForm extends StatefulWidget {
  const MemoryForm({super.key, this.event, this.name, this.chapter});
  final Event? event;
  final String? name;

  /// The chapter it was added from ("Your own" in a chapter).
  final BookChapter? chapter;

  @override
  State<MemoryForm> createState() => _MemoryFormState();
}

class _MemoryFormState extends State<MemoryForm> with _Memories {
  Event? get e => widget.event;
  late final _name = TextEditingController(text: e?['name'] == null ? widget.name ?? '' : memoryLabel(e!['name'] as String));
  late final _note = TextEditingController(text: e?.note ?? '');
  late DateTime _start = e?.start ?? DateTime.now();
  late String? _tooth = e?['tooth'];

  /// The chapter picked by hand, or the one it was opened in (an existing memory's, an idea's, the
  /// chapter's "Your own"). Null only for a new memory from nowhere in particular: it then follows
  /// the name and date ([autoChapter]) until one is picked.
  late BookChapter? _chapter = e != null
      ? chapterOf(e!, birth: context.read<AppState>().child?.birthDate)
      : ideaFor(widget.name)?.chapter ?? widget.chapter;

  BookChapter _chapterNow(AppState s) => _chapter ?? autoChapter(_name.text, at: _start, birth: s.child?.birthDate);
  Uint8List? _newPhoto;
  bool _removePhoto = false, _busy = false, _preparing = false;

  bool get _hadPhoto => e?['photo_version'] != null;


  /// The browser in serverless mode keeps a few MB at most: no photos there.
  bool _photosAllowed(AppState s) => !(kIsWeb && s.serverless);

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  Future<void> _choosePhoto() async {
    setState(() => _preparing = true);
    final photo = await guard(context, pickMemoryPhoto);
    if (!mounted) return;
    setState(() {
      _preparing = false;
      if (photo != null) {
        _newPhoto = photo;
        _removePhoto = false;
      }
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return showMessage(context, l10n.bookNameNeeded);
    setState(() => _busy = true);
    final s = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final note = _note.text.trim();
    final tooth = isFirstTooth(name) || e?['tooth'] != null ? _tooth : null;
    // Always saved, so a renamed memory (or a later list of ideas) never moves it.
    final chapter = _chapterNow(s).id;
    final body = {'type': 'milestone', 'name': storedMemoryName(name), 'start': formatTime(_start), 'note': note.isEmpty ? null : note, 'tooth': tooth, 'chapter': chapter};
    if (e == null) body.removeWhere((k, v) => v == null);
    final saved = await guard(context, () => s.act((api) => e == null ? api.post('/children/${s.childId}/events', body) : api.patch('/events/${e!.id}', body)));
    if (saved is! Map) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    final id = saved['id'] as String;
    String? problem;
    try {
      if (_newPhoto != null) {
        final withPhoto = await s.api!.putBytes('/events/$id/photo', _newPhoto!, contentType: 'image/jpeg');
        if (withPhoto is Map<String, dynamic>) s.rememberEventPhoto(withPhoto, _newPhoto!);
        await s.refreshChild();
      } else if (_removePhoto && _hadPhoto) {
        await s.act((api) => api.delete('/events/$id/photo'));
      }
    } on Exception catch (err) {
      problem = l10n.bookPhotoNotSaved(err is ApiException ? err.message : '$err');
    }
    if (!mounted) return;
    Navigator.pop(context);
    if (problem != null) messenger.showSnackBar(SnackBar(content: Text(problem)));
  }

  Future<void> _delete() async {
    if (!await confirm(context, l10n.bookDeleteTitle, l10n.bookDeleteBody)) return;
    if (!mounted) return;
    final s = context.read<AppState>();
    final ok = await guard(context, () => s.act((api) => api.delete('/events/${e!.id}')).then((_) => true));
    if (ok == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final s = context.watch<AppState>();
    if (e == null) watchMemories(s);
    final k = Kind.milestone;
    final strong = c.isDark ? k.fill(c) : k.deepTone;
    final saved = _hadPhoto && !_removePhoto ? s.eventPhoto(e!) : null;
    final picture = _newPhoto ?? saved;
    final showsPhoto = _newPhoto != null || (_hadPhoto && !_removePhoto);
    final idea = ideaFor(_name.text);

    final chapter = _chapterNow(s);

    // Ideas not in the book yet: the chapter's, or, once something is typed, any that match
    // (the chapter's first).
    final typed = _key(_name.text), logged = loggedIdeas;
    final open = milestoneIdeas.where((i) => (i.repeats || !logged.contains(i.id)) && (typed.isEmpty ? i.chapter == chapter : _key(i.label).contains(typed)));
    final suggestions = e != null || idea != null
        ? const <MilestoneIdea>[]
        : [...open.where((i) => i.chapter == chapter), ...open.where((i) => i.chapter != chapter)].take(12).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92, maxWidth: 640),
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
                child: Row(
                  children: [
                    BlobIcon(k, size: 46, icon: idea?.icon),
                    const SizedBox(width: 14),
                    Expanded(child: Text(e == null ? l10n.bookNewMemory : l10n.bookEditMemory, style: serifStyle(24))),
                    if (e != null) IconButton(onPressed: _delete, tooltip: l10n.delete, icon: const Icon(Icons.delete_outline_rounded), color: c.danger),
                  ],
                ),
              ),
              Divider(height: 1, color: c.line),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (_photosAllowed(s))
                      Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 16), child: showsPhoto ? _photoPreview(picture) : _addPhoto()),
                    Divider(height: 1, color: c.line),
                    FormRow(
                      label: l10n.bookChapter,
                      below: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final ch in BookChapter.values)
                            ChoiceChip(
                              avatar: Icon(ch.icon, size: 18, color: k.on(c)),
                              label: Text(ch.title),
                              selected: chapter == ch,
                              onSelected: (_) => setState(() => _chapter = ch),
                            ),
                        ],
                      ),
                    ),
                    FormRow(
                      label: l10n.bookWhatHappened,
                      below: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _name,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(hintText: l10n.bookNameHint),
                          ),
                          if (suggestions.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final i in suggestions)
                                  ActionChip(
                                    avatar: Icon(i.icon, size: 18, color: k.on(c)),
                                    label: Text(i.label),
                                    onPressed: () => setState(() {
                                      _chapter = i.chapter;
                                      _name.text = i.label;
                                    }),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isFirstTooth(_name.text) || e?['tooth'] != null)
                      FormRow(
                        label: l10n.bookWhichTooth,
                        child: DropdownButton<String?>(
                          value: _tooth,
                          isDense: true,
                          isExpanded: true,
                          underline: const SizedBox(),
                          hint: Text(l10n.formChoose),
                          items: [for (final t in babyTeeth) DropdownMenuItem(value: t.code, child: Text(t.name))],
                          onChanged: (v) => setState(() => _tooth = v),
                        ),
                      ),
                    FormRow(
                      label: l10n.formWhen,
                      child: DateTimeValue(value: _start, onChanged: (v) => setState(() => _start = v)),
                    ),
                    FormRow(
                      label: l10n.bookStory,
                      below: TextField(
                        controller: _note,
                        maxLines: null,
                        minLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(hintText: l10n.bookStoryHint),
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: FilledButton(
                    onPressed: _busy || _preparing ? null : _save,
                    style: FilledButton.styleFrom(backgroundColor: strong, foregroundColor: c.onAccent),
                    child: Text(_busy ? l10n.bookSaving : (e == null ? l10n.bookSaveToBook : l10n.formSaveChanges)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addPhoto() {
    final c = context.pal;
    final k = Kind.milestone;
    return Material(
      color: k.fill(c).withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: k.on(c).withValues(alpha: 0.45), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _preparing ? null : _choosePhoto,
        child: SizedBox(
          height: 132,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_preparing)
                const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5))
              else
                Icon(Icons.add_a_photo_rounded, size: 34, color: k.on(c)),
              const SizedBox(height: 10),
              Text(
                _preparing ? l10n.bookPreparingPhoto : l10n.bookAddPhoto,
                style: TextStyle(fontWeight: FontWeight.w700, color: k.on(c), fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoPreview(Uint8List? picture) {
    final c = context.pal;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: picture == null
              ? Container(height: 200, color: c.raised, alignment: Alignment.center, child: const CircularProgressIndicator())
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: Image.memory(picture, fit: BoxFit.cover, width: double.infinity, cacheWidth: 1000, gaplessPlayback: true),
                ),
        ),
        Positioned(
          right: 10,
          bottom: 10,
          child: Row(
            children: [
              _photoButton(Icons.photo_library_rounded, l10n.bookChangePhoto, _preparing ? null : _choosePhoto),
              const SizedBox(width: 8),
              _photoButton(
                Icons.delete_outline_rounded,
                l10n.remove,
                () => setState(() {
                  _newPhoto = null;
                  _removePhoto = true;
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _photoButton(IconData icon, String label, VoidCallback? onTap) => FilledButton.tonalIcon(
    onPressed: onTap,
    style: FilledButton.styleFrom(
      backgroundColor: context.pal.surface.withValues(alpha: 0.92),
      foregroundColor: context.pal.ink,
      minimumSize: const Size(0, 38),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
    icon: Icon(icon, size: 18),
    label: Text(label),
  );
}
