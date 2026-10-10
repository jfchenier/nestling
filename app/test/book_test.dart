import 'package:flutter_test/flutter_test.dart';
import 'package:nestling/api/api.dart';
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
    expect(milestoneIdeas.map((i) => i.name.toLowerCase()).toSet().length, milestoneIdeas.length, reason: 'idea names are unique');
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

  test('memories before birth say how far along', () {
    final c = Child({'id': 'c', 'birth_date': '2026-05-20', 'book': {'due_date': '2026-05-27'}});
    expect(pregnancyWeeks(c, DateTime(2026, 1, 7, 15)), '20 weeks along');
    expect(pregnancyWeeks(Child({'id': 'c', 'birth_date': '2026-05-20'}), DateTime(2026, 1, 7)), '19 weeks before birth');
    expect(pregnancyWeeks(c, DateTime(2026, 5, 20)), isNull);
  });
}
