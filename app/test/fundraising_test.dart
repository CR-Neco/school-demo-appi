import 'package:flutter_test/flutter_test.dart';
import 'package:appi/fundraising.dart';

void main() {
  test('Totals come from cents, not an inconsistent backend percentage', () {
    final data = Fundraising.fromJson({'target_cents': 10000, 'raised_cents': 2500, 'progress_percent': 99});
    expect(data.percent, 25);
    expect(data.barValue, 0.25);
    expect(data.remainingCents, 7500);
  });
  test('Overfunding preserves actual percentage while capping the bar', () {
    const data = Fundraising(targetCents: 10000, raisedCents: 12500);
    expect(data.percent, 125);
    expect(data.barValue, 1);
    expect(data.remainingCents, 0);
  });
  test('Expenses may leave a negative balance without a negative bar', () {
    const data = Fundraising(targetCents: 10000, raisedCents: -2500);
    expect(data.percent, -25);
    expect(data.barValue, 0);
    expect(data.remainingCents, 12500);
    expect(euro(data.raisedCents), '−25,00 €');
  });
  test('Invalid target never divides by zero', () {
    for (final target in [0, -100]) {
      final data = Fundraising(targetCents: target, raisedCents: 100);
      expect(data.hasTarget, isFalse);
      expect(data.percent, isNull);
      expect(data.barValue, 0);
    }
  });
  test('Missing or fractional money is rejected rather than guessed', () {
    expect(() => Fundraising.fromJson({'target_cents': 10000}), throwsFormatException);
    expect(() => Fundraising.fromJson({'target_cents': 10000, 'raised_cents': 12.5}), throwsFormatException);
  });
  test('German currency and percent labels', () {
    expect(euro(1500000), '15.000,00 €');
    expect(euro(101), '1,01 €');
    expect(percentLabel(12.345), '12,3 %');
  });
}
