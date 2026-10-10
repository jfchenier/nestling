import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// The baby book's own pages: the day they were born, their name, the world they were born into,
/// and growth month by month. The texts are kept on the child (`book`), the measurements come
/// from the Growth entries.

/// The moon on a day: its phase name and how lit it is (0 new … 1 full), from the mean synodic
/// month counted from the new moon of 6 January 2000, 18:14 UTC (good to about a day).
({String name, double lit, double age}) moonPhase(DateTime when) {
  const month = 29.530588853;
  final ref = DateTime.utc(2000, 1, 6, 18, 14);
  final days = when.toUtc().difference(ref).inMinutes / 1440;
  final age = (days % month + month) % month;
  final names = [
    l10n.pagesMoonNew,
    l10n.pagesMoonWaxingCrescent,
    l10n.pagesMoonFirstQuarter,
    l10n.pagesMoonWaxingGibbous,
    l10n.pagesMoonFull,
    l10n.pagesMoonWaningGibbous,
    l10n.pagesMoonLastQuarter,
    l10n.pagesMoonWaningCrescent,
  ];
  final name = names[((age / month) * 8 + 0.5).floor() % 8];
  return (name: name, lit: (1 - math.cos(2 * math.pi * age / month)) / 2, age: age);
}

/// When the baby was born, as a local time (noon without a `birth_time`), or null without a
/// birth date.
DateTime? bornAt(Child child) {
  final d = child.birthDate;
  if (d == null) return null;
  final t = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(child.book['birth_time'] ?? '');
  return DateTime(
    d.year,
    d.month,
    d.day,
    t == null ? 12 : int.parse(t.group(1)!),
    t == null ? 0 : int.parse(t.group(2)!),
  );
}

/// The measurement closest to each month of age (within half a month), one row per month with
/// any: `(months, weight_g, length_cm, head_cm)`. Month 0 is birth.
List<(int, num?, num?, num?)> growthByMonth(Child child, List<Event> growth) {
  final b = child.birthDate;
  if (b == null || growth.isEmpty) return const [];
  final last = growth.map((e) => e.start).reduce((a, c) => a.isAfter(c) ? a : c);
  final rows = <(int, num?, num?, num?)>[];
  for (var m = 0; m <= 36; m++) {
    final at = DateTime(b.year, b.month + m, b.day);
    if (at.isAfter(last.add(const Duration(days: 16)))) break;
    num? pick(String field) {
      Event? best;
      for (final e in growth) {
        if (e[field] is! num) continue;
        final off = e.start.difference(at).inHours.abs();
        if (off > 15 * 24 || (best != null && off >= best.start.difference(at).inHours.abs())) continue;
        best = e;
      }
      return best?[field] as num?;
    }

    final row = (m, pick('weight_g'), pick('length_cm'), pick('head_cm'));
    if (row.$2 != null || row.$3 != null || row.$4 != null) rows.add(row);
  }
  return rows;
}

/// A sheet of paper taped into the book: the pages' look, like the memories' prints.
class TapedPaper extends StatelessWidget {
  const TapedPaper({super.key, required this.child, this.onTap, this.tilt = 0.006, this.semanticLabel});
  final Widget child;
  final VoidCallback? onTap;
  final double tilt;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final k = Kind.milestone;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 16, 6, 14),
      child: Transform.rotate(
        angle: tilt,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Semantics(
              button: onTap != null,
              label: semanticLabel,
              child: Material(
                color: c.surface,
                elevation: 1.5,
                shadowColor: c.ink.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: onTap,
                  child: Padding(padding: const EdgeInsets.fromLTRB(18, 20, 18, 18), child: child),
                ),
              ),
            ),
            Positioned(
              top: -11,
              left: 24,
              child: Transform.rotate(
                angle: -0.08,
                child: Container(width: 70, height: 22, color: k.fill(c).withValues(alpha: c.isDark ? 0.85 : 0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A page's heading: its icon, title, a line under it and the pencil that says it can be edited.
class _PageHead extends StatelessWidget {
  const _PageHead(this.title, this.icon, {this.subtitle});
  final String title;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          BlobIcon(Kind.milestone, size: 40, icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: serifStyle(21)),
                if (subtitle != null) Text(subtitle!, style: TextStyle(color: c.muted, fontSize: 13.5)),
              ],
            ),
          ),
          if (!context.select<AppState, bool>((s) => s.bookOnly)) Icon(Icons.edit_rounded, size: 18, color: c.muted),
        ],
      ),
    );
  }
}

