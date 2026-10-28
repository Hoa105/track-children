import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_repository.dart';
import 'package:track_children/features/growth/growth_stature_detail.dart';
import 'package:track_children/features/growth/growth_head_detail.dart';
import 'package:track_children/features/growth/growth_bmi_detail.dart';
import 'package:track_children/features/growth/growth_weight_history.dart';

class MetricHistoryRepo extends GrowthRepository {
  @override
  DateTime get dateOfBirth => DateTime(2024, 5, 15);
  @override
  Future<List<GrowthMetricViewData>> loadOverview() async => [];
  @override
  Future<List<GrowthMeasurementDraft>> weightMeasurements() async => [
    GrowthMeasurementDraft(value: 8.2, measuredAt: DateTime(2025, 3, 15)),
    GrowthMeasurementDraft(value: 8.5, measuredAt: DateTime(2025, 4, 15)),
  ];
  @override
  Future<List<GrowthMeasurementDraft>> measurements(
    GrowthMetric metric,
  ) async => [
    GrowthMeasurementDraft(
      value: metric == GrowthMetric.headCircumference ? 44.2 : 73.5,
      measuredAt: DateTime(2025, 3, 15),
      method: metric == GrowthMetric.headCircumference
          ? null
          : GrowthMeasurementMethod.recumbent,
    ),
    GrowthMeasurementDraft(
      value: metric == GrowthMetric.headCircumference ? 45 : 75,
      measuredAt: DateTime(2025, 4, 15),
      method: metric == GrowthMetric.headCircumference
          ? null
          : GrowthMeasurementMethod.recumbent,
    ),
  ];
}

void main() {
  for (final metric in ['length', 'head', 'bmi']) {
    testWidgets(
      '$metric history opens, shows its own units and newest-first details',
      (tester) async {
        final repo = MetricHistoryRepo();
        final screen = metric == 'bmi'
            ? GrowthBmiDetailScreen(repository: repo)
            : metric == 'head'
            ? GrowthHeadDetailScreen(repository: repo)
            : GrowthStatureDetailScreen(repository: repo);
        await tester.pumpWidget(MaterialApp(home: screen));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lịch sử'));
        await tester.pumpAndSettle();
        expect(find.byType(GrowthWeightHistoryTab), findsOneWidget);
        expect(find.text('Lịch sử đo'), findsOneWidget);
        expect(
          find.text(
            metric == 'bmi'
                ? '15,11 kg/m²'
                : metric == 'head'
                ? '45 cm'
                : '75 cm',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            metric == 'bmi'
                ? '−0,07 kg/m²'
                : metric == 'head'
                ? '+0,8 cm'
                : '+1,5 cm',
          ),
          findsOneWidget,
        );
        expect(
          tester.getTopLeft(find.text('15/04/2025')).dy,
          lessThan(tester.getTopLeft(find.text('15/03/2025')).dy),
        );
        await tester.tap(find.text('15/04/2025'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            metric == 'bmi'
                ? 'Chi tiết BMI'
                : metric == 'head'
                ? 'Chi tiết Vòng đầu'
                : 'Chi tiết Chiều dài',
          ),
          findsOneWidget,
        );
        if (metric == 'bmi') {
          expect(find.textContaining('hai số đo cùng ngày'), findsOneWidget);
        }
        if (metric == 'length') {
          expect(find.text('Cách đo: Đo nằm'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Mixed stature methods do not show a misleading delta', (
    tester,
  ) async {
    final points = [
      GrowthMeasurementDraft(
        value: 85,
        measuredAt: DateTime(2026, 4, 15),
        method: GrowthMeasurementMethod.recumbent,
      ),
      GrowthMeasurementDraft(
        value: 84.5,
        measuredAt: DateTime(2026, 6, 15),
        method: GrowthMeasurementMethod.standing,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrowthWeightHistoryTab(
            readings: points,
            repository: MetricHistoryRepo(),
            metric: GrowthMetric.lengthHeight,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('—'), findsNWidgets(2));
    await tester.tap(find.text('15/06/2026'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết Chiều cao'), findsOneWidget);
    expect(find.textContaining('Khác hoặc thiếu cách đo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('All metric histories support narrow large text and empty data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = MetricHistoryRepo();
    for (final metric in [
      GrowthMetric.lengthHeight,
      GrowthMetric.headCircumference,
      GrowthMetric.weight,
    ]) {
      final bmi = metric == GrowthMetric.weight;
      final points = bmi
          ? await repo.bmiMeasurements()
          : await repo.measurements(metric);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: GrowthWeightHistoryTab(
                readings: points,
                repository: repo,
                metric: metric,
                bmiMode: bmi,
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
            body: GrowthWeightHistoryTab(
              readings: const [],
              repository: repo,
              metric: metric,
              bmiMode: bmi,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(bmi ? 'Chưa đủ số đo cùng ngày' : 'Chưa có số đo'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
