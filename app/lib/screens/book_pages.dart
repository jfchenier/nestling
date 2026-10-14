import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/photo.dart';
import 'growth_chart.dart';

/// The baby book's own pages: the family tree, the day they were born and its story, their name,
/// the world they were born into, growth month by month and a letter for later. The texts are kept
/// on the child (`book`), the measurements come from the Growth entries.

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

/// The Western zodiac sign of a birthday, as an English id (`libra`); shown with `pagesZodiacSign`.
String zodiacSign(DateTime day) {
  const starts = [
    (1, 20, 'aquarius'),
    (2, 19, 'pisces'),
    (3, 21, 'aries'),
    (4, 20, 'taurus'),
    (5, 21, 'gemini'),
    (6, 21, 'cancer'),
    (7, 23, 'leo'),
    (8, 23, 'virgo'),
    (9, 23, 'libra'),
    (10, 23, 'scorpio'),
    (11, 22, 'sagittarius'),
    (12, 22, 'capricorn'),
  ];
  var sign = 'capricorn';
  for (final (month, from, id) in starts) {
    if (day.month > month || (day.month == month && day.day >= from)) sign = id;
  }
  return sign;
}

const _zodiacSymbols = {
  'aries': '♈',
  'taurus': '♉',
  'gemini': '♊',
  'cancer': '♋',
  'leo': '♌',
  'virgo': '♍',
  'libra': '♎',
  'scorpio': '♏',
  'sagittarius': '♐',
  'capricorn': '♑',
  'aquarius': '♒',
  'pisces': '♓',
};

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
          if (book['birth_time'] case final String t) _Line(l10n.pagesAt, hhmmLabel(t)),
          if (book['birth_place'] case final p?) _Line(l10n.pagesWhere, p),
          if (first?.$2 case final w?) _Line(l10n.pagesWeighed, units.weight(w)),
          if (first?.$3 case final l?) _Line(l10n.pagesMeasured, units.length(l)),
          if (book['hair'] case final h?) _Line(l10n.pagesHair, h),
          if (book['eyes'] case final e?) _Line(l10n.pagesEyes, e),
          if (moon != null) _Line(l10n.pagesMoon, moon.name, icon: moon.lit > 0.5 ? Icons.circle : Icons.dark_mode_rounded),
          if (child.birthDate case final d?) _Line(l10n.pagesZodiac, '${l10n.pagesZodiacSign(zodiacSign(d))} ${_zodiacSymbols[zodiacSign(d)]}'),
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
                if (rows.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GrowthChartScreen())),
                    icon: const Icon(Icons.show_chart_rounded, size: 18),
                    label: Text(l10n.homeChartsShort),
                  ),
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

/// The birth story's texts: key (saved in the book).
const _storyKeys = ['labour_start', 'labour_story', 'birth_people', 'hospital_stay'];

/// "Your birth story": when labour started, how it went, who was there and the time at the
/// hospital (typed, else from the birth date to the "Came home" memory).
class BirthStoryPage extends StatelessWidget {
  const BirthStoryPage({super.key, required this.child, this.cameHome});
  final Child child;

  /// The day of the "Came home" memory, if there is one.
  final DateTime? cameHome;

  static bool hasText(Child child) => child.book.keys.any(_storyKeys.contains);

  /// "3 days" at the hospital, from the birth date to [cameHome].
  static String? hospitalStay(Child child, DateTime? cameHome) {
    final b = child.birthDate;
    if (b == null || cameHome == null) return null;
    final days = DateTime(cameHome.year, cameHome.month, cameHome.day).difference(DateTime(b.year, b.month, b.day)).inDays;
    if (days < 0 || days > 120) return null;
    return days == 0 ? l10n.pagesHospitalSameDay : l10n.pagesHospitalDays(days);
  }

  @override
  Widget build(BuildContext context) {
    final book = child.book;
    final readOnly = context.select<AppState, bool>((s) => s.bookOnly);
    final stay = book['hospital_stay'] ?? hospitalStay(child, cameHome);
    return TapedPaper(
      tilt: 0.006,
      semanticLabel: readOnly ? l10n.pagesStoryTitle : l10n.pagesTapToEdit(l10n.pagesStoryTitle),
      onTap: readOnly ? null : () => editStoryPage(context, child),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHead(l10n.pagesStoryTitle, Icons.local_hospital_rounded),
          if (book['labour_start'] case final v?) _Line(l10n.pagesLabourStarted, v),
          if (book['birth_people'] case final v?) _Line(l10n.pagesBirthPeople, v),
          if (stay != null) _Line(l10n.pagesHospital, stay),
          if (book['labour_story'] case final v?) _Block(l10n.pagesLabourStory, v),
          if (!hasText(child)) _Prompt(l10n.pagesStoryPrompt),
        ],
      ),
    );
  }
}

/// The family tree's names: parents (1, 2), each one's parents, theirs (each in a key of their own;
/// saved before as two lines of one text), brothers and sisters, aunts, uncles and cousins.
const _treeKeys = [
  'tree_parent_1',
  'tree_parent_2',
  'tree_gp_1a',
  'tree_gp_1b',
  'tree_gp_2a',
  'tree_gp_2b',
  'tree_ggp_1a',
  'tree_ggp_1b',
  'tree_ggp_2a',
  'tree_ggp_2b',
  'tree_ggp_1a_1',
  'tree_ggp_1a_2',
  'tree_ggp_1b_1',
  'tree_ggp_1b_2',
  'tree_ggp_2a_1',
  'tree_ggp_2a_2',
  'tree_ggp_2b_1',
  'tree_ggp_2b_2',
  'tree_siblings',
  'tree_others',
];