/// "Weighed   3.4 kg" on a page.
class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.icon});
  final String label, value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(label, style: TextStyle(color: c.muted, fontSize: 14)),
          ),
          if (icon != null) ...[Icon(icon, size: 18, color: Kind.milestone.on(c)), const SizedBox(width: 6)],
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.3)),
          ),
        ],
      ),
    );
  }
}

/// A heading and its text, for the longer answers ("Why we chose it").
class _Block extends StatelessWidget {
  const _Block(this.label, this.text);
  final String label, text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.pal.muted, fontSize: 14)),
        const SizedBox(height: 2),
        Text(
          text,
          style: TextStyle(color: context.pal.ink, fontSize: 15.5, height: 1.4, fontStyle: FontStyle.italic),
        ),
      ],
    ),
  );
}

class _Prompt extends StatelessWidget {
  const _Prompt(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      text,
      style: TextStyle(color: Kind.milestone.on(context.pal), fontWeight: FontWeight.w600),
    ),
  );
}

/// "The day you were born": date and weekday, time, place, birth measurements (the first Growth
/// entry), hair, eyes, the moon that night, and a note.
class BornPage extends StatelessWidget {
  const BornPage({super.key, required this.child, required this.growth});
  final Child child;
  final List<Event> growth;

  @override
  Widget build(BuildContext context) {
    final units = context.watch<AppState>().units;
    final book = child.book;
    final born = bornAt(child);
    final rows = growthByMonth(child, growth);
    final first = rows.isNotEmpty && rows.first.$1 == 0 ? rows.first : null;
    final moon = born == null ? null : moonPhase(born);
    final readOnly = context.select<AppState, bool>((s) => s.bookOnly);
    final filled = readOnly || book.keys.any((k) => const ['birth_time', 'birth_place', 'hair', 'eyes', 'birth_note'].contains(k));
    return TapedPaper(
      tilt: -0.008,
      semanticLabel: readOnly ? l10n.pagesBornTitle : l10n.pagesTapToEdit(l10n.pagesBornTitle),
      onTap: readOnly ? null : () => editBornPage(context, child),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHead(l10n.pagesBornTitle, Icons.child_friendly_rounded, subtitle: born == null ? null : capFirst(DateFormat.EEEE().format(born))),
          if (born != null) _Line(l10n.pagesBorn, DateFormat.yMMMMd().format(born)),
          if (book['birth_time'] case final t?) _Line(l10n.pagesAt, t),
          if (book['birth_place'] case final p?) _Line(l10n.pagesWhere, p),
          if (first?.$2 case final w?) _Line(l10n.pagesWeighed, units.weight(w)),
          if (first?.$3 case final l?) _Line(l10n.pagesMeasured, units.length(l)),
          if (book['hair'] case final h?) _Line(l10n.pagesHair, h),
          if (book['eyes'] case final e?) _Line(l10n.pagesEyes, e),
          if (moon != null) _Line(l10n.pagesMoon, moon.name, icon: moon.lit > 0.5 ? Icons.circle : Icons.dark_mode_rounded),
          if (book['birth_note'] case final n?) _Block(l10n.pagesWeRemember, n),
          if (born == null && !readOnly) _Prompt(l10n.pagesBornNoDate),
          if (!filled) _Prompt(l10n.pagesBornPrompt),
          if (first == null && born != null && !readOnly)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l10n.pagesBirthGrowthHint, style: TextStyle(color: context.pal.muted, fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

/// "Your name": full name, what it means, why we chose it, other names we considered, nicknames.
class NamePage extends StatelessWidget {
  const NamePage({super.key, required this.child});
  final Child child;

  @override
  Widget build(BuildContext context) {
    final book = child.book;
    final readOnly = context.select<AppState, bool>((s) => s.bookOnly);
    final filled = readOnly || book.keys.any((k) => k.startsWith('name_') || k == 'full_name');
    return TapedPaper(
      tilt: 0.007,
      semanticLabel: readOnly ? l10n.pagesNameTitle : l10n.pagesTapToEdit(l10n.pagesNameTitle),
      onTap: readOnly ? null : () => editNamePage(context, child),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHead(l10n.pagesNameTitle, Icons.badge_rounded),
          Text(book['full_name'] ?? child.name, style: serifStyle(26, color: Kind.milestone.on(context.pal))),
          if (book['name_meaning'] case final m?) _Block(l10n.pagesNameMeaning, m),
          if (book['name_why'] case final w?) _Block(l10n.pagesNameWhy, w),
          if (book['name_others'] case final o?) _Block(l10n.pagesNameOthers, o),
          if (book['name_nicknames'] case final n?) _Block(l10n.pagesNicknames, n),
          if (!filled) _Prompt(l10n.pagesNamePrompt),
        ],
      ),
    );
  }
}

/// The world page's texts: key (saved in the book), label, hint.
List<(String, String, String)> get worldTopics => [
  ('world_headlines', l10n.pagesWorldNews, l10n.pagesWorldNewsHint),
  ('world_leaders', l10n.pagesWorldLeaders, l10n.pagesWorldLeadersHint),
  ('world_songs', l10n.pagesWorldSongs, l10n.pagesWorldSongsHint),
  ('world_movies', l10n.pagesWorldMovies, l10n.pagesWorldMoviesHint),
  ('world_shows', l10n.pagesWorldShows, l10n.pagesWorldShowsHint),
  ('world_people', l10n.pagesWorldPeople, l10n.pagesWorldPeopleHint),
  ('world_tech', l10n.pagesWorldTech, l10n.pagesWorldTechHint),
];

/// What things cost: key (saved in the book), label.
List<(String, String)> get worldPrices => [
  ('price_coffee', l10n.pagesPriceCoffee),
  ('price_milk', l10n.pagesPriceMilk),
  ('price_bread', l10n.pagesPriceBread),
  ('price_gas', l10n.pagesPriceGas),
  ('price_diapers', l10n.pagesPriceDiapers),
  ('price_movie', l10n.pagesPriceMovie),
  ('price_rent', l10n.pagesPriceRent),
  ('price_house', l10n.pagesPriceHouse),
  ('price_car', l10n.pagesPriceCar),
];

/// "The world you were born into": news, culture and prices, typed by the family (the app
/// doesn't look them up). Only what's filled in shows.
class WorldPage extends StatelessWidget {
  const WorldPage({super.key, required this.child});
  final Child child;

  /// Anything was written on it (book viewers don't see it empty).
  static bool hasText(Child child) => child.book.keys.any((k) => k.startsWith('world_') || k.startsWith('price_'));

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final book = child.book;
    final born = child.birthDate;
    final topics = [
      for (final (k, label, _) in worldTopics)
        if (book[k] case final v?) (label, v),
    ];
    final prices = [
      for (final (k, label) in worldPrices)
        if (book[k] case final v?) (label, v),
    ];
    final readOnly = context.select<AppState, bool>((s) => s.bookOnly);
    return TapedPaper(
      tilt: -0.006,
      semanticLabel: readOnly ? l10n.pagesWorldTitle : l10n.pagesTapToEdit(l10n.pagesWorldTitle),
      onTap: readOnly ? null : () => editWorldPage(context, child),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHead(
            l10n.pagesWorldTitle,
            Icons.public_rounded,
            subtitle: born == null ? null : capFirst(DateFormat.yMMMM().format(born)),
          ),
          for (final (label, v) in topics) _Block(label, v),
          if (prices.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(l10n.pagesWhatThingsCost, style: TextStyle(color: c.muted, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, v) in prices)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Kind.milestone.fill(c).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, style: TextStyle(color: c.muted, fontSize: 12)),
                        Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          if (book['world_note'] case final n?) _Block(l10n.pagesAndAlso, n),
          if (topics.isEmpty && prices.isEmpty && book['world_note'] == null) _Prompt(l10n.pagesWorldPrompt),
        ],
      ),
    );
  }
}

