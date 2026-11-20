import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_measurement_chart.dart';
import 'package:track_children/features/growth/growth_repository.dart';

void main() {
  testWidgets('two head measurements both paint a circle on the overview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GrowthMeasurementChart(
              birth: DateTime(2026, 4, 4),
              metric: GrowthMetric.headCircumference,
              rows: [
                GrowthMeasurementDraft(
                  value: 40.5,
                  measuredAt: DateTime(2026, 7, 14),
                ),
                GrowthMeasurementDraft(
                  value: 45.5,
                  measuredAt: DateTime(2026, 11, 19),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final plot = find.byKey(const Key('growth-plot'));
    final dynamic painter = tester.widget<CustomPaint>(plot).painter;
    expect(painter.showMarkers(tester.getSize(plot)), isTrue);
    // Two measurement dots plus two rings highlighting the selected dot.
    expect(plot, paintsExactlyCountTimes(#drawCircle, 4));
    expect(tester.takeException(), isNull);
  });

  for (final metric in GrowthMetric.values) {
    for (final count in [1, 2, 12, 1000]) {
      testWidgets(
        '${metric.name}: $count measurements use the correct dot visibility',
        (tester) async {
          final birth = DateTime(2023, 1, 1);
          final rows = List.generate(
            count,
            (i) => GrowthMeasurementDraft(
              value: (metric == GrowthMetric.weight ? 3 : 40) + i / 100,
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
          final plot = find.byKey(const Key('growth-plot'));
          expect(
            plot,
            paintsExactlyCountTimes(#drawCircle, count <= 12 ? count + 2 : 3),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
