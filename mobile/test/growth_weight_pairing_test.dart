import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_models.dart';
import 'package:track_children/features/growth/growth_weight_velocity_data.dart';

void main() {
  GrowthMeasurementDraft reading(DateTime date, double kg) =>
      GrowthMeasurementDraft(value: kg, measuredAt: date);

  test('WHO early periods use 28 days and ignore intervening readings', () {
    final birth = DateTime(2024, 1, 31);
    final rows = [
      reading(birth, 3),
      reading(DateTime(2024, 2, 10), 3.2),
      reading(DateTime(2024, 2, 28), 3.8),
      reading(DateTime(2024, 2, 29), 3.9),
      reading(DateTime(2024, 3, 31), 4.5),
    ];
    final points = growthWeightMonthlyIncrements(rows, birth);
    expect(points.length, 2);
    expect(points.first.to, DateTime(2024, 2, 28));
    expect(points.last.from, DateTime(2024, 2, 28));
    expect(points.first.grams, closeTo(800, .001));
    expect(points.last.grams, closeTo(700, .001));
    expect(points.first.endAge, points.last.startAge);
  });

  test('all longer periods include exact 24 months but no later period', () {
    final birth = DateTime(2024, 1, 31);
    final rows = [
      for (var m = 0; m <= 26; m++)
        reading(
          DateTime(2024, 1 + m, DateTime(2024, 2 + m, 0).day),
          12 - m * .1,
        ),
    ];
    for (final period in [2, 3, 4, 6]) {
      final points = growthWeightPeriodIncrements(rows, birth, period);
      expect(points.length, 25 - period);
      expect(points.last.to, DateTime(2026, 1, 31));
      expect(points.last.intervalMonths, period);
      expect(points.last.grams, closeTo(-100 * period, .001));
    }
    expect(
      () => growthWeightPeriodIncrements(rows, birth, 5),
      throwsArgumentError,
    );
  });
}