/// A grandparent's parents: each name in a key of its own (`tree_ggp_1a_1`, `tree_ggp_1a_2`), or,
/// as saved before, both in one text, one per line (`tree_ggp_1a`); null where a name is missing.
List<String?> _couple(Map<String, dynamic> book, String key) {
  if (book.containsKey('${key}_1') || book.containsKey('${key}_2')) return [book['${key}_1'], book['${key}_2']];
  return [for (final i in const [1, 2]) _legacyName(book, '${key}_$i')];
}

/// The name a great-grandparent's own key (`tree_ggp_1a_2`) had in the old two-line text, if any:
/// its line (the second gets any further lines too).
String? _legacyName(Map<String, dynamic> book, String key) {
  final m = RegExp(r'^(tree_ggp_\d[ab])_([12])$').firstMatch(key);
  if (m == null) return null;
  final names = [
    for (final l in ((book[m[1]!] as String?) ?? '').split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];
  return m[2] == '1' ? names.firstOrNull : (names.length < 2 ? null : names.skip(1).join(', '));
}

/// "AM" for "Alex Martin", "N" for "Noah".
String initials(String name) {
  final words = name.trim().split(RegExp(r'[\s-]+')).where((w) => w.isNotEmpty).toList();
  return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
}

/// "Family tree": a little tree growing from the baby, with the parents on its branches, then the
/// grandparents, then each grandparent's parents as a couple; one side lilac, the other seafoam.
/// Brothers and sisters and the rest of the family are listed under it.
class FamilyTreePage extends StatelessWidget {
  const FamilyTreePage({super.key, required this.child});
  final Child child;

  static bool hasText(Child child) => child.book.keys.any(_treeKeys.contains);

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final book = child.book;
    final s = context.watch<AppState>();
    final readOnly = s.bookOnly;
    Uint8List? photo(String key) => s.bookPhoto(child, key);
    const greatKeys = ['tree_ggp_1a', 'tree_ggp_1b', 'tree_ggp_2a', 'tree_ggp_2b'], grandKeys = ['tree_gp_1a', 'tree_gp_1b', 'tree_gp_2a', 'tree_gp_2b'];
    final great = [for (final k in greatKeys) _couple(book, k)];
    final grand = [book['tree_gp_1a'], book['tree_gp_1b'], book['tree_gp_2a'], book['tree_gp_2b']];
    final parents = [book['tree_parent_1'], book['tree_parent_2']];
    const sides = [Kind.sleep, Kind.activity];
    final babyPhoto = photo(treeBabyPhoto);
    // Book viewers see only the levels with names.
    final showGreat = great.any((g) => g.any((n) => n != null)) || (!readOnly && grand.any((n) => n != null));
    final showGrand = !readOnly || grand.any((n) => n != null) || showGreat;
    final showParents = !readOnly || parents.any((n) => n != null) || showGrand;

    return TapedPaper(
      tilt: -0.006,
      semanticLabel: readOnly ? l10n.pagesTreeTitle : l10n.pagesTapToEdit(l10n.pagesTreeTitle),
      onTap: readOnly ? null : () => editTreePage(context, child),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHead(l10n.pagesTreeTitle, Icons.account_tree_rounded),
          _ZoomableTree(
            id: child.id,
            width: _treeWidth(context, great, grand, parents, child.name),
            onAdd: readOnly ? null : () => editTreePage(context, child),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showGreat) ...[
                  _Grows(
                    6,
                    _TreeLevel([
                      for (final (i, g) in great.indexed)
                        _Couple(g, sides[i ~/ 2], photos: [photo('${greatKeys[i]}_1'), photo('${greatKeys[i]}_2')], hidden: readOnly && g.every((n) => n == null)),
                    ]),
                  ),
                  _Branches([for (final g in great) g.any((n) => n != null) || !readOnly], 4, width: 2, stage: 5),
                ],
                if (showGrand) ...[
                  _Grows(4, _TreeLevel([for (final (i, n) in grand.indexed) _Person(n, sides[i ~/ 2], size: 40, photo: photo(grandKeys[i]), hidden: readOnly && n == null)])),
                  _Branches([for (final n in grand) n != null || !readOnly], 2, width: 3, stage: 3),
                ],
                if (showParents) ...[
                  _Grows(2, _TreeLevel([for (final (i, n) in parents.indexed) _Person(n, sides[i], size: 50, photo: photo('tree_parent_${i + 1}'), hidden: readOnly && n == null)])),
                  _Branches([for (final n in parents) n != null || !readOnly], 1, width: 4.5, stage: 1),
                ],
                // The baby, where the tree grows from, on a bit of grass.
                _Grows(
                  0,
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Kind.milestone.fill(c),
                            shape: BoxShape.circle,
                            border: Border.all(color: c.surface, width: 3),
                            boxShadow: [BoxShadow(color: c.ink.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))],
                            image: babyPhoto == null ? null : DecorationImage(image: MemoryImage(babyPhoto), fit: BoxFit.cover),
                          ),
                          child: babyPhoto != null ? null : Icon(Icons.child_care_rounded, size: 34, color: c.bandInk),
                        ),
                        const SizedBox(height: 4),
                        Text(child.name, style: serifStyle(18, color: Kind.milestone.on(c))),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 150,
                          height: 10,
                          decoration: BoxDecoration(color: Kind.diaper.fill(c).withValues(alpha: 0.7), borderRadius: const BorderRadius.all(Radius.elliptical(75, 5))),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (book['tree_siblings'] case final v?) _Block(l10n.pagesTreeSiblings, v),
          if (book['tree_others'] case final v?) _Block(l10n.pagesTreeOthers, v),
          if (!hasText(child)) _Prompt(l10n.pagesTreePrompt),
        ],
      ),
    );
  }
}

