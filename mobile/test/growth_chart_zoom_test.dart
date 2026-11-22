import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_chart_scale.dart';
import 'package:track_children/features/growth/growth_chart_gestures.dart';
import 'package:track_children/features/growth/growth_tracking_flow.dart';
import 'package:track_children/features/growth/growth_measurement_chart.dart';
import 'package:track_children/features/growth/growth_repository.dart';

Future<void> pinch(
  WidgetTester tester,
  Finder area, {
  bool expand = true,
  bool staggered = false,
}) async {
  final center =
      tester.getTopLeft(area) + Offset(tester.getSize(area).width / 2, 160);
  final initial = expand ? 30.0 : 100.0;
  final finish = expand ? 100.0 : 30.0;
  final first = await tester.createGesture(pointer: 21);
  final second = await tester.createGesture(pointer: 22);
  await first.down(center - Offset(initial, 0));
  if (staggered) {
    await first.moveBy(const Offset(-25, 0));
    await tester.pump(const Duration(milliseconds: 30));
  }
  await second.down(center + Offset(initial, 0));
  await tester.pump();
  for (var i = 1; i <= 8; i++) {
    final spread = initial + (finish - initial) * i / 8;
    await first.moveTo(center - Offset(spread, 0));
    await second.moveTo(center + Offset(spread, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  final rangeBeforeLift = tester
      .state<GrowthMeasurementChartState>(find.byType(GrowthMeasurementChart))
      .visibleRange;
  await first.up();
  await tester.pump();
  expect(
    tester
        .state<GrowthMeasurementChartState>(find.byType(GrowthMeasurementChart))
        .visibleRange,
    rangeBeforeLift,
  );
  await second.up();
  await tester.pumpAndSettle();
}

Future<void> reset(WidgetTester tester) async {
  final area = find.byType(GrowthChartGestures);
  final center = tester.getTopLeft(area) + const Offset(180, 80);
  await tester.tapAt(center);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tapAt(center);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('leaving the chart during a pinch releases pointer tracking', (
    tester,
  ) async {
    final locks = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: GrowthChartGestures(
          onStart: (_) {},
          onUpdate: (_) {},
          onTap: (_) {},
          onPinchingChanged: locks.add,
          child: const SizedBox.expand(),
        ),
      ),
    );
    final first = await tester.createGesture(pointer: 71);
    final second = await tester.createGesture(pointer: 72);
    await first.down(const Offset(100, 100));
    await second.down(const Offset(200, 100));
    await tester.pump();
    expect(locks, [true]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(locks, [true, false]);
    await first.up();
    await second.up();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'pinch works inside the real tab after the first finger moves early',
    (tester) async {
      tester.view.physicalSize = const Size(390, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: TrackingHistoryScreen(
            repository: MockGrowthRepository(),
            metric: GrowthMetric.weight,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await pinch(tester, find.byType(GrowthChartGestures), staggered: true);
      final range = tester
          .state<GrowthMeasurementChartState>(
            find.byType(GrowthMeasurementChart),
          )
          .visibleRange;
      expect(range.end - range.start, lessThan(72));
      expect(
        DefaultTabController.of(tester.element(find.byType(TabBarView))).index,
        0,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('overview horizontal swipe still switches to history', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: TrackingHistoryScreen(
          repository: MockGrowthRepository(),
          metric: GrowthMetric.weight,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final area = find.byType(GrowthChartGestures);
    await tester.dragFrom(
      tester.getTopLeft(area) + const Offset(280, 120),
      const Offset(-240, 0),
    );
    await tester.pumpAndSettle();
    expect(
      DefaultTabController.of(tester.element(find.byType(TabBarView))).index,
      1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('pinch zooms in and out while vertical swipes scroll the page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final birth = DateTime(2023, 1, 1);
    final rows = List.generate(
      1000,
      (i) => GrowthMeasurementDraft(
        value: 3 + i / 100,
        measuredAt: birth.add(Duration(days: i)),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: controller,
            child: Column(
              children: [
                GrowthMeasurementChart(
                  rows: rows,
                  birth: birth,
                  metric: GrowthMetric.weight,
                ),
                const SizedBox(height: 400),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final area = find.byType(GrowthChartGestures);
    dynamic painter() => tester
        .widget<CustomPaint>(find.byKey(const Key('growth-plot')))
        .painter;
    await pinch(tester, area);
    final zoomed = painter().maxAge - painter().minAge as double;
    expect(zoomed, lessThan(72));
    expect(controller.offset, 0);
    await pinch(tester, area, expand: false);
    expect(painter().maxAge - painter().minAge, greaterThan(zoomed));
    final span = painter().maxAge - painter().minAge;
    await tester.dragFrom(
      tester.getTopLeft(area) + const Offset(180, 100),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(painter().maxAge - painter().minAge, closeTo(span, .00001));
    expect(tester.takeException(), isNull);
  });

  for (final metric in GrowthMetric.values) {
    test(
      '${metric.name}: vertical scale includes the first and all later values',
      () {
        for (final values in [
          [3.0],
          [45.0],
          [9.5, 7.0, 8.5],
          [35.0, 38.0, 36.0],
          [3.15, 3.2, 3.18],
          [.1, .2],
        ]) {
          final rows = [
            for (final value in values)
              GrowthMeasurementDraft(value: value, measuredAt: DateTime(2026)),
          ];
          final scale = GrowthChartValueScale.forRows(rows, metric);
          for (final value in values) {
            expect(scale.low, lessThanOrEqualTo(value));
            expect(scale.high, greaterThanOrEqualTo(value));
          }
          expect(scale.low, greaterThanOrEqualTo(0));
          expect(scale.high, greaterThan(scale.low));
          expect(scale.step, greaterThan(0));
        }
        final scale = GrowthChartValueScale.forRows([
          GrowthMeasurementDraft(value: 3, measuredAt: DateTime(2026)),
        ], GrowthMetric.weight);
        expect(scale.low, 2.5);
      },
    );

    testWidgets(
      '${metric.name}: zoom filters a 1000-row snapshot and reset restores every row',
      (tester) async {
        tester.view.physicalSize = const Size(390, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final birth = DateTime(2023, 1, 1);
        final rows = List.generate(
          1000,
          (i) => GrowthMeasurementDraft(
            id: '$i',
            value: 3 + i / 100,
            measuredAt: birth.add(Duration(days: i)),
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
        dynamic painter() => tester.widget<CustomPaint>(paint).painter;
        expect(painter().rows, hasLength(1000));
        expect(find.byKey(const Key('growth-visible-range')), findsNothing);
        expect(find.byIcon(Icons.restart_alt), findsNothing);
        expect(painter().showMarkers(tester.getSize(paint)), isFalse);
        expect(find.byIcon(Icons.zoom_in), findsNothing);
        expect(find.byType(RangeSlider), findsNothing);
        await pinch(tester, find.byType(GrowthChartGestures));
        expect(painter().maxAge - painter().minAge, lessThan(72));
        Future<void> range(double start, double end) async {
          await reset(tester);
          await tester.pumpAndSettle();
          final gestures = tester.widget<GrowthChartGestures>(
            find.byType(GrowthChartGestures),
          );
          final width = tester.getSize(find.byType(GrowthChartGestures)).width;
          final anchor = 38 + (width - 46) * ((start + end) / 2 / 72);
          gestures.onStart(
            ScaleStartDetails(
              localFocalPoint: Offset(anchor, 100),
              pointerCount: 2,
            ),
          );
          gestures.onUpdate(
            ScaleUpdateDetails(
              localFocalPoint: Offset(38 + (width - 46) / 2, 100),
              pointerCount: 2,
              scale: 72 / (end - start),
            ),
          );
          await tester.pumpAndSettle();
        }

        await range(12, 24);
        await tester.pumpAndSettle();
        expect(painter().rows, hasLength(367));
        expect(painter().rows.first.id, '365');
        expect(painter().rows.last.id, '731');
        for (final row in painter().rows as List<GrowthMeasurementDraft>) {
          expect(row.measuredAt.isBefore(DateTime(2024, 1, 1)), isFalse);
          expect(row.measuredAt.isAfter(DateTime(2025, 1, 1)), isFalse);
          expect(painter().low, lessThanOrEqualTo(row.value));
          expect(painter().high, greaterThanOrEqualTo(row.value));
        }
        final Rect plot = painter().plot(tester.getSize(paint));
        expect(
          painter().xForDate(DateTime(2024, 1, 1), tester.getSize(paint)),
          plot.left,
        );
        expect(
          painter().xForDate(DateTime(2025, 1, 1), tester.getSize(paint)),
          closeTo(plot.right, .00001),
        );
        await tester.drag(paint, const Offset(-50, 0));
        await tester.pumpAndSettle();
        expect(painter().minAge, greaterThan(12));
        expect(painter().maxAge, greaterThan(24));
        await range(12, 12.1);
        await tester.pumpAndSettle();
        expect(painter().rows, hasLength(4));
        expect(painter().showMarkers(tester.getSize(paint)), isTrue);
        await range(59, 60);
        await tester.pumpAndSettle();
        expect(
          find.text('Chưa có số đo trong khoảng đang xem.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('selected-growth-value')), findsNothing);
        await reset(tester);
        await tester.pumpAndSettle();
        expect(painter().rows, hasLength(1000));
        expect(painter().minAge, 0);
        expect(painter().maxAge, 72);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
