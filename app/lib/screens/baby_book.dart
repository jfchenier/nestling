import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/date_time.dart';
import '../widgets/photo.dart';
import 'home.dart' show ChildAvatar;
import 'teeth_chart.dart';

/// A first worth remembering, offered in the baby book and the memory form.
class MilestoneIdea {
  const MilestoneIdea(this.name, this.icon, this.when);
  final String name;
  final IconData icon;

  /// Roughly when it happens, as a hint.
  final String when;
}

/// Ideas for the baby book, in about the order they come. Any other name works too.
const milestoneIdeas = [
  MilestoneIdea('Came home', Icons.home_rounded, 'first days'),
  MilestoneIdea('First bath', Icons.bathtub_rounded, 'first weeks'),
  MilestoneIdea('Met the grandparents', Icons.diversity_1_rounded, 'first weeks'),
  MilestoneIdea('First walk outside', Icons.park_rounded, 'first weeks'),
  MilestoneIdea('First smile', Icons.sentiment_very_satisfied_rounded, 'around 6 weeks'),
  MilestoneIdea('Held head up', Icons.face_rounded, '2–4 months'),
  MilestoneIdea('First laugh', Icons.emoji_emotions_rounded, '3–4 months'),
  MilestoneIdea('Rolled over', Icons.sync_rounded, '4–6 months'),
  MilestoneIdea('Slept through the night', Icons.nights_stay_rounded, 'any time'),
  MilestoneIdea('First solid food', Icons.restaurant_rounded, 'around 6 months'),
  MilestoneIdea('Sat up alone', Icons.event_seat_rounded, '6–8 months'),
  MilestoneIdea('First tooth', Icons.auto_awesome_rounded, '6–10 months'),
  MilestoneIdea('Crawled', Icons.child_care_rounded, '7–10 months'),
  MilestoneIdea('Waved bye-bye', Icons.waving_hand_rounded, '8–10 months'),
  MilestoneIdea('Clapped hands', Icons.front_hand_rounded, '8–10 months'),
  MilestoneIdea('Pulled to stand', Icons.accessibility_new_rounded, '9–12 months'),
  MilestoneIdea('First word', Icons.record_voice_over_rounded, '10–14 months'),
  MilestoneIdea('First steps', Icons.directions_walk_rounded, '9–15 months'),
  MilestoneIdea('First birthday', Icons.cake_rounded, '1 year'),
  MilestoneIdea('First haircut', Icons.content_cut_rounded, 'any time'),
  MilestoneIdea('First swim', Icons.pool_rounded, 'any time'),
  MilestoneIdea('First trip', Icons.luggage_rounded, 'any time'),
  MilestoneIdea('First snow', Icons.ac_unit_rounded, 'any time'),
  MilestoneIdea('First day at daycare', Icons.school_rounded, 'any time'),
];

String _key(String name) => name.trim().toLowerCase();

MilestoneIdea? ideaFor(String? name) => name == null ? null : milestoneIdeas.where((i) => _key(i.name) == _key(name)).firstOrNull;

/// The selected child's memories (milestones), oldest first, reloaded whenever data changes.
mixin _Memories<T extends StatefulWidget> on State<T> {
  List<Event>? memories;
  (String?, int)? _loadedFor;

  void watchMemories(AppState s) {
    final key = (s.childId, s.revision);
    if (_loadedFor == key) return;
    _loadedFor = key;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (s.childId == null || s.api == null) return;
      final res = await guard(context, () => s.api!.get('/children/${s.childId}/events', {'type': 'milestone', 'limit': '1000'}));
      if (!mounted || res == null) return;
      setState(() => memories = [for (final e in res['events'] as List) Event(e)]..sort((a, b) => a.start.compareTo(b.start)));
    });
  }

  Set<String> get loggedKeys => {for (final e in memories ?? const <Event>[]) _key((e['name'] as String?) ?? '')};
}

/// The baby book: the child's firsts as a scrapbook (photo, story, age), grouped by age, with
/// ideas of firsts still to come. Tap a memory to edit it, its photo to see it big.
class BabyBookScreen extends StatefulWidget {
  const BabyBookScreen({super.key, this.addMemory = false});

  /// Opens "New memory" over the book right away (the Firsts card), so closing it shows the book.
  final bool addMemory;