/// The width the tree needs so no name is cut: each great-grandparent couple's names on one line,
/// grandparents' and parents' names wrapped at most between words, the baby's name whole. Never
/// less than the page (the spots then spread out as before).
double _treeWidth(BuildContext context, List<List<String?>> great, List<String?> grand, List<String?> parents, String baby) {
  final base = DefaultTextStyle.of(context).style;
  final scaler = MediaQuery.textScalerOf(context);
  final direction = Directionality.of(context);
  double measure(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: base.merge(style)),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  double longestWord(String? name, TextStyle style) => [
    0.0,
    for (final w in (name ?? '').split(RegExp(r'\s+')))
      if (w.isNotEmpty) measure(w, style),
  ].reduce(math.max);

  // Room around each spot: its padding plus a gap to the next one.
  const gap = 8.0;
  final couple = [58.0, for (final g in great) ...g.nonNulls.map((n) => measure(n, _coupleStyle))].reduce(math.max) + gap;
  final grandparent = [40.0, for (final n in grand) longestWord(n, _personStyle)].reduce(math.max) + 4 + gap;
  final parent = [50.0, for (final n in parents) longestWord(n, _personStyle)].reduce(math.max) + 4 + gap;
  return [4 * couple, 4 * grandparent, 2 * parent, measure(baby, serifStyle(18)) + gap].reduce(math.max).ceilToDouble();
}

const _personStyle = TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, height: 1.15);
const _coupleStyle = TextStyle(fontSize: 11, height: 1.2);

/// The tree at the width its names need. When that is wider than the page, it opens shrunk to fit
/// the page whole. Tapping someone glides and zooms onto their branch; tapping them again, the baby
/// or an empty spot glides back out. A pinch zooms and a drag pans too. Where the tree runs past the
/// window, its edge fades out instead of being cut. The first time it shows (once per child while
/// the app runs), it grows from the baby up, a generation at a time. A button in its corner opens
/// it [fullScreen]: there it fills the screen, whole and centred, to look at (no editing).
class _ZoomableTree extends StatefulWidget {
  const _ZoomableTree({required this.id, required this.width, required this.child, this.onAdd, this.fullScreen = false});
  final String id;
  final double width;
  final Widget child;
  final VoidCallback? onAdd;
  final bool fullScreen;

  @override
  State<_ZoomableTree> createState() => _ZoomableTreeState();
}

class _ZoomableTreeState extends State<_ZoomableTree> with TickerProviderStateMixin {
  /// When each child's tree started growing in (this app run), so a tree built again (the list
  /// rebuilt as the book loads) carries on where it was, and later ones show grown.
  static final _growing = <String, DateTime>{};
  static const _fade = 28.0;
  final _transform = TransformationController();
  final _treeKey = GlobalKey();
  late final _grow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  late final _fly = AnimationController(vsync: this, duration: const Duration(milliseconds: 550))..addListener(_flying);
  Matrix4Tween? _flight;
  RenderObject? _focused;
  Size? _fitted;
  double _page = 0, _width = 0;
  Size _window = Size.zero;

  /// The whole tree's width in the page.
  double get _fit => _page / _width;

  /// The scale that shows the whole tree: its width in the card, also its height on a full screen.
  double get _whole {
    final h = (_treeKey.currentContext?.findRenderObject() as RenderBox?)?.size.height;
    if (!widget.fullScreen || h == null || h == 0 || _window.height == 0) return _fit;
    return math.min(_fit, _window.height / h);
  }

  /// The whole tree, centred.
  Matrix4 get _home {
    final s = _whole, h = (_treeKey.currentContext?.findRenderObject() as RenderBox?)?.size.height ?? 0;
    return Matrix4.diagonal3Values(s, s, 1)..setTranslationRaw((_page - _width * s) / 2, widget.fullScreen ? math.max(0, (_window.height - h * s) / 2) : 0, 0);
  }

  @override
  void initState() {
    super.initState();
    final since = DateTime.now().difference(_growing.putIfAbsent(widget.id, DateTime.now));
    _grow.forward(from: since.inMicroseconds / _grow.duration!.inMicroseconds);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _grow.value = 1;
  }

