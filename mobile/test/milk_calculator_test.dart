import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/services/milk_calculator.dart';

void main() {
  test('daily volume is unchanged by dividing into different feed counts', () {
    expect(estimateMilk(3.2, 8).dailyMl, 480);
    expect(estimateMilk(3.2, 8).perFeedMl, 60);
    expect(estimateMilk(3.2, 6).dailyMl, 480);
    expect(estimateMilk(3.2, 6).perFeedMl, 80);
    expect(() => estimateMilk(double.nan, 8), throwsArgumentError);
    expect(() => estimateMilk(3, 0), throwsArgumentError);
  });

  test('eligibility handles first week, calendar months and risk factors', () {
    String? check({
      DateTime? birth,
      double kg = 3,
      bool healthy = true,
      bool bottle = true,
    }) => milkEligibility(
      birthDate: birth ?? DateTime(2026, 10, 9),
      today: DateTime(2026, 10, 16),
      weightKg: kg,
      healthyFullTerm: healthy,
      exclusivelyBottleFed: bottle,
    );
    expect(check(), isNull);
    expect(check(birth: DateTime(2026, 10, 10)), isNotNull);
    expect(check(birth: DateTime(2026, 4, 16)), isNotNull);
    expect(check(birth: DateTime(2026, 4, 17)), isNull);
    expect(check(kg: 2.49), isNotNull);
    expect(check(kg: 2.5), isNull);
    expect(check(healthy: false), isNotNull);
    expect(check(bottle: false), isNotNull);
    expect(check(kg: double.infinity), isNotNull);
  });
}
