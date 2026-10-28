import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_bmi_detail.dart';
import 'package:track_children/features/growth/growth_repository.dart';
import 'package:track_children/features/growth/growth_stature_velocity.dart';
import 'package:track_children/features/growth/growth_stature_velocity_reference.dart';

class BmiVelocityRepo extends GrowthRepository {
  BmiVelocityRepo({this.empty = false});
  final bool empty;
  @override
  DateTime get dateOfBirth => DateTime(2024, 5, 15);
  @override
  Future<List<GrowthMetricViewData>> loadOverview() async => [];
  @override
  Future<List<GrowthMeasurementDraft>> weightMeasurements() async => empty
      ? []
      : [
          for (var i = 0; i < 3; i++)
            GrowthMeasurementDraft(
              value: [8.0, 8.4, 8.5][i],
              measuredAt: DateTime(2025, i + 1, 15),
            ),
        ];
  @override
  Future<List<GrowthMeasurementDraft>> measurements(
    GrowthMetric metric,
  ) async => [
    for (var i = 0; i < 3; i++)
      GrowthMeasurementDraft(
        value: [70.0, 71.0, 72.0][i],
        measuredAt: DateTime(2025, i + 1, 15),
        method: GrowthMeasurementMethod.recumbent,
      ),
  ];
  @override
  Future<GrowthStatureVelocityReference?> statureVelocityReference() =>
      throw StateError('BMI must never load stature velocity references');
  @override
  Future<GrowthStatureVelocityReference?> headVelocityReference() =>
      throw StateError('BMI must never load head velocity references');
}

void main() {
  testWidgets('BMI overview has no velocity tab or velocity screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: GrowthBmiDetailScreen(repository: BmiVelocityRepo())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tốc độ'), findsNothing);
    expect(find.byType(GrowthStatureVelocityTab), findsNothing);
    expect(find.text('BMI hiện tại'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