  @override
  void dispose() {
    _grow.dispose();
    _fly.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _flying() => _transform.value = _flight!.transform(Curves.easeInOutCubic.transform(_fly.value));

  void _flyTo(Matrix4 to) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _fly.stop();
      _transform.value = to;
      return;
    }
    _flight = Matrix4Tween(begin: _transform.value.clone(), end: to);
    _fly.forward(from: 0);
  }

  void _overview() {
    _focused = null;
    _flyTo(_home);
  }

  /// Glides onto a spot: at least the tree's own size, with room for its neighbours.
  void _focus(BuildContext spot) {
    final box = spot.findRenderObject() as RenderBox?, tree = _treeKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || tree == null || !box.attached) return;
    if (identical(box, _focused)) return _overview();
    _focused = box;
    final rect = MatrixUtils.transformRect(box.getTransformTo(tree), Offset.zero & box.size);
    final h = tree.size.height, view = _window.height;
    final scale = math.max(1.0, math.min(1.6, _page / (rect.width * 2)));
    double place(double t, double window, double content) => content <= window ? (window - content) / 2 : t.clamp(window - content, 0.0);
    final dx = place(_page / 2 - rect.center.dx * scale, _page, _width * scale);
    final dy = place(view / 2 - rect.center.dy * scale, view, h * scale);
    _flyTo(Matrix4.diagonal3Values(scale, scale, 1)..setTranslationRaw(dx, dy, 0));
  }

  /// Fades the window's edges where the tree runs past them, more the further it goes.
  Widget _fadeEdges(Size window, Widget child) => ValueListenableBuilder<Matrix4>(
    valueListenable: _transform,
    child: child,
    builder: (context, m, child) {
      final tree = _treeKey.currentContext?.findRenderObject() as RenderBox?;
      if (tree == null || !tree.hasSize) return child!;
      // No rotation here: the x axis' scale is the zoom (the z axis keeps 1).
      final scale = m.entry(0, 0), t = m.getTranslation();
      double past(double by) => (by / _fade).clamp(0.0, 1.0);
      final left = past(-t.x), right = past(t.x + _width * scale - window.width);
      final top = past(-t.y), bottom = past(t.y + tree.size.height * scale - window.height);
      if (left + right + top + bottom == 0) return child!;
      // An alpha mask, not a colour on screen: opaque keeps the tree, clear hides it.
      Shader mask(Rect r, Axis axis, double start, double end) {
        final f = _fade / (axis == Axis.horizontal ? r.width : r.height);
        return LinearGradient(
          begin: axis == Axis.horizontal ? Alignment.centerLeft : Alignment.topCenter,
          end: axis == Axis.horizontal ? Alignment.centerRight : Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 1 - start), Colors.black, Colors.black, Colors.black.withValues(alpha: 1 - end)],
          stops: [0, f, 1 - f, 1],
        ).createShader(r);
      }

      return ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => mask(r, Axis.horizontal, left, right),
        child: ShaderMask(blendMode: BlendMode.dstIn, shaderCallback: (r) => mask(r, Axis.vertical, top, bottom), child: child),
      );
    },
  );

  @override
  Widget build(BuildContext context) => _TreeScope(
    grow: _grow,
    focus: _focus,
    add: widget.onAdd,
    child: LayoutBuilder(
      builder: (context, box) {
        _page = box.maxWidth;
        _width = math.max(_page, widget.width);
        // Back to the opening view whenever the page or the tree changes width.
        if (_fitted != Size(_page, _width)) {
          _fitted = Size(_page, _width);
          _focused = null;
          _fly.stop();
          _transform.value = Matrix4.diagonal3Values(_fit, _fit, 1);
          // On a full screen, the whole tree's height is known once it is laid out.
          if (widget.fullScreen) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _transform.value = _home : null);
        }
        final viewer = LayoutBuilder(
          builder: (context, window) {
            _window = window.biggest;
            return _fadeEdges(
              window.biggest,
              InteractiveViewer(
                transformationController: _transform,
                constrained: false,
                minScale: math.min(_fit, _whole),
                maxScale: 3,
                onInteractionStart: (_) {
                  _fly.stop();
                  _focused = null;
                },
                // Taps that land on no one (the baby, the gaps) glide back to the whole tree.
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _overview,
                  child: SizedBox(key: _treeKey, width: _width, child: widget.child),
                ),
              ),
            );
          },
        );
        if (widget.fullScreen) return viewer;
        return Stack(
          children: [
            // An unseen copy of the tree, shrunk to fit, gives the window its height.
            Visibility(
              visible: false,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: ExcludeSemantics(
                child: FittedBox(fit: BoxFit.fitWidth, child: SizedBox(width: _width, child: widget.child)),
              ),
            ),
            Positioned.fill(child: viewer),
            // In the bottom corner, beside the baby, where the tree has nobody.
            Positioned(
              bottom: 0,
              right: 0,
              child: IconButton(
                tooltip: l10n.pagesTreeFullScreen,
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(backgroundColor: context.pal.surface.withValues(alpha: 0.85), foregroundColor: context.pal.muted),
                icon: const Icon(Icons.fullscreen_rounded),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (_) => _FullScreenTree(_ZoomableTree(id: widget.id, width: widget.width, fullScreen: true, child: widget.child)),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// The family tree on a screen of its own.
class _FullScreenTree extends StatelessWidget {
  const _FullScreenTree(this.tree);
  final Widget tree;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.pal.surface,
    appBar: AppBar(
      backgroundColor: context.pal.surface,
      title: Text(l10n.pagesTreeTitle, style: serifStyle(20)),
    ),
    body: SafeArea(
      top: false,
      child: Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: tree),
    ),
  );
}

/// What the tree's spots need from the tree around them: the grow-in, and what a tap does.
class _TreeScope extends InheritedWidget {
  const _TreeScope({required this.grow, required this.focus, required this.add, required super.child});
  final Animation<double> grow;
  final void Function(BuildContext spot) focus;
  final VoidCallback? add;

  static _TreeScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_TreeScope>();

  @override
  bool updateShouldNotify(_TreeScope old) => old.grow != grow || old.add != add;
}

/// When a generation grows in: the baby first (stage 0), then each level of branches and people.
Interval _growStage(int stage) => Interval(stage * 0.13, math.min(1, stage * 0.13 + 0.22));

/// A level of the tree that fades and swells in at its [stage] of the grow-in.
class _Grows extends StatelessWidget {
  const _Grows(this.stage, this.child);
  final int stage;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final grow = _TreeScope.of(context)?.grow ?? kAlwaysCompleteAnimation;
    return AnimatedBuilder(
      animation: grow,
      child: child,
      builder: (context, child) {
        final t = _growStage(stage).transform(grow.value);
        return Opacity(
          opacity: Curves.easeOut.transform(t),
          child: Transform.scale(scale: 0.6 + 0.4 * Curves.easeOutBack.transform(t), alignment: Alignment.bottomCenter, child: child),
        );
      },
    );
  }
}

/// A person (or couple) on the tree: tapping glides onto them, or opens the page to fill in an
/// empty spot.
class _Spot extends StatelessWidget {
  const _Spot({required this.empty, required this.child});
  final bool empty;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = _TreeScope.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: scope == null ? null : (empty ? scope.add : () => scope.focus(context)),
      child: child,
    );
  }
}

