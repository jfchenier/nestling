import 'l10n/l10n.dart';

/// The family tree's people, kept as texts in the child's `book` (names, roles) and photos in its
/// `book_photos`, both under the same keys.
///
/// Ancestors are numbered the genealogists' way (Ahnentafel): the baby is 1 and a person n's
/// parents are 2n and 2n + 1, so parents are 2–3, grandparents 4–7, great-grandparents 8–15 and so
/// on, with no end. The first three generations keep the keys they had before the tree could grow
/// (`tree_parent_1`, `tree_gp_1a`, `tree_ggp_1a_1`…), so nothing saved has to move and older
/// versions of the app still show them; from 16 on a person's key is `tree_a<n>`.
///
/// Anyone on the tree can have brothers and sisters: `tree_s<n>_<i>` is person n's i-th (`tree_s1_1`
/// the baby's, `tree_s2_1` an aunt or uncle on the father's side). Each person's role
/// (`mother`/`father`, `sister`/`brother`) is in `<key>_role`; an ancestor without one is the
/// position's (2n father, 2n + 1 mother), a brother or sister without one is either.

/// How many generations a number is above the baby (the baby 0, parents 1…).
int generationOf(int n) => n.bitLength - 1;

/// An ancestor's key (n ≥ 2).
String treeKey(int n) {
  assert(n >= 2);
  return switch (generationOf(n)) {
    1 => 'tree_parent_${n - 1}',
    2 => 'tree_gp_${_side(n)}',
    3 => 'tree_ggp_${_side(n >> 1)}_${n.isEven ? 1 : 2}',
    _ => 'tree_a$n',
  };
}

/// "1a" for 4, "1b" for 5, "2a" for 6, "2b" for 7.
String _side(int gp) => '${(gp - 4) ~/ 2 + 1}${(gp - 4).isEven ? 'a' : 'b'}';

/// The number an ancestor's key stands for, or null for any other key.
int? treeNumber(String key) {
  if (RegExp(r'^tree_parent_([12])$').firstMatch(key) case final m?) return int.parse(m[1]!) + 1;
  int gp(String s, String ab) => 4 + (int.parse(s) - 1) * 2 + (ab == 'a' ? 0 : 1);
  if (RegExp(r'^tree_gp_([12])([ab])$').firstMatch(key) case final m?) return gp(m[1]!, m[2]!);
  if (RegExp(r'^tree_ggp_([12])([ab])_([12])$').firstMatch(key) case final m?) return gp(m[1]!, m[2]!) * 2 + (m[3] == '1' ? 0 : 1);
  if (RegExp(r'^tree_a(\d{1,9})$').firstMatch(key) case final m?) {
    final n = int.parse(m[1]!);
    return generationOf(n) >= 4 ? n : null;
  }
  return null;
}

/// The key of person n's [i]-th brother or sister.
String siblingKey(int n, int i) => 'tree_s${n}_$i';

/// A brother or sister's key → (whose, which), or null.
(int, int)? siblingOf(String key) {
  final m = RegExp(r'^tree_s(\d{1,9})_(\d{1,4})$').firstMatch(key);
  return m == null ? null : (int.parse(m[1]!), int.parse(m[2]!));
}

/// The key of the person a node stands for: ancestor n, or the baby's own photo for 1.
const treeBabyPhoto = 'tree_baby';

/// The keys a family tree has in the book (all start with `tree_`).
bool isTreeKey(String key) => key.startsWith('tree_');

/// The book with the family tree in today's keys: the old two-line great-grandparent texts
/// (`tree_ggp_1a`: one name per line) become a key each, and the old "Brothers and sisters" text
/// (`tree_siblings`, one per line or comma) becomes the baby's brothers and sisters. Changes [book]
/// in place; saving it moves them for good.
Map<String, dynamic> migrateTree(Map<String, dynamic> book) {
  for (final base in const ['tree_ggp_1a', 'tree_ggp_1b', 'tree_ggp_2a', 'tree_ggp_2b']) {
    final old = book.remove(base);
    if (old is! String) continue;
    final names = [
      for (final l in old.split('\n'))
        if (l.trim().isNotEmpty) l.trim(),
    ];
    // Keys of their own win over the old text (they were saved later).
    if (book.containsKey('${base}_1') || book.containsKey('${base}_2')) continue;
    if (names.isNotEmpty) book['${base}_1'] = names.first;
    if (names.length > 1) book['${base}_2'] = names.skip(1).join(', ');
  }
  final old = book.remove('tree_siblings');
  if (old is String) {
    var i = nextSibling(book, 1);
    for (final name in old.split(RegExp(r'[\n,;]'))) {
      if (name.trim().isNotEmpty) book[siblingKey(1, i++)] = name.trim();
    }
  }
  return book;
}

/// The next free number for a new brother or sister of person n.
int nextSibling(Map<String, dynamic> book, int n) {
  var i = 0;
  for (final k in book.keys) {
    if (siblingOf(k) case (final whose, final which) when whose == n && which > i) i = which;
  }
  return i + 1;
}