/// Weight, length and head size at each month, from the Growth entries.
class GrowthPage extends StatelessWidget {
  const GrowthPage({super.key, required this.child, required this.growth});
  final Child child;
  final List<Event> growth;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final units = context.watch<AppState>().units;
    final rows = growthByMonth(child, growth);
    final head = rows.any((r) => r.$4 != null);
    TextStyle cell([bool bold = false]) => TextStyle(
      fontSize: 14.5,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      color: bold ? Kind.milestone.on(c) : c.ink,
    );
    return TapedPaper(
      tilt: 0.006,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const BlobIcon(Kind.growth, size: 40, icon: Icons.straighten_rounded),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.pagesMonthByMonth, style: serifStyle(21))),
              ],
            ),
          ),
          if (rows.isEmpty)
            Text(
              child.birthDate == null ? l10n.pagesGrowthNoBirth : l10n.pagesGrowthEmpty,
              style: TextStyle(color: c.muted),
            )
          else
            Table(
              columnWidths: {
                0: const FlexColumnWidth(1.1),
                1: const FlexColumnWidth(1.2),
                2: const FlexColumnWidth(1),
                if (head) 3: const FlexColumnWidth(1),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.line)),
                  ),
                  children: [
                    for (final h in [l10n.pagesAge, l10n.pagesWeight, l10n.pagesLength, if (head) l10n.pagesHead])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(h, style: TextStyle(color: c.muted, fontSize: 13)),
                      ),
                  ],
                ),
                for (final (m, w, l, hc) in rows)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Text(m == 0 ? l10n.pagesBirth : l10n.pagesMonthsShort(m), style: cell(true)),
                      ),
                      Text(w == null ? '–' : units.weight(w), style: cell()),
                      Text(l == null ? '–' : units.length(l), style: cell()),
                      if (head) Text(hc == null ? '–' : units.length(hc), style: cell()),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---- editing ----