/// One level of the tree: its spots spread evenly across the page.
class _TreeLevel extends StatelessWidget {
  const _TreeLevel(this.spots);
  final List<Widget> spots;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [for (final s in spots) Expanded(child: s)],
  );
}

/// A round badge with the initials and the name under it (a "+" spot to fill in when empty, or
/// nothing for a book viewer).
class _Person extends StatelessWidget {
  const _Person(this.name, this.side, {required this.size, this.photo, this.hidden = false});
  final String? name;
  final Kind side;
  final double size;
  final Uint8List? photo;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    if (hidden) return const SizedBox();
    final c = context.pal;
    final n = name;
    return _Spot(
      empty: n == null,
      child: Column(
        children: [
          _Badge(n == null ? null : initials(n), side, size: size, photo: photo),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              n ?? '',
              textAlign: TextAlign.center,
              style: _personStyle.copyWith(color: c.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// A grandparent's parents: two small badges side by side and their names under them.
class _Couple extends StatelessWidget {
  const _Couple(this.names, this.side, {this.photos = const [null, null], this.hidden = false});
  final List<String?> names;
  final Kind side;
  final List<Uint8List?> photos;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    if (hidden) return const SizedBox();
    final c = context.pal;
    return _Spot(
      empty: names.every((n) => n == null),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Badge(names[0] == null ? null : initials(names[0]!), side, size: 28, small: true, photo: photos[0]),
              const SizedBox(width: 2),
              _Badge(names[1] == null ? null : initials(names[1]!), side, size: 28, small: true, photo: photos[1]),
            ],
          ),
          const SizedBox(height: 3),
          for (final n in names.nonNulls)
            Text(
              n,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              style: _coupleStyle.copyWith(color: c.ink),
            ),
        ],
      ),
    );
  }
}

/// A circle with the person's photo, else their initials in the side's color, or an outlined "+"
/// when nobody is named yet.
class _Badge extends StatelessWidget {
  const _Badge(this.initials, this.side, {required this.size, this.small = false, this.photo});
  final String? initials;
  final Kind side;
  final double size;
  final bool small;
  final Uint8List? photo;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final empty = initials == null && photo == null;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: empty ? c.surface : side.fill(c),
        shape: BoxShape.circle,
        border: Border.all(color: empty ? c.line : (photo != null ? side.fill(c) : c.surface), width: small ? 1.5 : 2.5),
        image: photo == null ? null : DecorationImage(image: MemoryImage(photo!), fit: BoxFit.cover),
      ),
      child: photo != null
          ? null
          : empty
          ? Icon(Icons.add_rounded, size: size * 0.5, color: c.muted)
          : Text(
              initials!,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * 0.36, color: side.on(c)),
            ),
    );
  }
}

/// The branches from a level down to the one under it ([to] spots): each spot's branch curves
/// down to the one it belongs to (two grandparents → their child), with a leaf on the way.
class _Branches extends StatelessWidget {
  const _Branches(this.shown, this.to, {required this.width, required this.stage});
  final List<bool> shown;
  final int to;
  final double width;
  final int stage;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final grow = _TreeScope.of(context)?.grow ?? kAlwaysCompleteAnimation;
    return SizedBox(
      height: 28,
      width: double.infinity,
      child: CustomPaint(
        painter: _BranchesPainter(shown, to, width, Kind.growth.on(c).withValues(alpha: c.isDark ? 0.75 : 0.6), Kind.diaper.fill(c), grow: grow, stage: stage),
      ),
    );
  }
}

class _BranchesPainter extends CustomPainter {
  _BranchesPainter(this.shown, this.to, this.width, this.wood, this.leaf, {required this.grow, required this.stage}) : super(repaint: grow);
  final List<bool> shown;
  final int to;
  final double width;
  final Color wood, leaf;
  final Animation<double> grow;
  final int stage;

