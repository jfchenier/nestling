import 'package:flutter_test/flutter_test.dart';
import 'package:nestling/api/api.dart';
import 'package:nestling/l10n/l10n.dart';
import 'package:nestling/local/domain.dart';
import 'package:nestling/models.dart';
import 'package:nestling/screens/baby_book.dart';
import 'package:nestling/screens/book_pages.dart';

void main() {
  test('the moon phase on a few known days', () {
    expect(moonPhase(DateTime.utc(2024, 1, 11, 12)).name, 'New moon');
    expect(moonPhase(DateTime.utc(2024, 1, 25, 18)).name, 'Full moon');
    expect(moonPhase(DateTime.utc(2024, 1, 18, 3)).name, 'First quarter');
    expect(moonPhase(DateTime.utc(2024, 1, 25, 18)).lit, greaterThan(0.99));
  });

  test('birth time comes from the book, noon without one', () {
    final c = Child({'id': 'c', 'birth_date': '2026-05-20', 'book': {'birth_time': '14:32'}});
    expect(bornAt(c), DateTime(2026, 5, 20, 14, 32));
    expect(bornAt(Child({'id': 'c', 'birth_date': '2026-05-20'})), DateTime(2026, 5, 20, 12));
  });

  test('growth month by month takes the closest measurement per month', () {
    final c = Child({'id': 'c', 'birth_date': '2026-01-10'});
    Event g(String day, {num? w, num? l}) => Event({'id': day, 'type': 'growth', 'start': '${day}T10:00:00-05:00', 'weight_g': ?w, 'length_cm': ?l});
    final rows = growthByMonth(c, [
      g('2026-01-10', w: 3400, l: 50),
      g('2026-02-05', w: 4000),
      g('2026-02-12', w: 4300),
      g('2026-04-11', l: 60),
    ]);
    expect(rows, [(0, 3400, 50, null), (1, 4300, null, null), (3, null, 60, null)]);
  });

  test('book pages: empty texts dropped, keys and values checked like the server', () {
    expect(checkBook({'birth_place': ' Home ', 'hair': '', 'eyes': null}), {'birth_place': 'Home'});
    expect(() => checkBook({'Bad Key': 'x'}), throwsA(isA<ApiException>()));
    expect(() => checkBook({'n': 3}), throwsA(isA<ApiException>()));
    expect(() => checkBook({'n': 'x' * 4001}), throwsA(isA<ApiException>()));
  });

  test('a milestone may name its chapter, like the server', () {
    expect(normalizeDetails({'type': 'milestone', 'name': 'Snow', 'chapter': 'celebrations'})['chapter'], 'celebrations');
    expect(() => normalizeDetails({'type': 'milestone', 'name': 'Snow', 'chapter': 'Attic!'}), throwsA(isA<ApiException>()));
  });

  test('memories find their chapter', () {
    expect(BookChapter.values.every((c) => validChapter(c.id)), isTrue);
    expect(chapterOf(Event({'name': 'Moved', 'chapter': 'from_a_newer_app'})), BookChapter.firsts);
    expect(milestoneIdeas.map((i) => i.id.toLowerCase()).toSet().length, milestoneIdeas.length, reason: 'idea names are unique');
    expect(chapterOf(Event({'name': 'First Christmas'})), BookChapter.celebrations);
    expect(chapterOf(Event({'name': 'came home'})), BookChapter.hello);
    expect(chapterOf(Event({'name': 'First tooth'})), BookChapter.growing);
    expect(chapterOf(Event({'name': 'Our own thing'})), BookChapter.firsts);
    expect(chapterOf(Event({'name': 'banana for scale'})), BookChapter.growing);
    expect(chapterOf(Event({'name': 'First Christmas', 'chapter': 'firsts'})), BookChapter.firsts);
  });

  test('a memory without a chapter dated before birth is in Waiting for you', () {
    final birth = DateTime(2026, 5, 20);
    expect(chapterOf(Event({'name': 'Painted the room', 'start': '2026-03-01T10:00:00-05:00'}), birth: birth), BookChapter.waiting);
    expect(chapterOf(Event({'name': 'Painted the room', 'start': '2026-05-20T01:00:00-04:00'}), birth: birth), BookChapter.firsts);
    expect(chapterOf(Event({'name': 'Came home', 'start': '2026-03-01T10:00:00-05:00'}), birth: birth), BookChapter.hello);
    expect(chapterOf(Event({'name': 'Retour à la maison', 'chapter': 'hello', 'start': '2026-05-23T10:00:00-04:00'}), birth: birth), BookChapter.hello);
  });

  test('every chapter offers a few ideas', () {
    for (final c in BookChapter.values) {
      expect(milestoneIdeas.where((i) => i.chapter == c).length, greaterThanOrEqualTo(4), reason: c.title);
    }
  });

  test('ideas are matched in any language and saved under their English name', () {
    // Every language's name finds its own idea (no name is shared by two ideas).
    for (final locale in AppLocalizations.supportedLocales) {
      useLanguage(locale.languageCode);
      for (final i in milestoneIdeas) {
        expect(ideaFor(i.label)?.id, i.id, reason: '${locale.languageCode}: ${i.label}');
      }
    }
    useLanguage('en');
    expect(ideaFor('Première dent')?.id, 'First tooth');
    expect(isFirstTooth('primer diente'), isTrue);
    expect(storedMemoryName(' Premier Noël '), 'First Christmas');
    expect(storedMemoryName('Une banane pour comparer'), bananaName);
    expect(storedMemoryName('Our own thing'), 'Our own thing');
    expect(isBanana(Event({'name': 'Un plátano de referencia'})), isTrue);
  });

  test('memories before birth say how far along', () {
    final c = Child({'id': 'c', 'birth_date': '2026-05-20', 'book': {'due_date': '2026-05-27'}});
    expect(pregnancyWeeks(c, DateTime(2026, 1, 7, 15)), '20 weeks along');
    expect(pregnancyWeeks(Child({'id': 'c', 'birth_date': '2026-05-20'}), DateTime(2026, 1, 7)), '19 weeks before birth');
    expect(pregnancyWeeks(c, DateTime(2026, 5, 20)), isNull);
  });

  test('zodiac signs at the edges', () {
    expect(zodiacSign(DateTime(2026, 1, 1)), 'capricorn');
    expect(zodiacSign(DateTime(2026, 1, 20)), 'aquarius');
    expect(zodiacSign(DateTime(2026, 3, 20)), 'pisces');
    expect(zodiacSign(DateTime(2026, 3, 21)), 'aries');
    expect(zodiacSign(DateTime(2026, 10, 13)), 'libra');
    expect(zodiacSign(DateTime(2026, 12, 22)), 'capricorn');
    expect(l10n.pagesZodiacSign('libra'), 'Libra');
  });

  test('the new family ideas find their chapters', () {
    expect(chapterOf(Event({'name': 'Our wedding', 'start': '2019-06-01T10:00:00Z'})), BookChapter.family);
    expect(chapterOf(Event({'name': 'The nursery'})), BookChapter.waiting);
    expect(chapterOf(Event({'name': 'first cold'})), BookChapter.firsts);
    expect(isDiary(Event({'name': 'diary'})), isTrue);
  });

  test('our homes say how long we lived there', () {
    Event home(String id, String day) => Event({'id': id, 'type': 'milestone', 'name': 'Our home', 'start': '${day}T10:00:00Z'});
    final spans = homeSpans([home('b', '2022-03-01'), home('a', '2018-01-15')], now: DateTime(2026, 10, 13));
    expect(spans, {'a': 'Lived here 4 years', 'b': 'Here for 4 years'});
    expect(homeSpans([home('c', '2026-09-01')], now: DateTime(2026, 10, 13)), {'c': 'Here for 1 month'});
  });

  test('a memory long before birth shows only its date', () {
    final c = Child({'id': 'c', 'birth_date': '2026-05-20'});
    expect(pregnancyWeeks(c, DateTime(2026, 3, 1)), '11 weeks before birth');
    expect(pregnancyWeeks(c, DateTime(2019, 6, 1)), isNull);
  });

  test('time at the hospital, up to Came home', () {
    final c = Child({'id': 'c', 'birth_date': '2026-05-20'});
    expect(BirthStoryPage.hospitalStay(c, DateTime(2026, 5, 23, 15)), '3 days');
    expect(BirthStoryPage.hospitalStay(c, DateTime(2026, 5, 20, 18)), 'Home the same day');
    expect(BirthStoryPage.hospitalStay(c, null), isNull);
  });

  test("the diary's schedule from the past week", () {
    Event sleep(String start, String end) => Event({'id': start, 'type': 'sleep', 'start': start, 'end': end});
    final lines = scheduleLines(
      [
        sleep('2026-10-10T19:30:00', '2026-10-11T06:55:00'),
        sleep('2026-10-11T09:30:00', '2026-10-11T10:30:00'), // a nap
        sleep('2026-10-11T19:40:00', '2026-10-11T23:00:00'),
        sleep('2026-10-11T23:20:00', '2026-10-12T07:10:00'),
        sleep('2026-10-12T15:30:00', '2026-10-12T17:05:00'), // a long late nap is not bedtime
        sleep('2026-10-12T19:20:00', '2026-10-13T07:05:00'),
      ],
      {'naps_per_day': 2.6, 'day_sleep_seconds_per_day': 9600, 'night_sleep_seconds_per_day': 39000, 'feeds_per_day': 7.2},
    );
    expect(lines, [
      'Wakes up around 07:05',
      '3 naps a day (2h 40m in all)',
      'Bedtime around 19:30',
      '10h 50m of sleep at night',
      '7 feeds a day',
    ]);
    expect(scheduleLines(const [], const {}), isEmpty);
  });
}
