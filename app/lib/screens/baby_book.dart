import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
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
  waiting('waiting', 'Waiting for you', 'Waiting', 'Before you arrived', Icons.pregnant_woman_rounded),
  hello('hello', 'Hello, world', 'Hello', 'The very beginning', Icons.child_friendly_rounded),
  firsts('firsts', 'Firsts', 'Firsts', 'Every new thing, month by month', Icons.auto_awesome_rounded),
  growing('growing', 'Growing up', 'Growing', 'Teeth, size, and how fast it goes', Icons.straighten_rounded),
  celebrations('celebrations', 'Celebrations', 'Celebrations', 'Holidays and special days', Icons.celebration_rounded);

  const BookChapter(this.id, this.title, this.tab, this.subtitle, this.icon);
  final String id, title, tab, subtitle;
  final IconData icon;

  static BookChapter? byId(Object? id) => values.where((c) => c.id == id).firstOrNull;
}

/// A first worth remembering, offered in the baby book and the memory form.
class MilestoneIdea {
  const MilestoneIdea(this.name, this.icon, this.when, [this.chapter = BookChapter.firsts, this.repeats = false]);
  final String name;
  final IconData icon;

  /// Roughly when it happens, as a hint.
  final String when;
  final BookChapter chapter;

  /// Stays offered once in the book (a belly photo at 20 weeks, another at 36).
  final bool repeats;
}