/// One field of a page's form: key in the book, label, hint, several lines or not.
typedef _Field = ({String key, String label, String hint, bool long});

Future<void> editBornPage(BuildContext context, Child child) => _editPage(
  context,
  child,
  title: l10n.pagesBornTitle,
  icon: Icons.child_friendly_rounded,
  time: true,
  fields: [
    (key: 'birth_place', label: l10n.pagesWhere, hint: l10n.pagesHintPlace, long: false),
    (key: 'hair', label: l10n.pagesHair, hint: l10n.pagesHintHair, long: false),
    (key: 'eyes', label: l10n.pagesEyes, hint: l10n.pagesHintEyes, long: false),
    (key: 'birth_note', label: l10n.pagesWeRemember, hint: l10n.pagesHintRemember, long: true),
  ],
);

Future<void> editNamePage(BuildContext context, Child child) => _editPage(
  context,
  child,
  title: l10n.pagesNameTitle,
  icon: Icons.badge_rounded,
  fields: [
    (key: 'full_name', label: l10n.pagesFullName, hint: child.name, long: false),
    (key: 'name_meaning', label: l10n.pagesNameMeaning, hint: l10n.pagesHintMeaning, long: true),
    (key: 'name_why', label: l10n.pagesNameWhy, hint: l10n.pagesHintWhy, long: true),
    (key: 'name_others', label: l10n.pagesNameOthers, hint: l10n.pagesHintOthers, long: true),
    (key: 'name_nicknames', label: l10n.pagesNicknames, hint: l10n.pagesHintNicknames, long: false),
  ],
);

