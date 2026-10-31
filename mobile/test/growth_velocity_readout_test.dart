import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_velocity_tooltip.dart';
import 'package:track_children/features/growth/growth_weight_velocity_data.dart';
import 'package:track_children/features/growth/growth_weight_velocity_summary.dart';

void main() {
  test('two-month gain comparison uses adjacent periods even with unsorted overlaps', () {
    final previous = GrowthWeightVelocityPoint(
      2,
      600.49,
      DateTime(2025, 3, 1),
      DateTime(2025, 5, 1),
      intervalMonths: 2,
    );
    final overlap = GrowthWeightVelocityPoint(
      3,
      999,
      DateTime(2025, 4, 1),
      DateTime(2025, 6, 1),
      intervalMonths: 2,
    );
    final current = GrowthWeightVelocityPoint(
      4,
      800.51,
      DateTime(2025, 5, 1),
      DateTime(2025, 7, 1),
      intervalMonths: 2,
    );
    final summary = GrowthVelocitySummary([current, overlap, previous]);
    expect(summary.latest, current);
    expect(summary.previous, previous);
    expect(summary.delta, 200);
    expect(GrowthVelocitySummary([overlap, current]).delta, isNull);
  });
  test(
    'readout keeps actual increment and suppresses WHO score outside scope',
    () {
      final point = GrowthWeightVelocityPoint(
        25,
        -120,
        DateTime(2026, 1, 1),
        DateTime(2026, 2, 3),
        intervalMonths: 0,
        referenceStatus: 'REFERENCE_NOT_APPLICABLE',
        referenceReason: 'OUT_OF_SCOPE_AGE',
        fromKg: 12,
        toKg: 11.88,
        elapsedDays: 33,
        zScore: 1,
      );
      final text = growthVelocityTooltip(point, previewZ: 2).toPlainText();
      expect(text, contains('Giảm 120 g'));
      expect(text, contains('12 kg'));
      expect(text, contains('11,88 kg'));
      expect(text, contains('33 ngày'));
      expect(text, contains('Chỉ ghi nhận'));
      expect(text, isNot(contains('Z-score')));
    },
  );
  test('six-month comparison skips overlapping periods', () {
    final previous = GrowthWeightVelocityPoint(
      0,
      1000,
      DateTime(2024, 1, 1),
      DateTime(2024, 7, 1),
      intervalMonths: 6,
    );
    final overlap = GrowthWeightVelocityPoint(
      1,
      1200,
      DateTime(2024, 2, 1),
      DateTime(2024, 8, 1),
      intervalMonths: 6,
    );
    final current = GrowthWeightVelocityPoint(
      6,
      800,
      DateTime(2024, 7, 1),
      DateTime(2025, 1, 1),
      intervalMonths: 6,
    );
    expect(GrowthVelocitySummary([previous, overlap, current]).delta, -200);
    expect(GrowthVelocitySummary([overlap, current]).delta, isNull);
  });
}