enum Role { mother, father, sister, brother }

/// The family tree as read from a child's book (already [migrateTree]d) and their photos' keys.
class FamilyTree {
  FamilyTree(Map<String, dynamic> book, this.photos) : book = migrateTree({...book});

  final Map<String, dynamic> book;
  final Set<String> photos;

  String? name(String key) => switch (book[key]) {
    final String s when s.trim().isNotEmpty => s.trim(),
    _ => null,
  };

  /// Someone is on the tree once they have a name or a photo.
  bool has(String key) => name(key) != null || photos.contains(key);
  bool hasAncestor(int n) => n == 1 || has(treeKey(n));

  /// Anyone on the tree above n (their parents, theirs…), however far up.
  bool hasAncestorsAbove(int n, {int? past}) {
    for (final k in book.keys.followedBy(photos)) {
      final a = treeNumber(k);
      if (a == null || !has(k)) continue;
      final up = generationOf(a) - generationOf(n);
      if (up >= 1 && (a >> up) == n && (past == null || up > past)) return true;
    }
    return false;
  }

  /// Person n's brothers and sisters' keys, in the order they were added.
  List<String> siblings(int n) {
    final found = <int>{};
    for (final k in book.keys.followedBy(photos)) {
      if (siblingOf(k) case (final whose, final which) when whose == n && has(k)) found.add(which);
    }
    return [for (final i in found.toList()..sort()) siblingKey(n, i)];
  }

  Role role(String key) {
    final saved = book['${key}_role'];
    if (siblingOf(key) != null) return saved == 'brother' ? Role.brother : Role.sister;
    if (saved == 'mother') return Role.mother;
    if (saved == 'father') return Role.father;
    return (treeNumber(key) ?? 2).isEven ? Role.father : Role.mother;
  }

  /// Whether a brother or sister's role was chosen (without one, they are "brother or sister").
  bool roleSet(String key) => book['${key}_role'] is String;

  bool female(String key) => role(key) == Role.mother || role(key) == Role.sister;

  /// "Grandmother on Dad's side", "Father", "Aunt on Mom's side", "Sister".
  String relation(String key) {
    if (siblingOf(key) case (final n, _)) {
      final g = generationOf(n);
      final known = roleSet(key);
      final word = g == 0 ? (!known ? l10n.treeSibling : (female(key) ? l10n.treeSister : l10n.treeBrother)) : _auntUncle(g - 1, known ? female(key) : null);
      return n == 1 ? word : _onSide(word, n);
    }
    final n = treeNumber(key)!;
    final word = _ancestor(generationOf(n) - 1, female(key));
    return generationOf(n) == 1 ? word : _onSide(word, n);
  }

  /// "Alex's mother" (with the name of the person they are the parent or sibling of), or null.
  String? whose(String key) {
    if (siblingOf(key) case (final n, _)) {
      if (n == 1) return null;
      final of = name(treeKey(n));
      if (of == null) return null;
      return l10n.treeSiblingOf(of, roleSet(key) ? role(key).name : 'other');
    }
    final n = treeNumber(key)!;
    if (n < 4) return null;
    final of = name(treeKey(n >> 1));
    return of == null ? null : l10n.treeParentOf(of, role(key).name);
  }

  /// The word for an ancestor [greats] generations past the parents (0 parent, 1 grandparent…).
  static String _ancestor(int greats, bool female) => switch (greats) {
    0 => female ? l10n.treeMother : l10n.treeFather,
    1 => female ? l10n.treeGrandmother : l10n.treeGrandfather,
    2 => female ? l10n.treeGreatGrandmother : l10n.treeGreatGrandfather,
    3 => female ? l10n.treeGreat2Grandmother : l10n.treeGreat2Grandfather,
    _ => female ? l10n.treeGreatNGrandmother(greats - 1) : l10n.treeGreatNGrandfather(greats - 1),
  };

  /// A parent's (0), grandparent's (1)… brother or sister; [female] null when not chosen.
  static String _auntUncle(int greats, bool? female) => switch (greats) {
    0 => female == null ? l10n.treeAuntOrUncle : (female ? l10n.treeAunt : l10n.treeUncle),
    1 => female == null ? l10n.treeGreatAuntOrUncle : (female ? l10n.treeGreatAunt : l10n.treeGreatUncle),
    _ => female == null ? l10n.treeGreatNAuntOrUncle(greats) : (female ? l10n.treeGreatNAunt(greats) : l10n.treeGreatNUncle(greats)),
  };

  /// "[word] on Dad's side", by which parent the line goes through.
  String _onSide(String word, int n) {
    final parent = n >> (generationOf(n) - 1);
    return role(treeKey(parent)) == Role.mother ? l10n.treeOnMomSide(word) : l10n.treeOnDadSide(word);
  }
}
