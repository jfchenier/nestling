import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nestling/format.dart';
import 'package:nestling/l10n/l10n.dart';
import 'package:nestling/models.dart';
import 'package:nestling/theme.dart';

void main() {
  tearDown(() => useLanguage('en'));

  test('every language has every text', () {
    Set<String> keys(String lang) =>
        (jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>).keys.where((k) => !k.startsWith('@')).toSet();
    final en = keys('en');
    for (final lang in ['fr', 'es']) {
      expect(en.difference(keys(lang)), isEmpty, reason: 'missing in $lang');
      expect(keys(lang).difference(en), isEmpty, reason: 'extra in $lang');
    }
  });

  test('French and Spanish labels and formats', () {
    final e = Event({'type': 'feed', 'method': 'breast', 'start': '2026-10-08T10:00:00Z', 'left_seconds': 600, 'right_seconds': 300, 'start_side': 'left'});
    useLanguage('fr');
    expect(Kind.bottle.label, 'Biberon');
    expect(duration(3900), '1 h 05');
    expect(ago(3 * 86400), 'il y a 3 jours');
    expect(cap('crib'), 'Lit de bébé');
    expect(describe(e, const Units(false)), ('Allaitement', 'G 10 min · D 5 min · fini D'));
    useLanguage('es');
    expect(Kind.diaper.label, 'Pañal');
    expect(ago(7200), 'hace 2 h 00 min');
    expect(cap('tummy_time'), 'Tiempo boca abajo');
    expect(cap('something_else'), 'Something else');
  });
}
