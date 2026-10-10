import 'package:flutter_test/flutter_test.dart';
import 'package:nestling/screens/teeth_chart.dart';

void main() {
  test('the 20 baby teeth have their usual letters and names', () {
    expect(babyTeeth.map((t) => t.code).join(), 'ABCDEFGHIJKLMNOPQRST');
    expect(toothFor('A')!.name, 'Upper right second molar');
    expect(toothFor('E')!.name, 'Upper right central incisor');
    expect(toothFor('F')!.name, 'Upper left central incisor');
    expect(toothFor('K')!.name, 'Lower left second molar');
    expect(toothFor('O')!.name, 'Lower left central incisor');
    expect(toothFor('P')!.name, 'Lower right central incisor');
    expect(toothFor('T')!.name, 'Lower right second molar');
    expect(toothFor('O')!.when, '6–10 months');
  });
}