/// Ideas for the baby book, by chapter, in about the order they come. Any other name works too.
const milestoneIdeas = [
  MilestoneIdea('We found out', Icons.favorite_border_rounded, 'the test', BookChapter.waiting),
  MilestoneIdea('First ultrasound', Icons.monitor_heart_rounded, 'around 8–12 weeks', BookChapter.waiting),
  MilestoneIdea('Heard the heartbeat', Icons.graphic_eq_rounded, 'around 10–12 weeks', BookChapter.waiting),
  MilestoneIdea('Boy or girl?', Icons.help_outline_rounded, 'around 20 weeks', BookChapter.waiting),
  MilestoneIdea('The belly', Icons.pregnant_woman_rounded, 'one now and then', BookChapter.waiting, true),
  MilestoneIdea('Baby shower', Icons.card_giftcard_rounded, 'last weeks', BookChapter.waiting),
  MilestoneIdea('Came home', Icons.home_rounded, 'first days', BookChapter.hello),
  MilestoneIdea('First bath', Icons.bathtub_rounded, 'first weeks', BookChapter.hello),
  MilestoneIdea('Met the grandparents', Icons.diversity_1_rounded, 'first weeks', BookChapter.hello),
  MilestoneIdea('First walk outside', Icons.park_rounded, 'first weeks', BookChapter.hello),
  // Firsts: talking and listening, moving, eating, the rest.
  MilestoneIdea('Cooed', Icons.music_note_rounded, '6–8 weeks'),
  MilestoneIdea('First smile', Icons.sentiment_very_satisfied_rounded, 'around 6 weeks'),
  MilestoneIdea('Found hands', Icons.back_hand_rounded, '2–3 months'),
  MilestoneIdea('Held head up', Icons.face_rounded, '2–4 months'),
  MilestoneIdea('Turned toward sounds', Icons.hearing_rounded, '3–4 months'),
  MilestoneIdea('First laugh', Icons.emoji_emotions_rounded, '3–4 months'),
  MilestoneIdea('Reached for a toy', Icons.toys_rounded, '3–5 months'),
  MilestoneIdea('Found toes', Icons.do_not_step_rounded, '4–6 months'),
  MilestoneIdea('Rolled over', Icons.sync_rounded, '4–6 months'),
  MilestoneIdea('First bottle', Icons.local_drink_rounded, 'any time'),
  MilestoneIdea('Slept through the night', Icons.nights_stay_rounded, 'any time'),
  MilestoneIdea('First solid food', Icons.restaurant_rounded, 'around 6 months'),
  MilestoneIdea('Knew own name', Icons.record_voice_over_rounded, '5–7 months'),
  MilestoneIdea('Sat up alone', Icons.event_seat_rounded, '6–8 months'),
  MilestoneIdea('Held own bottle', Icons.sports_bar_rounded, '6–10 months'),
  MilestoneIdea('Crawled', Icons.child_care_rounded, '7–10 months'),
  MilestoneIdea('Waved bye-bye', Icons.waving_hand_rounded, '8–10 months'),
  MilestoneIdea('Clapped hands', Icons.front_hand_rounded, '8–10 months'),
  MilestoneIdea('Said "mama"', Icons.chat_bubble_rounded, '8–12 months'),
  MilestoneIdea('Said "dada"', Icons.chat_rounded, '8–12 months'),
  MilestoneIdea('Pulled to stand', Icons.accessibility_new_rounded, '9–12 months'),
  MilestoneIdea('First drink from a cup', Icons.coffee_rounded, '9–12 months'),
  MilestoneIdea('Gave a kiss', Icons.favorite_rounded, '10–14 months'),
  MilestoneIdea('First word', Icons.forum_rounded, '10–14 months'),
  MilestoneIdea('Stood alone', Icons.man_rounded, '10–14 months'),
  MilestoneIdea('First steps', Icons.directions_walk_rounded, '9–15 months'),
  MilestoneIdea('Fed self with a spoon', Icons.soup_kitchen_rounded, '12–18 months'),
  MilestoneIdea('First dance', Icons.nightlife_rounded, 'any time'),
  MilestoneIdea('First haircut', Icons.content_cut_rounded, 'any time'),
  MilestoneIdea('First swim', Icons.pool_rounded, 'any time'),
  MilestoneIdea('First snow', Icons.ac_unit_rounded, 'any time'),
  MilestoneIdea('First day at daycare', Icons.school_rounded, 'any time'),
  MilestoneIdea('First tooth', Icons.auto_awesome_rounded, '6–10 months', BookChapter.growing),
  MilestoneIdea('Up a diaper size', Icons.baby_changing_station_rounded, 'now and then', BookChapter.growing, true),
  MilestoneIdea('Up a clothes size', Icons.checkroom_rounded, 'now and then', BookChapter.growing, true),
  MilestoneIdea('Outgrew the bassinet', Icons.crib_rounded, '3–6 months', BookChapter.growing),
  MilestoneIdea('Own room', Icons.bedroom_baby_rounded, 'any time', BookChapter.growing),
  MilestoneIdea('Forward-facing car seat', Icons.directions_car_rounded, 'after 2 years', BookChapter.growing),
  MilestoneIdea('First shoes', Icons.directions_run_rounded, 'first steps', BookChapter.growing),
  MilestoneIdea('First Christmas', Icons.park_rounded, 'December', BookChapter.celebrations),
  MilestoneIdea('First Halloween', Icons.dark_mode_rounded, 'October', BookChapter.celebrations),
  MilestoneIdea('First Easter', Icons.egg_rounded, 'spring', BookChapter.celebrations),
  MilestoneIdea("First Mother's Day", Icons.local_florist_rounded, 'May', BookChapter.celebrations),
  MilestoneIdea("First Father's Day", Icons.redeem_rounded, 'June', BookChapter.celebrations),
  MilestoneIdea('Baptism or naming day', Icons.water_drop_rounded, 'any time', BookChapter.celebrations),
  MilestoneIdea('First trip', Icons.luggage_rounded, 'any time', BookChapter.celebrations),
  MilestoneIdea('First birthday', Icons.cake_rounded, '1 year', BookChapter.celebrations),
];

String _key(String name) => name.trim().toLowerCase();

MilestoneIdea? ideaFor(String? name) => name == null ? null : milestoneIdeas.where((i) => _key(i.name) == _key(name)).firstOrNull;

/// The monthly photo next to a banana, to see how much they grew: any number of these, shown as
/// a strip in Growing up rather than as memories.
const bananaName = 'Banana for scale';

bool isBanana(Event e) => _key((e['name'] as String?) ?? '') == _key(bananaName);

