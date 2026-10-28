import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_repository.dart';
import 'package:track_children/features/growth/growth_stature_detail.dart';
import 'package:track_children/features/growth/growth_weight_detail.dart';
import 'package:track_children/features/growth/growth_stature_age_axis.dart';

class StatureRepo extends GrowthRepository {
  StatureRepo(this.reference, {this.height = false, this.fail = false});
  final GrowthWeightReference? reference;
  final bool height, fail;
  @override
  DateTime get dateOfBirth => DateTime(2024, 5, 15);
  @override
  Future<List<GrowthMetricViewData>> loadOverview() async => const [];
  @override
  Future<List<GrowthMeasurementDraft>> measurements(GrowthMetric metric) async {
    if (fail) throw StateError('fixture');
    return [
      GrowthMeasurementDraft(
        value: height ? 88 : 73.5,
        measuredAt: DateTime(height ? 2026 : 2025, 3, 15),
        method: height
            ? GrowthMeasurementMethod.standing
            : GrowthMeasurementMethod.recumbent,
      ),
      GrowthMeasurementDraft(
        value: height ? 90 : 75,
        measuredAt: DateTime(height ? 2026 : 2025, height ? 6 : 4, 15),
        method: height
            ? GrowthMeasurementMethod.standing
            : GrowthMeasurementMethod.recumbent,
      ),
    ];
  }

  @override
  Future<GrowthWeightReference?> statureAgeReference(bool length) async =>
      reference;
}

void main() {
  test('Stature axis uses rounded cm ticks around the visible readings and reference', () {
    final axis = growthStatureAgeAxis([65.2, 73.5, 75, 82.7]);
    expect(axis.min, greaterThan(0));
    expect(axis.min, lessThanOrEqualTo(65.2));
    expect(axis.max, greaterThanOrEqualTo(82.7));
    expect(axis.step, 5);
    expect(
      (axis.max - axis.min) / axis.step,
      closeTo(((axis.max - axis.min) / axis.step).round(), .00001),
    );
    final full = growthStatureAgeAxis([43, 102]);
    expect(full.min, lessThanOrEqualTo(43));
    expect(full.max, greaterThanOrEqualTo(102));
  });
  final raw = jsonDecode(
    File('assets/data/who/stature_for_age_curves.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  GrowthWeightReference reference(bool length) {
    final key = '${length ? 'length' : 'height'}_boys';
    return GrowthWeightReference(
      sex: GrowthReferenceSex.boys,
      rows: [
        for (final r in raw['tables'][key])
          GrowthWeightReferenceRow((r[0] as num).toInt(), [
            for (final v in (r as List).skip(1)) (v as num).toDouble(),
          ]),
      ],
      sourceUrl: raw['sources'][key]['url'],
      sourceHash: raw['sources'][key]['sha256'],
    );
  }

  test('WHO length/height tables retain separate 24-month measurements', () {
    expect(growthStatureName(23.99), 'Chiều dài');
    expect(growthStatureName(24), 'Chiều cao');
    expect(reference(true).rows.length, 25);
    expect(reference(false).rows.length, 37);
    expect(reference(true).rows.last.weights[2], 87.8);
    expect(reference(false).rows.first.weights[2], 87.1);
  });
  testWidgets(
    'Stature overview changes naming, keeps only one age chart and opens explanation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final height in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            home: GrowthStatureDetailScreen(
              key: ValueKey(height),
              repository: StatureRepo(reference(!height), height: height),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(height ? 'Chiều cao' : 'Chiều dài'), findsOneWidget);
        expect(find.byType(GrowthWeightMeasurementChart), findsOneWidget);
        final chart = tester.widget<GrowthWeightMeasurementChart>(
          find.byType(GrowthWeightMeasurementChart),
        );
        expect(chart.unit, 'cm');
        expect(chart.seriesColor, const Color(0xFF4B92C6));
        expect(chart.points.length, height ? 1 : 2);
        await tester.ensureVisible(find.text('Vì sao có kết luận này?'));
        await tester.tap(find.text('Vì sao có kết luận này?'));
        await tester.pumpAndSettle();
        expect(find.text('Căn cứ đánh giá'), findsOneWidget);
        await tester.tap(find.byTooltip('Quay lại'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets('Narrow large-text layout and loading error', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: GrowthStatureDetailScreen(
            repository: StatureRepo(reference(true)),
            easyReadMode: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: GrowthStatureDetailScreen(
          key: const ValueKey('error'),
          repository: StatureRepo(null, fail: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa tải được số đo.'), findsOneWidget);
  });
}
