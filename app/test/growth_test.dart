import 'package:flutter_test/flutter_test.dart';
import 'package:nestling/growth/percentiles.dart';

void main() {
  test('WHO medians at birth', () {
    expect(WhoStandard(GrowthIndicator.weight, 'female').valueAt(0, 0), closeTo(3.2322, 1e-4));
    expect(WhoStandard(GrowthIndicator.weight, 'male').valueAt(0, 0), closeTo(3.3464, 1e-4));
    expect(WhoStandard(GrowthIndicator.length, 'male').valueAt(0, 0), closeTo(49.8842, 1e-4));
    expect(WhoStandard(GrowthIndicator.head, 'female').valueAt(0, 0), closeTo(33.8787, 1e-4));
  });

  test('a median measurement is the 50th percentile', () {
    final w = WhoStandard(GrowthIndicator.weight, 'female');
    expect(w.percentile(100, w.valueAt(100, 0)!), closeTo(50, 0.01));
    expect(w.percentile(100, w.valueAt(100, 1.2816)!), closeTo(90, 0.05));
  });

  test('girl, 2 months 5 days, 4.55 kg is about the 13th percentile', () {
    final p = WhoStandard(GrowthIndicator.weight, 'female').percentile(66, 4.55)!;
    expect(p, inInclusiveRange(11, 15));
  });

  test('labels', () {
    expect(percentileLabel(13.2), '13th');
    expect(percentileLabel(1.4), '1st');
    expect(percentileLabel(22), '22nd');
    expect(percentileLabel(11), '11th');
    expect(percentileLabel(0.3), '<1st');
  });

  test('no values past 24 months', () => expect(WhoStandard(GrowthIndicator.weight, 'male').lms(800), isNull));
}
