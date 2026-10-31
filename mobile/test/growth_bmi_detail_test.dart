import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_bmi_detail.dart';
import 'package:track_children/features/growth/growth_repository.dart';
import 'package:track_children/features/growth/weight_chart_view.dart';

class BmiRepo extends GrowthRepository {
  BmiRepo({this.empty = false});
  final bool empty;
  @override
  DateTime get dateOfBirth => DateTime(2024, 5, 15);
  @override
  Future<List<GrowthMetricViewData>> loadOverview() async => [];
  @override
  Future<List<GrowthMeasurementDraft>> weightMeasurements() async => empty
      ? []
      : [
          GrowthMeasurementDraft(value: 8.2, measuredAt: DateTime(2025, 3, 15)),
          GrowthMeasurementDraft(
            value: 8.5,
            measuredAt: DateTime(2025, 4, 15, 9),
          ),
          GrowthMeasurementDraft(value: 9, measuredAt: DateTime(2025, 4, 16)),
          GrowthMeasurementDraft(value: 0, measuredAt: DateTime(2025, 4, 17)),
        ];
  @override
  Future<List<GrowthMeasurementDraft>> measurements(
    GrowthMetric metric,
  ) async => [
    GrowthMeasurementDraft(
      value: 73.5,
      measuredAt: DateTime(2025, 3, 15),
      method: GrowthMeasurementMethod.recumbent,
    ),
    GrowthMeasurementDraft(
      value: 75,
      measuredAt: DateTime(2025, 4, 15, 14),
      method: GrowthMeasurementMethod.recumbent,
    ),
    GrowthMeasurementDraft(
      value: 76,
      measuredAt: DateTime(2025, 4, 17),
      method: GrowthMeasurementMethod.recumbent,
    ),
  ];
  @override
  Future<GrowthWeightReference?> bmiAgeReference(bool length) async {
    final raw = jsonDecode(File('assets/data/who_bmi.json').readAsStringSync());
    final all = raw['boys'] as List;
    return GrowthWeightReference(
      sex: GrowthReferenceSex.boys,
      rows: [
        for (final row in length ? all.take(25) : all.skip(25))
          GrowthWeightReferenceRow(row[0], [
            for (final i in [4, 5, 7, 9, 10]) (row[i] as num).toDouble(),
          ]),
      ],
      sourceUrl: raw['source'],
      sourceHash: '',
    );
  }
}

void main() {
  test('BMI pairs valid measurements on the same calendar day only', () async {
    final points = await BmiRepo().bmiMeasurements();
    expect(points.length, 2);
    expect(points.last.value, closeTo(8.5 / (.75 * .75), 1e-10));
    expect(points.last.method, GrowthMeasurementMethod.recumbent);
  });
  test(
    'BMI keeps distinct WHO length and height tables at 24 months',
    () async {
      final length = (await BmiRepo().bmiAgeReference(true))!;
      final height = (await BmiRepo().bmiAgeReference(false))!;
      expect(length.rows.length, 25);
      expect(height.rows.length, 37);
      expect(length.rows.last.month, 24);
      expect(height.rows.first.month, 24);
      expect(length.rows.last.weights[2], isNot(height.rows.first.weights[2]));
    },
  );
  testWidgets('BMI overview has one fitted age chart and its own explanation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: GrowthBmiDetailScreen(repository: BmiRepo())),
    );
    await tester.pumpAndSettle();
    final chart = tester.widget<WeightChartView>(find.byType(WeightChartView));
    expect(chart.points.length, 2);
    expect(chart.unit, 'kg/m²');
    expect(chart.metricName, 'BMI');
    expect(chart.end, 60);
    expect(chart.curves.length, 62);
    expect(chart.breakAt, weightAgeTick(24));
    await tester.ensureVisible(find.text('Vì sao có nhận xét này?'));
    await tester.tap(find.text('Vì sao có nhận xét này?'));
    await tester.pumpAndSettle();
    expect(find.text('Căn cứ đánh giá theo WHO'), findsOneWidget);
    expect(find.text('Cách xác định BMI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('BMI handles narrow large text and missing paired measurements', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: GrowthBmiDetailScreen(
            repository: BmiRepo(),
            easyReadMode: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: GrowthBmiDetailScreen(
          key: const ValueKey('empty'),
          repository: BmiRepo(empty: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa đủ số đo cùng ngày để tính BMI'), findsOneWidget);
    expect(find.byType(WeightChartView), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
