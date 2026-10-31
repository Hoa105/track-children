import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_repository.dart';
import 'package:track_children/features/growth/growth_head_detail.dart';
import 'package:track_children/features/growth/weight_chart_view.dart';

class HeadRepo extends GrowthRepository {
  HeadRepo(this.reference, {this.empty = false});
  final GrowthWeightReference? reference;
  final bool empty;
  @override
  DateTime get dateOfBirth => DateTime(2024, 5, 15);
  @override
  Future<List<GrowthMetricViewData>> loadOverview() async => const [];
  @override
  Future<List<GrowthMeasurementDraft>> measurements(
    GrowthMetric metric,
  ) async => empty
      ? []
      : [
          GrowthMeasurementDraft(
            value: 44.2,
            measuredAt: DateTime(2025, 3, 15),
          ),
          GrowthMeasurementDraft(value: 45, measuredAt: DateTime(2025, 4, 15)),
        ];
  @override
  Future<GrowthWeightReference?> headAgeReference() async => reference;
}

void main() {
  final raw = jsonDecode(
    File('assets/data/who/head_for_age_curves.json').readAsStringSync(),
  );
  GrowthWeightReference reference(GrowthReferenceSex sex) =>
      GrowthWeightReference(
        sex: sex,
        rows: [
          for (final r in raw['tables'][sex.name])
            GrowthWeightReferenceRow((r[0] as num).toInt(), [
              for (final v in (r as List).skip(1)) (v as num).toDouble(),
            ]),
        ],
        sourceUrl: raw['sources'][sex.name]['url'],
        sourceHash: raw['sources'][sex.name]['sha256'],
      );
  test('Head WHO references cover 0–60 months for both sexes', () {
    for (final sex in GrowthReferenceSex.values) {
      final ref = reference(sex);
      expect(ref.rows.length, 61);
      expect(ref.rows.first.month, 0);
      expect(ref.rows.last.month, 60);
      expect(ref.sourceUrl, contains('head-circumference-for-age'));
      for (final row in ref.rows) {
        expect(row.weights.length, 5);
        for (var i = 1; i < 5; i++) {
          expect(row.weights[i], greaterThan(row.weights[i - 1]));
        }
      }
    }
  });
  testWidgets(
    'Head overview has one purple age chart and its own explanation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: GrowthHeadDetailScreen(
            repository: HeadRepo(reference(GrowthReferenceSex.boys)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Vòng đầu'), findsOneWidget);
      expect(find.text('45\u00A0cm'), findsOneWidget);
      expect(find.textContaining('Tăng 0,8\u00A0cm'), findsOneWidget);
      final chart = tester.widget<WeightChartView>(
        find.byType(WeightChartView),
      );
      expect(chart.points.length, 2);
      expect(chart.end, 60);
      expect(chart.unit, 'cm');
      expect(chart.metricName, 'Vòng đầu');
      expect(chart.breakAt, isNull);
      expect(chart.dataColor, const Color(0xFF9468B5));
      await tester.ensureVisible(find.text('Vì sao có nhận xét này?'));
      await tester.tap(find.text('Vì sao có nhận xét này?'));
      await tester.pumpAndSettle();
      expect(find.text('Căn cứ đánh giá theo WHO'), findsOneWidget);
      expect(
        find.textContaining('WHO 2007: vòng đầu theo tuổi'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Head overview handles narrow large text and empty data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: GrowthHeadDetailScreen(
            repository: HeadRepo(reference(GrowthReferenceSex.girls)),
            easyReadMode: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: GrowthHeadDetailScreen(
          key: const ValueKey('empty'),
          repository: HeadRepo(null, empty: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa có số đo vòng đầu'), findsOneWidget);
  });
}
