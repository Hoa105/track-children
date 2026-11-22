import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_overview.dart';
import 'package:track_children/features/growth/growth_tracking_flow.dart';
import 'package:track_children/features/growth/growth_measurement_chart.dart';

class EmptyGrowth extends GrowthRepository {
  @override
  DateTime get dateOfBirth => DateTime(2025, 1, 1);
}

class ReadOnlyGrowth extends MockGrowthRepository {
  @override
  bool get canEdit => false;
}

void main() {
  testWidgets('separate summaries open the matching assessment', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: GrowthOverview(repository: MockGrowthRepository())),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GrowthMeasurementChart), findsOneWidget);
    for (final (title, kind) in [
      ('Đánh giá BMI', 'bmi'),
      ('Đánh giá vòng đầu', 'head'),
    ]) {
      await tester.scrollUntilVisible(find.text(title), 200);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(title));
      await tester.pumpAndSettle();
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TrackingAssessmentScreen>(
              find.byType(TrackingAssessmentScreen),
            )
            .kind,
        kind,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  for (final metric in GrowthMetric.values) {
    testWidgets('${metric.name}: chart and history show the same metric', (
      tester,
    ) async {
      final repository = MockGrowthRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: TrackingHistoryScreen(repository: repository, metric: metric),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<GrowthMeasurementChart>(find.byType(GrowthMeasurementChart))
            .metric,
        metric,
      );
      await tester.tap(find.text('Lịch sử'));
      await tester.pumpAndSettle();
      final row = (await repository.measurements(metric)).last;
      await tester.tap(
        find.text('${trackingValue(row.value)} ${metric.unit}').first,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TrackingMeasurementEditor>(
              find.byType(TrackingMeasurementEditor),
            )
            .metric,
        metric,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Biểu đồ'));
      await tester.pumpAndSettle();
      expect(find.byType(GrowthMeasurementChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty detail keeps both tabs available', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TrackingHistoryScreen(
          repository: EmptyGrowth(),
          metric: GrowthMetric.weight,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa có số đo trong độ tuổi này.'), findsOneWidget);
    await tester.tap(find.text('Lịch sử'));
    await tester.pumpAndSettle();
    expect(find.text('Thêm số đo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('read only history cannot open editor', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TrackingHistoryScreen(
          repository: ReadOnlyGrowth(),
          metric: GrowthMetric.weight,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Ghi số đo'), findsNothing);
    await tester.tap(find.text('Lịch sử'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Card).first);
    await tester.pumpAndSettle();
    expect(find.byType(TrackingMeasurementEditor), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail fits narrow screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: TrackingHistoryScreen(
            repository: MockGrowthRepository(),
            metric: GrowthMetric.headCircumference,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Lịch sử'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
