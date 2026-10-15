import 'package:flutter_test/flutter_test.dart';
import 'package:nestling/family_tree.dart';
import 'package:nestling/l10n/l10n.dart';

void main() {
  setUp(() => useLanguage('en'));

  test('ancestor numbers keep the first three generations\' old keys', () {
    expect(treeKey(2), 'tree_parent_1');
    expect(treeKey(3), 'tree_parent_2');
    expect([for (var n = 4; n < 8; n++) treeKey(n)], ['tree_gp_1a', 'tree_gp_1b', 'tree_gp_2a', 'tree_gp_2b']);
    expect(treeKey(8), 'tree_ggp_1a_1');
    expect(treeKey(9), 'tree_ggp_1a_2');
    expect(treeKey(15), 'tree_ggp_2b_2');
    expect(treeKey(16), 'tree_a16');
    expect(treeKey(1000), 'tree_a1000');
    for (var n = 2; n < 300; n++) {
      expect(treeNumber(treeKey(n)), n);
    }
    expect(treeNumber('tree_a9'), isNull);
    expect(treeNumber('tree_others'), isNull);
    expect(treeNumber('tree_s1_1'), isNull);
    expect(siblingOf('tree_s5_2'), (5, 2));
  });

  test('older texts move to their own keys', () {
    final book = migrateTree({
      'tree_ggp_1a': 'Rose\nPaul',
      'tree_ggp_2b': 'Anna\nIvan\nOleg',
      'tree_ggp_1b': 'Old',
      'tree_ggp_1b_1': 'New',
      'tree_s1_1': 'Léa',
      'tree_siblings': 'Max, Zoé\nNoé',
    });
    expect(book, {
      'tree_ggp_1a_1': 'Rose',
      'tree_ggp_1a_2': 'Paul',
      'tree_ggp_2b_1': 'Anna',
      'tree_ggp_2b_2': 'Ivan, Oleg',
      'tree_ggp_1b_1': 'New',
      'tree_s1_1': 'Léa',
      'tree_s1_2': 'Max',
      'tree_s1_3': 'Zoé',
      'tree_s1_4': 'Noé',
    });
  });

  test('relations say whose side and whose parent', () {
    final tree = FamilyTree({
      'tree_parent_1': 'Alex',
      'tree_parent_2': 'Sam',
      'tree_gp_1b': 'Rose',
      'tree_gp_2a': 'Jo',
      'tree_gp_2a_role': 'mother',
      'tree_a16': 'Ida',
      'tree_s1_1': 'Max',
      'tree_s1_1_role': 'brother',
      'tree_s1_2': 'Kim',
      'tree_s3_1': 'Lou',
      'tree_s3_1_role': 'sister',
      'tree_s5_1': 'Bea',
    }, {});
    expect(tree.relation('tree_parent_1'), 'Father');
    expect(tree.relation('tree_parent_2'), 'Mother');
    expect(tree.relation('tree_gp_1b'), "Grandmother on Dad's side");
    expect(tree.whose('tree_gp_1b'), "Alex's mother");
    expect(tree.relation('tree_gp_2a'), "Grandmother on Mom's side");
    expect(tree.relation('tree_ggp_2a_1'), "Great-grandfather on Mom's side");
    expect(tree.whose('tree_ggp_2a_1'), "Jo's father");
    expect(tree.relation('tree_a16'), "Great-great-grandfather on Dad's side");
    expect(tree.relation('tree_a32'), "3× great-grandfather on Dad's side");
    expect(tree.relation('tree_s1_1'), 'Brother');
    expect(tree.relation('tree_s1_2'), 'Brother or sister');
    expect(tree.relation('tree_s3_1'), "Aunt on Mom's side");
    expect(tree.whose('tree_s3_1'), "Sam's sister");
    expect(tree.relation('tree_s5_1'), "Great-aunt or great-uncle on Dad's side");
    expect(tree.siblings(1), ['tree_s1_1', 'tree_s1_2']);
    expect(tree.hasAncestorsAbove(2), isTrue);
    expect(tree.hasAncestorsAbove(2, past: 2), isTrue);
    expect(tree.hasAncestorsAbove(2, past: 3), isFalse);
    expect(tree.hasAncestorsAbove(3, past: 1), isFalse);
    expect(nextSibling(tree.book, 1), 3);
  });

  test('relations in French', () {
    useLanguage('fr');
    final tree = FamilyTree({'tree_parent_2': 'Sam', 'tree_gp_2b': 'Line'}, {});
    expect(tree.relation('tree_gp_2b'), 'Grand-mère du côté de maman');
    expect(tree.whose('tree_gp_2b'), 'Mère de Sam');
  });
}