Future<void> editWorldPage(BuildContext context, Child child) => _editPage(
  context,
  child,
  title: l10n.pagesWorldTitle,
  icon: Icons.public_rounded,
  fields: [
    for (final (k, label, hint) in worldTopics) (key: k, label: label, hint: hint, long: true),
    for (final (k, label) in worldPrices) (key: k, label: label, hint: l10n.pagesPriceHint, long: false),
    (key: 'world_note', label: l10n.pagesAndAlso, hint: l10n.pagesHintWorldNote, long: true),
  ],
);

Future<void> _editPage(
  BuildContext context,
  Child child, {
  required String title,
  required IconData icon,
  required List<_Field> fields,
  bool time = false,
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: context.pal.background,
  builder: (_) => _PageForm(child: child, title: title, icon: icon, fields: fields, time: time),
);

class _PageForm extends StatefulWidget {
  const _PageForm({
    required this.child,
    required this.title,
    required this.icon,
    required this.fields,
    required this.time,
  });
  final Child child;
  final String title;
  final IconData icon;
  final List<_Field> fields;
  final bool time;

  @override
  State<_PageForm> createState() => _PageFormState();
}

class _PageFormState extends State<_PageForm> {
  late final _text = {
    for (final f in widget.fields) f.key: TextEditingController(text: widget.child.book[f.key] ?? ''),
  };
  late String? _time = widget.child.book['birth_time'];
  bool _busy = false;

  Future<void> _pickTime() async {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(_time ?? '');
    final t = await showTimePicker(
      context: context,
      initialTime: m == null
          ? const TimeOfDay(hour: 12, minute: 0)
          : TimeOfDay(hour: int.parse(m.group(1)!), minute: int.parse(m.group(2)!)),
    );
    if (t != null) {
      setState(() => _time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final s = context.read<AppState>();
    // The whole book is sent: the other pages' texts stay as they are.
    final book = <String, dynamic>{...widget.child.book};
    for (final MapEntry(:key, value: ctl) in _text.entries) {
      book[key] = ctl.text.trim();
    }
    if (widget.time) book['birth_time'] = _time;
    book.removeWhere((_, v) => v == null || (v is String && v.isEmpty));
    final ok = await guard(
      context,
      () => s.act((api) => api.patch('/children/${widget.child.id}', {'book': book}), families: true).then((_) => true),
    );
    if (!mounted) return;
    if (ok == true) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final k = Kind.milestone;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92, maxWidth: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                children: [
                  BlobIcon(k, size: 46, icon: widget.icon),
                  const SizedBox(width: 14),
                  Expanded(child: Text(widget.title, style: serifStyle(22))),
                ],
              ),
            ),
            Divider(height: 1, color: c.line),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (widget.time)
                    FormRow(
                      label: l10n.pagesTimeOfBirth,
                      onTap: _pickTime,
                      child: Text(
                        _time ?? l10n.pagesSetTime,
                        style: TextStyle(fontWeight: FontWeight.w600, color: _time == null ? c.accent : c.ink),
                      ),
                    ),
                  for (final f in widget.fields)
                    FormRow(
                      label: f.label,
                      below: TextField(
                        controller: _text[f.key],
                        maxLines: f.long ? null : 1,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(hintText: f.hint),
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
                  onPressed: _busy ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: c.isDark ? k.fill(c) : k.deepTone,
                    foregroundColor: c.onAccent,
                  ),
                  child: Text(_busy ? l10n.pagesSaving : l10n.pagesSaveToBook),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final t in _text.values) {
      t.dispose();
    }
    super.dispose();
  }
}
