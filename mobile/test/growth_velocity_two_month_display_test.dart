import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_repository.dart';
import 'package:track_children/features/growth/growth_weight_velocity.dart';
import 'package:track_children/features/growth/growth_weight_velocity_data.dart';

class _TwoMonthRepository extends GrowthRepository {
  _TwoMonthRepository({this.withPrevious = true});
  final bool withPrevious;
  @override
  DateTime get dateOfBirth => DateTime(2024, 1, 1);
  @override
  Future<List<GrowthMetricViewData>> loadOverview() async => [];
  @override
  Future<List<GrowthMeasurementDraft>> weightMeasurements() async => [];
  @override
  Future<List<GrowthWeightVelocityPoint>?> weightVelocityIntervals({
    int period = 1,
  }) async => [
    GrowthWeightVelocityPoint(
      10,
      800,
      DateTime(2024, 11, 1),
      DateTime(2025, 1, 1),
      intervalMonths: 2,
      fromKg: 5.6,
      toKg: 6.4,
    ),
    GrowthWeightVelocityPoint(
      9,
      999,
      DateTime(2024, 10, 1),
      DateTime(2024, 12, 1),
      intervalMonths: 2,
    ),
    if (withPrevious)
      GrowthWeightVelocityPoint(
        8,
        600,
        DateTime(2024, 9, 1),
        DateTime(2024, 11, 1),
        intervalMonths: 2,
        fromKg: 5,
        toKg: 5.6,
      ),
  ];
}

void main() {
  testWidgets(
    'no preceding two-month period does not compare the overlapping period',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GrowthWeightVelocityTab(
              repository: _TwoMonthRepository(withPrevious: false),
              readings: const [],
              initialPeriod: 2,
              initialAgeBand: 3,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('+800\u00A0g', findRichText: true), findsOneWidget);
      expect(find.text('Chưa có dữ liệu so sánh'), findsOneWidget);
      expect(find.text('Nhiều hơn 200\u00A0g'), findsNothing);
      expect(find.text('Ít hơn 199\u00A0g'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'filtered two-month UI shows 800 g and 200 g more, not overlapping gain',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GrowthWeightVelocityTab(
              repository: _TwoMonthRepository(),
              readings: const [],
              initialPeriod: 2,
              initialAgeBand: 3,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('+800\u00A0g', findRichText: true), findsOneWidget);
      expect(find.text('Nhiều hơn 200\u00A0g'), findsOneWidget);
      expect(find.text('so với kỳ trước'), findsOneWidget);
      await tester.ensureVisible(find.text('Vì sao có nhận xét này'));
      await tester.tap(find.text('Vì sao có nhận xét này'));
      await tester.pumpAndSettle();
      expect(find.text('Chu kỳ 2 tháng'), findsOneWidget);
      expect(find.text('6,4 kg'), findsOneWidget);
      expect(
        find.text('+200 g so với kỳ liền trước cùng độ dài.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