/// The chapter a memory goes in when none was picked: its idea's, Waiting for you before the
/// [birth] day, else Firsts.
BookChapter autoChapter(String? name, {DateTime? at, DateTime? birth}) {
  final idea = ideaFor(name);
  if (idea != null) return idea.chapter;
  if (name != null && _key(name) == _key(bananaName)) return BookChapter.growing;
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

  Set<String> get loggedKeys => {for (final e in memories ?? const <Event>[]) _key((e['name'] as String?) ?? '')};
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
    final list = memories?.where((e) => e['tooth'] == null || _key((e['name'] as String?) ?? '') == 'first tooth').toList();
    final byChapter = {for (final c in BookChapter.values) c: <Event>[]};
    final bananas = <Event>[];
    for (final e in list ?? const <Event>[]) {
      (isBanana(e) ? bananas : byChapter[chapterOf(e, birth: child.birthDate)]!).add(e);
    }
    final logged = loggedKeys;
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
      final left = milestoneIdeas.where((i) => i.chapter == chapter && (i.repeats || !logged.contains(_key(i.name)))).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            chapter == BookChapter.firsts ? 'Ideas to remember' : 'Ideas for this chapter',
            trailing: seeAll ? TextButton(onPressed: () => _showAllIdeas(context), child: const Text('See all')) : null,
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
                      name: 'Your own',
                      icon: Icons.add_rounded,
                      when: 'anything special',
                      onTap: () => showMemoryForm(context, chapter: chapter),
                    )
                  : _IdeaSticker(
                      name: left[i - 1].name,
                      icon: left[i - 1].icon,
                      when: left[i - 1].when,
                      onTap: () => showMemoryForm(context, name: left[i - 1].name),
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
        'Teeth',
        trailing: Text('as you look at ${child.name}', style: TextStyle(color: context.pal.muted, fontSize: 13)),
      ),
      TeethChart(child: child, milestones: memories ?? const []),
      if (!readOnly || bananas.isNotEmpty) ...[
        SectionTitle('Banana for scale 🍌', trailing: Text('a photo a month', style: TextStyle(color: context.pal.muted, fontSize: 13))),
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
      appBar: AppBar(title: Text('${child.name}’s book'), automaticallyImplyLeading: !widget.asTab, actions: [if (readOnly) const BookViewerActions()]),
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
      final byKey = {for (final e in memories ?? const <Event>[]) _key((e['name'] as String?) ?? ''): e};
      final done = milestoneIdeas.where((i) => byKey.containsKey(_key(i.name))).length;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text('Ideas to remember', style: serifStyle(24)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text('$done of ${milestoneIdeas.length} in the book. Tap one to add it.', style: TextStyle(color: c.muted)),
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
                        final e = byKey[_key(idea.name)];
                        return ListTile(
                          leading: BlobIcon(Kind.milestone, size: 40, icon: idea.icon),
                          title: Text(idea.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(e == null ? idea.when : DateFormat.yMMMd().format(e.start)),
                          trailing: e == null
                              ? Icon(Icons.add_circle_outline_rounded, color: c.accent)
                              : Icon(Icons.check_circle_rounded, color: Kind.milestone.on(c)),
                          onTap: () {
                            Navigator.pop(sheet);
                            showMemoryForm(context, event: e, name: idea.name);
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
      helpText: 'Due date',
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
                label: Text('Due ${due == null ? '' : DateFormat.yMMMMd().format(due)}'),
              )
            : ActionChip(
                avatar: Icon(Icons.event_rounded, size: 18, color: Kind.milestone.on(c)),
                label: Text(due == null ? 'Set the due date' : 'Due ${DateFormat.yMMMMd().format(due)}'),
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
            'The same banana next to ${child.name} every month: the best way to see how fast it goes.',
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
                      onTap: () => showMemoryForm(context, name: bananaName),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_rounded, size: 32, color: k.on(c)),
                          const SizedBox(height: 10),
                          Text(
                            photos.isEmpty ? 'Take the first one' : 'This month’s',
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
                                  : Image.memory(bytes, fit: BoxFit.cover, cacheWidth: 300, gaplessPlayback: true, semanticLabel: 'Banana for scale'),
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
                  'CHAPTER ${chapter.index + 1}',
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
  if (day.isBefore(b)) return 'Before birth';
  var months = (day.year - b.year) * 12 + day.month - b.month;
  if (day.day < b.day) months--;
  if (months < 1) return 'Newborn';
  if (months < 24) return '$months month${months == 1 ? '' : 's'}';
  return '${months ~/ 12} years';
}

/// "Saturday 12 July 2026 · 6 weeks old".
String _dateLine(Child child, DateTime day) {
  final born = child.birthDate;
  final age = born == null || day.isBefore(born) ? null : '${child.ageAt(day)} old';
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
    if (weeks >= 1 && weeks <= 44) return '$weeks week${weeks == 1 ? '' : 's'} along';
  }
  final before = born.difference(d).inDays ~/ 7;
  return before == 0 ? 'days before birth' : '$before week${before == 1 ? '' : 's'} before birth';
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
                              'The book of',
                              style: TextStyle(color: c.bandInk.withValues(alpha: 0.75), fontWeight: FontWeight.w600),
                            ),
                            Text(child.name, style: serifStyle(32, color: c.bandInk)),
                            if (born != null) Text('Born ${DateFormat.yMMMMd().format(born)}', style: TextStyle(color: c.bandInk.withValues(alpha: 0.8))),
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
                              ? 'No memories yet'
                              : '${memories.length} ${memories.length == 1 ? 'memory' : 'memories'} · $photos photo${photos == 1 ? '' : 's'}',
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
                          label: const Text('Add a memory'),
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
        if (babies > 1) IconButton(tooltip: 'Switch baby', icon: const Icon(Icons.swap_horiz_rounded), onPressed: () => showChildSwitcher(context)),
        IconButton(
          tooltip: 'Settings',
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
        Text('The first page is waiting', style: serifStyle(22), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
          readOnly ? 'Memories show here as the family adds them.' : 'Pick an idea below or add your own: a photo, the day and a few words about it.',
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
    final name = (event['name'] as String?) ?? 'Milestone';
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
                              semanticLabel: 'Photo: $name',
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
          child: Center(child: Image.memory(bytes, semanticLabel: 'Photo: $name')),
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
  late final _name = TextEditingController(text: e?['name'] ?? widget.name ?? '');
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
    if (name.isEmpty) return showMessage(context, 'What happened? Give the memory a name.');
    setState(() => _busy = true);
    final s = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final note = _note.text.trim();
    final tooth = _key(name) == 'first tooth' || e?['tooth'] != null ? _tooth : null;
    // Always saved, so a renamed memory (or a later list of ideas) never moves it.
    final chapter = _chapterNow(s).id;
    final body = {'type': 'milestone', 'name': name, 'start': formatTime(_start), 'note': note.isEmpty ? null : note, 'tooth': tooth, 'chapter': chapter};
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
      problem = 'The memory is saved, but not its photo: ${err is ApiException ? err.message : err}';
    }
    if (!mounted) return;
    Navigator.pop(context);
    if (problem != null) messenger.showSnackBar(SnackBar(content: Text(problem)));
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Delete this memory?', 'It will be removed for everyone in the family, with its photo.')) return;
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
    final typed = _key(_name.text), logged = loggedKeys;
    final open = milestoneIdeas.where((i) => (i.repeats || !logged.contains(_key(i.name))) && (typed.isEmpty ? i.chapter == chapter : _key(i.name).contains(typed)));
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
                    Expanded(child: Text(e == null ? 'New memory' : 'Edit memory', style: serifStyle(24))),
                    if (e != null) IconButton(onPressed: _delete, tooltip: 'Delete', icon: const Icon(Icons.delete_outline_rounded), color: c.danger),
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
                      label: 'Chapter',
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
                      label: 'What happened?',
                      below: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _name,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(hintText: 'First smile, rolled over…'),
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
                                    label: Text(i.name),
                                    onPressed: () => setState(() {
                                      _chapter = i.chapter;
                                      _name.text = i.name;
                                    }),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_key(_name.text) == 'first tooth' || e?['tooth'] != null)
                      FormRow(
                        label: 'Which tooth?',
                        child: DropdownButton<String?>(
                          value: _tooth,
                          isDense: true,
                          isExpanded: true,
                          underline: const SizedBox(),
                          hint: const Text('Choose'),
                          items: [for (final t in babyTeeth) DropdownMenuItem(value: t.code, child: Text(t.name))],
                          onChanged: (v) => setState(() => _tooth = v),
                        ),
                      ),
                    FormRow(
                      label: 'When',
                      child: DateTimeValue(value: _start, onChanged: (v) => setState(() => _start = v)),
                    ),
                    FormRow(
                      label: 'The story',
                      below: TextField(
                        controller: _note,
                        maxLines: null,
                        minLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(hintText: 'Where you were, who was there, how it felt…'),
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
                    child: Text(_busy ? 'Saving…' : (e == null ? 'Save to the book' : 'Save changes')),
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
                _preparing ? 'Preparing the photo…' : 'Add a photo',
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
              _photoButton(Icons.photo_library_rounded, 'Change', _preparing ? null : _choosePhoto),
              const SizedBox(width: 8),
              _photoButton(
                Icons.delete_outline_rounded,
                'Remove',
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
