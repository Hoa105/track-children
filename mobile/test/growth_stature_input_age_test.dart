import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_weight_input.dart';
import 'package:track_children/features/growth/growth_repository.dart';

void main() {
  for (final date in [
    DateTime(2026, 5, 14),
    DateTime(2026, 5, 15),
    DateTime(2026, 5, 16),
  ]) {
    testWidgets('Stature input selects name and method at $date', (
      tester,
    ) async {
      GrowthMeasurementDraft? draft;
      final length = date.isBefore(DateTime(2026, 5, 15));
      await tester.pumpWidget(
        MaterialApp(
          home: GrowthWeightInputScreen(
            repository: MockGrowthRepository(),
            metric: GrowthMetric.lengthHeight,
            initialDate: date,
            onContinue: (value) => draft = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(length ? 'Cập nhật chiều dài' : 'Cập nhật chiều cao'),
        findsOneWidget,
      );
      expect(find.text('Cách đo'), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(draft, isNotNull);
      expect(
        draft!.method,
        length
            ? GrowthMeasurementMethod.recumbent
            : GrowthMeasurementMethod.standing,
      );
      expect(draft!.measuredAt, date);
      expect(tester.takeException(), isNull);
    });
  }
}