  @override
  void paint(Canvas canvas, Size size) {
    final branch = Paint()
      ..color = wood
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final leafPaint = Paint()..color = leaf;
    final from = shown.length, per = from ~/ to, h = size.height;
    // While the tree grows in, each branch is drawn from the bottom up, then its leaf unfolds.
    final t = Curves.easeInOut.transform(_growStage(stage).transform(grow.value));
    if (t == 0) return;
    for (var i = 0; i < from; i++) {
      if (!shown[i]) continue;
      final top = Offset(size.width * (i + 0.5) / from, 0);
      final below = Offset(size.width * (i ~/ per + 0.5) / to, h);
      final path = Path()
        ..moveTo(below.dx, below.dy)
        ..cubicTo(below.dx, h * 0.45, top.dx, h * 0.55, top.dx, top.dy);
      if (t < 1) {
        final metric = path.computeMetrics().first;
        canvas.drawPath(metric.extractPath(0, metric.length * t), branch);
      } else {
        canvas.drawPath(path, branch);
      }
      if (t < 0.6) continue;
      // A leaf halfway, leaning out from the branch.
      final mid = Offset((top.dx + below.dx) / 2, h / 2);
      final out = top.dx == below.dx ? (i.isEven ? -1.0 : 1.0) : (top.dx < below.dx ? -1.0 : 1.0);
      canvas.save();
      canvas.translate(mid.dx, mid.dy);
      canvas.rotate(out * 0.9);
      final s = (4.0 + width) * ((t - 0.6) / 0.4);
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(s * 0.6, -s * 0.9, 0, -s * 2)
          ..quadraticBezierTo(-s * 0.6, -s * 0.9, 0, 0),
        leafPaint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BranchesPainter old) =>
      old.wood != wood || old.leaf != leaf || old.to != to || old.width != width || old.shown.join() != shown.join() || old.grow != grow || old.stage != stage;
}

/// "A letter for later": up to two letters (from whom, and the letter), to read at 18.
class LetterPage extends StatelessWidget {
  const LetterPage({super.key, required this.child});
  final Child child;

  static bool hasText(Child child) => child.book['letter_1'] != null || child.book['letter_2'] != null;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final book = child.book;
    final b = child.birthDate;
    final readOnly = context.select<AppState, bool>((s) => s.bookOnly);
    return TapedPaper(
      tilt: 0.007,
      semanticLabel: readOnly ? l10n.pagesLetterTitle : l10n.pagesTapToEdit(l10n.pagesLetterTitle),
      onTap: readOnly ? null : () => editLetterPage(context, child),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHead(l10n.pagesLetterTitle, Icons.mail_rounded, subtitle: b == null ? null : l10n.pagesLetterOpenOn(DateFormat.yMMMMd().format(DateTime(b.year + 18, b.month, b.day)))),
          for (final n in const [1, 2])
            if (book['letter_$n'] case final text?)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (book['letter_from_$n'] case final from?) Text(l10n.pagesLetterFrom(from), style: serifStyle(17, color: Kind.milestone.on(c))),
                    const SizedBox(height: 4),
                    Text(
                      text,
                      style: TextStyle(color: c.ink, fontSize: 15.5, height: 1.45, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
          if (!hasText(child)) _Prompt(l10n.pagesLetterPrompt(child.name)),
        ],
      ),
    );
  }
}

/// A diary page's start: the schedule of the past 7 days (wake-up and bedtime from the sleep
/// entries, naps, night sleep and feeds from the trends), or null with nothing logged.
Future<String?> diarySchedule(AppState s) async {
  final api = s.api, id = s.childId;
  if (api == null || id == null) return null;
  final now = DateTime.now();
  final sleeps = await api.get('/children/$id/events', {'type': 'sleep', 'from': formatTime(now.subtract(const Duration(days: 7))), 'limit': '1000'});
  final trends = await api.get('/children/$id/trends', {'days': '7'});
  final lines = scheduleLines(
    [for (final e in (sleeps as Map)['events'] as List) Event(e)],
    ((trends as Map)['averages'] as Map?)?.cast<String, dynamic>() ?? const {},
    dayStart: s.family?.dayStart ?? '06:00',
    dayEnd: s.family?.dayEnd ?? '18:00',
  );
  return lines.isEmpty ? null : [l10n.diarySchedule, for (final l in lines) '• $l'].join('\n');
}

/// The schedule's lines: usual wake-up, naps, bedtime, night sleep and feeds a day. Bedtime is the
/// usual start of the first long sleep (90 min or more) of each evening (from an hour before
/// [dayEnd], so a late nap isn't bedtime), wake-up the usual end of each night's last sleep before noon.
List<String> scheduleLines(List<Event> sleeps, Map<String, dynamic> averages, {String dayStart = '06:00', String dayEnd = '18:00'}) {
  int minutes(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p.length > 1 ? p[1] : '0');
  }

  // Minutes since noon, so a night doesn't wrap around midnight.
  int sinceNoon(DateTime t) => (t.hour * 60 + t.minute - 720) % 1440;
  final evening = (minutes(dayEnd) - 60 - 720) % 1440, morning = (minutes(dayStart) - 720) % 1440;
  final bed = <String, int>{}, wake = <String, int>{};
  for (final e in sleeps) {
    final end = e.end;
    if (end == null) continue;
    final start = sinceNoon(e.start);
    if (start < evening || start >= morning) continue;
    final day = e.start.hour >= 12 ? e.start : e.start.subtract(const Duration(days: 1));
    final night = '${day.year}-${day.month}-${day.day}';
    if (end.difference(e.start).inMinutes >= 90 && start < (bed[night] ?? 1440)) bed[night] = start;
    final stop = sinceNoon(end);
    if (stop >= 720 && end.difference(e.start).inHours < 16 && stop > (wake[night] ?? -1)) wake[night] = stop;
  }
  String? usual(Iterable<int> values) {
    if (values.isEmpty) return null;
    final sorted = values.toList()..sort();
    final m = (sorted[sorted.length ~/ 2] / 5).round() * 5;
    final t = (m + 720) % 1440;
    return timeOfDay(DateTime(2000, 1, 1, t ~/ 60, t % 60));
  }

  double avg(String k) => toDouble(averages[k]) ?? 0;
  final naps = avg('naps_per_day').round(), feeds = avg('feeds_per_day').round();
  final nightSleep = avg('night_sleep_seconds_per_day').round();
  return [
    if (usual(wake.values) case final t?) l10n.diaryWakesUp(t),
    if (naps > 0) l10n.diaryNaps(naps, duration(avg('day_sleep_seconds_per_day').round())),
    if (usual(bed.values) case final t?) l10n.diaryBedtime(t),
    if (nightSleep > 0) l10n.diaryNightSleep(duration(nightSleep)),
    if (feeds > 0) l10n.diaryFeeds(feeds),
  ];
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

