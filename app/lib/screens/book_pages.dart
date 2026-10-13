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
          if (book['birth_time'] case final t?) _Line(l10n.pagesAt, t),
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

/// The family tree's names: parents (1, 2), each one's parents, their grandparents (several lines),
/// brothers and sisters, aunts, uncles and cousins.
const _treeKeys = ['tree_parent_1', 'tree_parent_2', 'tree_gp_1a', 'tree_gp_1b', 'tree_gp_2a', 'tree_gp_2b', 'tree_great_1', 'tree_great_2', 'tree_siblings', 'tree_others'];

/// "Family tree": the baby at the bottom, the parents above, then the grandparents (and the
/// great-grandparents as lists), with the brothers and sisters and the rest of the family below.
class FamilyTreePage extends StatelessWidget {
  const FamilyTreePage({super.key, required this.child});
  final Child child;

  static bool hasText(Child child) => child.book.keys.any(_treeKeys.contains);

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final book = child.book;
    final readOnly = context.select<AppState, bool>((s) => s.bookOnly);
    final grand = [book['tree_gp_1a'], book['tree_gp_1b'], book['tree_gp_2a'], book['tree_gp_2b']];
    final parents = [book['tree_parent_1'], book['tree_parent_2']];
    final great = [book['tree_great_1'], book['tree_great_2']];
    // Book viewers see only the rows with names.
    final showGrand = !readOnly || grand.any((n) => n != null);
    final showParents = !readOnly || parents.any((n) => n != null) || showGrand;

    Widget caption(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(color: c.muted, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.1),
      ),
    );

    return TapedPaper(
      tilt: -0.006,
      semanticLabel: readOnly ? l10n.pagesTreeTitle : l10n.pagesTapToEdit(l10n.pagesTreeTitle),
      onTap: readOnly ? null : () => editTreePage(context, child),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHead(l10n.pagesTreeTitle, Icons.account_tree_rounded),
          if (great.any((g) => g != null)) ...[
            caption(l10n.pagesTreeGreat),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final g in great)
                  Expanded(
                    child: Text(
                      (g ?? '').split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).join('\n'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.ink, fontSize: 13, height: 1.35),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (showGrand) ...[caption(l10n.pagesTreeGrandparents), _TreeRow(grand), _TreeJoins(grand, 2)],
          if (showParents) ...[if (!showGrand) caption(l10n.pagesTreeParents), _TreeRow(parents), _TreeJoins(parents, 1)],
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(color: Kind.milestone.fill(c), borderRadius: BorderRadius.circular(14)),
              child: Text(child.name, style: serifStyle(18, color: c.bandInk)),
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

/// A row of the tree: one box per name, spread evenly (an empty one is a dashed spot to fill in,
/// or nothing for a book viewer).
class _TreeRow extends StatelessWidget {
  const _TreeRow(this.names);
  final List<String?> names;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final readOnly = context.select<AppState, bool>((s) => s.bookOnly);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final n in names)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: n == null && readOnly
                    ? const SizedBox()
                    : Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        decoration: BoxDecoration(
                          color: n == null ? null : Kind.milestone.fill(c).withValues(alpha: 0.35),
                          border: n == null ? Border.all(color: c.line) : null,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          n ?? '?',
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, height: 1.2, color: n == null ? c.muted : c.ink),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The lines from a row of the tree down to the row under it ([to] boxes): each box joins the
/// one it belongs to (two grandparents → their child).
class _TreeJoins extends StatelessWidget {
  const _TreeJoins(this.names, this.to);
  final List<String?> names;
  final int to;

  @override
  Widget build(BuildContext context) {
    final readOnly = context.select<AppState, bool>((s) => s.bookOnly);
    return SizedBox(
      height: 20,
      width: double.infinity,
      child: CustomPaint(painter: _JoinsPainter([for (final n in names) n != null || !readOnly], to, context.pal.line)),
    );
  }
}

class _JoinsPainter extends CustomPainter {
  _JoinsPainter(this.shown, this.to, this.color);
  final List<bool> shown;
  final int to;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final from = shown.length, per = from ~/ to;
    for (var j = 0; j < to; j++) {
      final below = Offset(size.width * (j + 0.5) / to, size.height);
      final mid = size.height / 2;
      final tops = [
        for (var i = j * per; i < (j + 1) * per; i++)
          if (shown[i]) size.width * (i + 0.5) / from,
      ];
      if (tops.isEmpty) continue;
      for (final x in tops) {
        canvas.drawLine(Offset(x, 0), Offset(x, mid), paint);
      }
      final left = math.min(tops.reduce(math.min), below.dx), right = math.max(tops.reduce(math.max), below.dx);
      canvas.drawLine(Offset(left, mid), Offset(right, mid), paint);
      canvas.drawLine(Offset(below.dx, mid), below, paint);
    }
  }

  @override
  bool shouldRepaint(_JoinsPainter old) => old.color != color || old.to != to || old.shown.join() != shown.join();
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

Future<void> editTreePage(BuildContext context, Child child) => _editPage(
  context,
  child,
  title: l10n.pagesTreeTitle,
  icon: Icons.account_tree_rounded,
  fields: [
    for (final n in const [1, 2]) ...[
      (key: 'tree_parent_$n', label: l10n.pagesTreeParent(n), hint: l10n.pagesHintName, long: false),
      (key: 'tree_gp_${n}a', label: l10n.pagesTreeGrandparent(n), hint: l10n.pagesHintName, long: false),
      (key: 'tree_gp_${n}b', label: l10n.pagesTreeGrandparent(n), hint: l10n.pagesHintName, long: false),
      (key: 'tree_great_$n', label: l10n.pagesTreeGreatOf(n), hint: l10n.pagesHintNames, long: true),
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
