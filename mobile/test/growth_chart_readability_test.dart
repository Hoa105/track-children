import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_tracking_flow.dart';
import 'package:track_children/features/growth/growth_repository.dart';
import 'package:track_children/features/growth/growth_measurement_chart.dart';

void main() {
  for (final metric in GrowthMetric.values) {
    for (final (birth, day, months) in [
      (DateTime(2025, 5, 3), DateTime(2026, 5, 3), 12.0),
      (DateTime(2026, 4, 3), DateTime(2026, 5, 3), 1.0),
      (DateTime(2026, 4, 4), DateTime(2026, 5, 3), 29 / 30),
      (DateTime(2026, 4, 19), DateTime(2026, 5, 3), 14 / 30),
      (DateTime(2026, 1, 31), DateTime(2026, 2, 28), 1.0),
      (DateTime(2024, 2, 29), DateTime(2025, 2, 28), 12.0),
    ]) {
      testWidgets(
        '${metric.name}: first measurement at $day is placed at age $months months',
        (tester) async {
          final row = GrowthMeasurementDraft(
            value: metric == GrowthMetric.weight ? 3 : 45,
            measuredAt: day,
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: GrowthMeasurementChart(
                    rows: [row],
                    birth: birth,
                    metric: metric,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final paint = find.descendant(
            of: find.byType(GrowthMeasurementChart),
            matching: find.byKey(const Key('growth-plot')),
          );
          final dynamic painter = tester.widget<CustomPaint>(paint).painter;
          final size = tester.getSize(paint);
          final Rect plot = painter.plot(size);
          final Offset point = painter.point(row, size);
          expect(painter.start, birth);
          expect(
            point.dx,
            closeTo(plot.left + plot.width * months / 60, .00001),
          );
          expect(point.dx, greaterThan(plot.left));
          expect(painter.xForDate(birth, size), plot.left);
          expect(
            painter.xForDate(painter.stop, size),
            closeTo(plot.right, .00001),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      '${metric.name}: all 1000 valid measurements reach the painter',
      (tester) async {
        final birth = DateTime(2023, 1, 1);
        final rows = List.generate(
          1000,
          (i) => GrowthMeasurementDraft(
            id: 'record-$i',
            measuredAt: birth.add(Duration(days: i)),
            value: metric == GrowthMetric.weight ? 3 + i / 100 : 35 + i / 100,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: GrowthMeasurementChart(
                  rows: rows,
                  birth: birth,
                  metric: metric,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final paint = find.descendant(
          of: find.byType(GrowthMeasurementChart),
          matching: find.byKey(const Key('growth-plot')),
        );
        final dynamic painter = tester.widget<CustomPaint>(paint).painter;
        expect(painter.rows, hasLength(1000));
        expect(painter.rows.first.id, 'record-0');
        expect(painter.rows.last.id, 'record-999');
        final size = tester.getSize(paint);
        for (final row in rows) {
          final Offset point = painter.point(row, size);
          expect(point.dx.isFinite && point.dy.isFinite, isTrue);
        }
        expect(find.textContaining('60 số đo'), findsNothing);
        expect(
          tester
              .getSize(find.byKey(const Key('selected-growth-measurement')))
              .height,
          lessThan(120),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${metric.name}: larger chart and selected value respond to touch',
      (tester) async {
        tester.view.physicalSize = const Size(390, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = MockGrowthRepository();
        final rows = await repository.measurements(metric);
        await tester.pumpWidget(
          MaterialApp(
            home: TrackingHistoryScreen(repository: repository, metric: metric),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('Phóng to'), findsNothing);
        expect(find.byIcon(Icons.open_in_full), findsNothing);
        final value = find.byKey(const Key('selected-growth-value'));
        expect(
          tester.widget<Text>(value).data,
          '${formatGrowthValue(rows.last.value)} ${metric.unit}',
        );
        expect(
          tester.widget<Text>(value).style!.fontSize,
          greaterThanOrEqualTo(24),
        );
        final paint = find.descendant(
          of: find.byType(GrowthMeasurementChart),
          matching: find.byKey(const Key('growth-plot')),
        );
        final size = tester.getSize(paint);
        expect(size.width, greaterThanOrEqualTo(370));
        expect(size.height, greaterThan(size.width));
        final dynamic painter = tester.widget<CustomPaint>(paint).painter;
        final Offset point = painter.point(rows.first, size);
        await tester.tapAt(tester.getTopLeft(paint) + point);
        await tester.pump();
        expect(
          tester.widget<Text>(value).data,
          '${formatGrowthValue(rows.first.value)} ${metric.unit}',
        );
        final date = rows.first.measuredAt;
        expect(
          tester
              .widget<Text>(find.byKey(const Key('selected-growth-date')))
              .data,
          'Ngày đo: ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('selected measurement fits narrow screen with large text', (
    tester,
  ) async {
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
    expect(find.byKey(const Key('selected-growth-value')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