Future<void> editStoryPage(BuildContext context, Child child) => _editPage(
  context,
  child,
  title: l10n.pagesStoryTitle,
  icon: Icons.local_hospital_rounded,
  fields: [
    (key: 'labour_start', label: l10n.pagesLabourStarted, hint: l10n.pagesHintLabourStarted, long: false),
    (key: 'labour_story', label: l10n.pagesLabourStory, hint: l10n.pagesHintLabourStory, long: true),
    (key: 'birth_people', label: l10n.pagesBirthPeople, hint: l10n.pagesHintBirthPeople, long: false),
    (key: 'hospital_stay', label: l10n.pagesHospital, hint: l10n.pagesHintHospital, long: false),
  ],
);

/// The family tree's photos: each name field's photo key, the same as the field's key (the
/// great-grandparents' `<key>_1`, `<key>_2` were already theirs before they had a field each). Saved with `/children/{id}/book-photos/{key}`.
Map<String, List<String>> get _treePhotos => {
  for (final n in const [1, 2]) ...{
    'tree_parent_$n': ['tree_parent_$n'],
    for (final g in const ['a', 'b']) ...{
      'tree_gp_$n$g': ['tree_gp_$n$g'],
      for (final i in const [1, 2]) 'tree_ggp_$n${g}_$i': ['tree_ggp_$n${g}_$i'],
    },
  },
};

/// The baby's own photo on the tree (not the profile picture).
const treeBabyPhoto = 'tree_baby';

Future<void> editTreePage(BuildContext context, Child child) => _editPage(
  context,
  child,
  title: l10n.pagesTreeTitle,
  icon: Icons.account_tree_rounded,
  photos: _treePhotos,
  photoRows: [(key: treeBabyPhoto, label: child.name, hint: l10n.pagesTreeBabyPhoto)],
  fields: [
    for (final n in const [1, 2]) ...[
      (key: 'tree_parent_$n', label: l10n.pagesTreeParent(n), hint: l10n.pagesHintName, long: false),
      for (final g in const ['a', 'b']) ...[
        (key: 'tree_gp_$n$g', label: l10n.pagesTreeGrandparent(n), hint: l10n.pagesHintName, long: false),
        // Each of the grandparent's parents in a box of their own.
        for (final i in const [1, 2]) (key: 'tree_ggp_$n${g}_$i', label: l10n.pagesTreeTheirParent(i), hint: l10n.pagesHintName, long: false),
      ],
    ],
    (key: 'tree_siblings', label: l10n.pagesTreeSiblings, hint: l10n.pagesHintNames, long: true),
    (key: 'tree_others', label: l10n.pagesTreeOthers, hint: l10n.pagesHintNames, long: true),
  ],
);

Future<void> editLetterPage(BuildContext context, Child child) => _editPage(
  context,
  child,
  title: l10n.pagesLetterTitle,
  icon: Icons.mail_rounded,
  fields: [
    for (final n in const [1, 2]) ...[
      (key: 'letter_from_$n', label: l10n.pagesLetterFromNumber(n), hint: l10n.pagesHintLetterFrom, long: false),
      (key: 'letter_$n', label: l10n.pagesLetterNumber(n), hint: l10n.pagesHintLetter(child.name), long: true),
    ],
  ],
);

