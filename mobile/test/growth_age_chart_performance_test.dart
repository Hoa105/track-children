import 'dart:collection';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_repository.dart';
import 'package:track_children/features/growth/growth_weight_detail.dart';

class CountingRows extends ListBase<GrowthWeightReferenceRow> {
  CountingRows(this.values);
  final List<GrowthWeightReferenceRow> values;
  int reads = 0;
  @override
  int get length => values.length;
  @override
  set length(int value) => values.length = value;
  @override
  GrowthWeightReferenceRow operator [](int index) {
    reads++;
    return values[index];
  }

  @override
  void operator []=(int index, GrowthWeightReferenceRow value) =>
      values[index] = value;
}

void main() {
  testWidgets('Head age chart reference work stays linear per painter', (
    tester,
  ) async {
    final rows = CountingRows([
      for (var i = 0; i <= 60; i++)
        GrowthWeightReferenceRow(i, [
          30 + i * .1,
          32 + i * .1,
          34 + i * .1,
          36 + i * .1,
          38 + i * .1,
        ]),
    ]);
    final reference = GrowthWeightReference(
      sex: GrowthReferenceSex.boys,
      rows: rows,
      sourceUrl: 'fixture',
      sourceHash: 'fixture',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrowthWeightMeasurementChart(
            points: [
              for (var i = 8; i <= 11; i++)
                GrowthMeasurementDraft(
                  value: 40 + i * .1,
                  measuredAt: DateTime(2024, 5 + i, 15),
                ),
            ],
            dateOfBirth: DateTime(2024, 5, 15),
            reference: reference,
            unit: 'cm',
            axisTitle: 'Vòng đầu (cm)',
            onSelect: (_) {},
            onHover: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    debugPrint('HEAD_CHART_REFERENCE_READS=${rows.reads}');
    expect(rows.reads, inInclusiveRange(1, 61));
    final afterPaint = rows.reads;
    final chart = find.byType(GrowthWeightMeasurementChart);
    final origin = tester.getTopLeft(chart);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    for (var i = 0; i < 20; i++) {
      await mouse.moveTo(origin + Offset(70 + i * 8, 100));
      await tester.pump();
    }
    await mouse.removePointer();
    expect(
      rows.reads,
      afterPaint,
      reason: 'Pointer hit tests must reuse cached axis bounds and ages',
    );
    expect(tester.takeException(), isNull);
  });
}
