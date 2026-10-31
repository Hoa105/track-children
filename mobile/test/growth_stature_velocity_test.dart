import 'package:flutter/material.dart';

import 'dart:convert';
import 'dart:io';

import 'package:track_children/features/growth/growth_stature_velocity_reference.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_repository.dart';
import 'package:track_children/features/growth/growth_stature_detail.dart';
import 'package:track_children/features/growth/growth_stature_velocity.dart';
import 'package:track_children/features/growth/stature_velocity_data.dart';

class StatureVelocityRepo extends GrowthRepository {
  @override
  Future<StatureVelocityReference?> statureVelocityPeriodReference(
    int period,
  ) async => StatureVelocityReference.fromJson(
    jsonDecode(
      File('assets/data/who/stature_velocity_periods.json').readAsStringSync(),
    ),
    'boys',
    period,
  );
  @override
  Future<GrowthStatureVelocityReference?> statureVelocityReference() async =>
      GrowthStatureVelocityReference.fromJson(
        jsonDecode(
          File('assets/data/who/stature_velocity_2month.json')
              .readAsStringSync(),
        ),
        'boys',
      );
  @override
  DateTime get dateOfBirth => DateTime(2024, 5, 15);
  @override
  Future<List<GrowthMetricViewData>> loadOverview() async => [];
  @override
  Future<List<GrowthMeasurementDraft>> measurements(
    GrowthMetric metric,
  ) async => samples;
}

final samples = [
  GrowthMeasurementDraft(
    value: 70,
    measuredAt: DateTime(2025, 1, 15),
    method: GrowthMeasurementMethod.recumbent,
  ),
  GrowthMeasurementDraft(
    value: 72,
    measuredAt: DateTime(2025, 2, 15),
    method: GrowthMeasurementMethod.recumbent,
  ),
  GrowthMeasurementDraft(
    value: 73.5,
    measuredAt: DateTime(2025, 3, 15),
    method: GrowthMeasurementMethod.recumbent,
  ),
  GrowthMeasurementDraft(
    value: 75,
    measuredAt: DateTime(2025, 4, 15),
    method: GrowthMeasurementMethod.recumbent,
  ),
];
void main() {
  testWidgets('Bundled WHO reference loads for each repository sex', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final sex in GrowthReferenceSex.values) {
        final reference = await MockGrowthRepository(referenceSex: sex)
            .statureVelocityReference();
        expect(reference, isNotNull);
        expect(reference!.rows.length, 23);
        expect(
          reference.rows.first.low,
          sex == GrowthReferenceSex.boys ? 6.2 : 5.7,
        );
      }
    });
  });
  test('WHO reference preserves both sexes and interval domains', () {
    final json = jsonDecode(
      File('assets/data/who/stature_velocity_2month.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final boys = GrowthStatureVelocityReference.fromJson(json, 'boys');
    final girls = GrowthStatureVelocityReference.fromJson(json, 'girls');
    expect(boys.rows.length, 23);
    expect(boys.rows.first.start, 0);
    expect(boys.rows.last.start, 22);
    expect(boys.rows.first.low, 6.2);
    expect(boys.rows.first.high, 10.8);
    expect(girls.rows.first.low, 5.7);
    expect(girls.rows.first.high, 10.1);
    expect(
      () => GrowthStatureVelocityReference.fromJson({
        ...json,
        'unit': 'g',
      }, 'boys'),
      throwsFormatException,
    );
  });
  test('Two-month increments pair nonadjacent readings, accepting 22–24 recumbent only', () {
    final points = growthStatureMonthlyIncrements(
      samples,
      DateTime(2024, 5, 15),
      months: 2,
    );
    expect(points.map((p) => p.change), [3.5, 3]);
    expect(points.map((p) => p.startMonth), [8, 9]);
    final birth = DateTime(2023, 1, 1);
    final readings = [
      for (final month in [22, 24, 26])
        GrowthMeasurementDraft(
          value: 80 + month.toDouble(),
          measuredAt: DateTime(2023, 1 + month, 1),
          method: GrowthMeasurementMethod.recumbent,
        ),
    ];
    final valid = growthStatureMonthlyIncrements(readings, birth, months: 2);
    expect(valid.length, 1);
    expect(valid.single.startMonth, 22);
  });
  testWidgets('WHO mode changes units and shows two-month reference', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrowthStatureVelocityTab(
            repository: StatureVelocityRepo(),
            readings: samples,
            name: 'Chiều dài',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('+3\u00A0cm'), findsOneWidget);
    expect(find.byKey(const ValueKey('stature-period-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('stature-period-6')), findsOneWidget);
    expect(find.text('+1,5 cm/tháng'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test('Stature velocity preserves fractional cm and excludes mixed methods and irregular intervals', () {
    final points = growthStatureMonthlyIncrements(
      samples,
      DateTime(2024, 5, 15),
    );
    expect(points.map((p) => p.change), [2, 1.5, 1.5]);
    expect(
      growthStatureMonthlyIncrements([
        samples.first,
        samples.last,
      ], DateTime(2024, 5, 15)),
      isEmpty,
    );
    expect(
      growthStatureMonthlyIncrements([
        samples.first,
        GrowthMeasurementDraft(
          value: 72,
          measuredAt: DateTime(2025, 2, 15),
          method: GrowthMeasurementMethod.standing,
        ),
      ], DateTime(2024, 5, 15)),
      isEmpty,
    );
    expect(growthStatureMonthlyIncrements(samples, null), isEmpty);
  });
  testWidgets(
    'Stature speed tab opens with cm notes and separate explanation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GrowthStatureDetailScreen(repository: StatureVelocityRepo()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tốc độ'));
      await tester.pumpAndSettle();
      expect(find.byType(GrowthStatureVelocityTab), findsOneWidget);
      expect(find.text('+3\u00A0cm'), findsOneWidget);
      expect(find.text('Chưa có dữ liệu so sánh'), findsOneWidget);
      await tester.ensureVisible(find.text('Vì sao có nhận xét này?'));
      await tester.tap(find.text('Vì sao có nhận xét này?'));
      await tester.pumpAndSettle();
      expect(find.text('Chu kỳ 2 tháng'), findsOneWidget);
      expect(find.textContaining('(75 − 72)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Stature velocity supports narrow large text and empty state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: GrowthStatureVelocityTab(
              repository: StatureVelocityRepo(),
              readings: samples,
              name: 'Chiều dài',
              easyRead: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrowthStatureVelocityTab(
            repository: StatureVelocityRepo(),
            readings: const [],
            name: 'Chiều cao',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa đủ số đo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