Future<void> _editPage(
  BuildContext context,
  Child child, {
  required String title,
  required IconData icon,
  required List<_Field> fields,
  bool time = false,
  Map<String, List<String>> photos = const {},
  List<_PhotoRow> photoRows = const [],
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: context.pal.background,
  builder: (_) => _PageForm(child: child, title: title, icon: icon, fields: fields, time: time, photos: photos, photoRows: photoRows),
);

/// A form row with only a photo (its key in `book_photos`) and a line saying what it is for.
typedef _PhotoRow = ({String key, String label, String hint});

class _PageForm extends StatefulWidget {
  const _PageForm({
    required this.child,
    required this.title,
    required this.icon,
    required this.fields,
    required this.time,
    this.photos = const {},
    this.photoRows = const [],
  });
  final Child child;
  final String title;
  final IconData icon;
  final List<_Field> fields;
  final bool time;

  /// Fields with photos next to them: field key → the photos' keys (`book_photos`).
  final Map<String, List<String>> photos;

  /// Photo-only rows, at the top.
  final List<_PhotoRow> photoRows;

  @override
  State<_PageForm> createState() => _PageFormState();
}

class _PageFormState extends State<_PageForm> {
  late final _text = {
    for (final f in widget.fields) f.key: TextEditingController(text: _initial(f.key)),
  };

  /// A field's text; a great-grandparent's name may still be in the old two-line text.
  String _initial(String key) {
    final book = widget.child.book;
    final m = RegExp(r'^(tree_ggp_\d[ab])_([12])$').firstMatch(key);
    if (m != null) return _couple(book, m[1]!)[int.parse(m[2]!) - 1] ?? '';
    return book[key] ?? '';
  }
  late String? _time = widget.child.book['birth_time'];
  bool _busy = false;

  /// Photos picked (bytes) or removed (null) here, saved with the page.
  final Map<String, Uint8List?> _photos = {};

  Future<void> _pickPhoto(String key) async {
    final had = _photos.containsKey(key) ? _photos[key] != null : widget.child.bookPhotos.containsKey(key);
    if (had) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        builder: (sheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(leading: const Icon(Icons.photo_library_rounded), title: Text(l10n.bookChangePhoto), onTap: () => Navigator.pop(sheet, 'change')),
              ListTile(leading: const Icon(Icons.delete_outline_rounded), title: Text(l10n.remove), onTap: () => Navigator.pop(sheet, 'remove')),
            ],
          ),
        ),
      );
      if (choice == null || !mounted) return;
      if (choice == 'remove') return setState(() => _photos[key] = null);
    }
    final photo = await guard(context, () => pickSquarePhoto(size: 400, jpeg: true));
    if (photo != null && mounted) setState(() => _photos[key] = photo);
  }

  Future<void> _pickTime() async {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(_time ?? '');
    final t = await showTimePicker(
      context: context,
      initialTime: m == null
          ? const TimeOfDay(hour: 12, minute: 0)
          : TimeOfDay(hour: int.parse(m.group(1)!), minute: int.parse(m.group(2)!)),
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: use24h), child: child!),
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
      // The great-grandparents' old two-line text is now in their own keys.
      if (RegExp(r'^tree_ggp_\d[ab]_[12]$').hasMatch(key)) book.remove(key.substring(0, key.length - 2));
    }
    if (widget.time) book['birth_time'] = _time;
    book.removeWhere((_, v) => v == null || (v is String && v.isEmpty));
    var ok = await guard(
      context,
      () => s.act((api) => api.patch('/children/${widget.child.id}', {'book': book}), families: true).then((_) => true),
    );
    final id = widget.child.id;
    for (final MapEntry(:key, value: bytes) in _photos.entries) {
      if (ok != true || !mounted) break;
      final path = '/children/$id/book-photos/$key';
      if (bytes == null) {
        if (!widget.child.bookPhotos.containsKey(key)) continue;
        ok = await guard(context, () => s.act((api) => api.delete(path), families: true).then((_) => true));
      } else {
        ok = await guard(
          context,
          () => s.act((api) => api.putBytes(path, bytes, contentType: 'image/jpeg'), families: true).then((res) {
            if (res is Map<String, dynamic>) s.rememberBookPhoto(res, key, bytes);
            return true;
          }),
        );
      }
    }
    if (!mounted) return;
    if (ok == true) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false);
    }
  }

  Widget _photoSpot(String key) => _PhotoSpot(
    photo: _photos.containsKey(key) ? _photos[key] : context.watch<AppState>().bookPhoto(widget.child, key),
    has: _photos.containsKey(key) ? _photos[key] != null : widget.child.bookPhotos.containsKey(key),
    onTap: () => _pickPhoto(key),
  );

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
                        _time == null ? l10n.pagesSetTime : hhmmLabel(_time!),
                        style: TextStyle(fontWeight: FontWeight.w600, color: _time == null ? c.accent : c.ink),
                      ),
                    ),
                  for (final r in widget.photoRows)
                    FormRow(
                      label: r.label,
                      below: Row(
                        children: [
                          _photoSpot(r.key),
                          const SizedBox(width: 12),
                          Expanded(child: Text(r.hint, style: TextStyle(color: c.muted))),
                        ],
                      ),
                    ),
                  for (final f in widget.fields)
                    FormRow(
                      label: f.label,
                      below: Row(
                        children: [
                          for (final key in widget.photos[f.key] ?? const <String>[]) ...[
                            _photoSpot(key),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: TextField(
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

/// A round photo spot next to a name in a page's form: the photo, or a camera to add one.
class _PhotoSpot extends StatelessWidget {
  const _PhotoSpot({required this.photo, required this.has, required this.onTap});
  final Uint8List? photo;

  /// A photo is set (it may still be loading).
  final bool has;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final k = Kind.milestone;
    return Semantics(
      button: true,
      label: has ? l10n.bookChangePhoto : l10n.bookAddPhoto,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: k.fill(c).withValues(alpha: 0.35),
            border: Border.all(color: k.on(c).withValues(alpha: 0.45), width: 1.5),
            image: photo == null ? null : DecorationImage(image: MemoryImage(photo!), fit: BoxFit.cover),
          ),
          child: photo != null ? null : Icon(has ? Icons.photo_rounded : Icons.add_a_photo_rounded, size: 20, color: k.on(c)),
        ),
      ),
    );
  }
}