  @override
  State<BabyBookScreen> createState() => _BabyBookScreenState();
}

class _BabyBookScreenState extends State<BabyBookScreen> with _Memories {
  @override
  void initState() {
    super.initState();
    if (widget.addMemory) WidgetsBinding.instance.addPostFrameCallback((_) => showMemoryForm(context));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final child = s.child;
    watchMemories(s);
    if (child == null) return const Scaffold();
    // Teeth are on the chart; only the first one is a memory of its own.
    final list = memories?.where((e) => e['tooth'] == null || _key((e['name'] as String?) ?? '') == 'first tooth').toList();
    final logged = loggedKeys;
    final ideas = milestoneIdeas.where((i) => !logged.contains(_key(i.name))).toList();

    final rows = <Widget>[
      _Cover(child: child, memories: list ?? const []),
      SectionTitle(
        'Ideas to remember',
        trailing: TextButton(onPressed: () => _showAllIdeas(context), child: const Text('See all')),
      ),
      SizedBox(
        height: 128,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: ideas.length + 1,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) => i == 0
              ? _IdeaSticker(name: 'Your own', icon: Icons.add_rounded, when: 'anything special', onTap: () => showMemoryForm(context))
              : _IdeaSticker(
                  name: ideas[i - 1].name,
                  icon: ideas[i - 1].icon,
                  when: ideas[i - 1].when,
                  onTap: () => showMemoryForm(context, name: ideas[i - 1].name),
                ),
        ),
      ),
    ];
    rows.addAll([
      SectionTitle('Teeth', trailing: Text('as you look at ${child.name}', style: TextStyle(color: context.pal.muted, fontSize: 13))),
      TeethChart(child: child, milestones: memories ?? const []),
    ]);
    if (list == null) {
      rows.add(
        const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    } else if (list.isEmpty) {
      rows.add(const _EmptyBook());
    } else {
      String? chapter;
      var i = 0;
      for (final e in list) {
        final c = _chapter(child, e.start);
        if (c != chapter) {
          chapter = c;
          rows.add(_ChapterTitle(c));
        }
        rows.add(_MemoryCard(event: e, child: child, index: i++));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text('${child.name}’s book')),
      body: Constrained(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 48), children: rows),
      ),
    );
  }

  /// Every idea, ticked when it's in the book.
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
              child: Text('Firsts to remember', style: serifStyle(24)),
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
                  for (final idea in milestoneIdeas)
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
  final age = child.birthDate == null || day.isBefore(child.birthDate!) ? null : child.ageAt(day);
  return [DateFormat.yMMMMEEEEd().format(day), if (age != null) '$age old'].join(' · ');
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
  const _EmptyBook();

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
          'Pick an idea above or add your own: a photo, the day and a few words about it.',
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
        onTap: () => showMemoryForm(context, event: event),
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
                          Text(tooth.name, style: TextStyle(color: k.on(c), fontSize: 13.5, fontWeight: FontWeight.w600)),
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

/// Add a memory (optionally starting from an idea's [name]) or edit [event].
Future<void> showMemoryForm(BuildContext context, {Event? event, String? name}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: context.pal.background,
  builder: (_) => MemoryForm(event: event, name: name),
);

class MemoryForm extends StatefulWidget {
  const MemoryForm({super.key, this.event, this.name});
  final Event? event;
  final String? name;

  @override
  State<MemoryForm> createState() => _MemoryFormState();
}

class _MemoryFormState extends State<MemoryForm> with _Memories {
  Event? get e => widget.event;
  late final _name = TextEditingController(text: e?['name'] ?? widget.name ?? '');
  late final _note = TextEditingController(text: e?.note ?? '');
  late DateTime _start = e?.start ?? DateTime.now();
  late String? _tooth = e?['tooth'];
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
    final body = {'type': 'milestone', 'name': name, 'start': formatTime(_start), 'note': note.isEmpty ? null : note, 'tooth': tooth};
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

    // Ideas not in the book yet that match what's typed.
    final typed = _key(_name.text), logged = loggedKeys;
    final suggestions = e != null || idea != null
        ? const <MilestoneIdea>[]
        : milestoneIdeas.where((i) => !logged.contains(_key(i.name)) && _key(i.name).contains(typed)).take(12).toList();

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
                                    onPressed: () => _name.text = i.name,
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
