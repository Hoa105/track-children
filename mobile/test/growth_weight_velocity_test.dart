import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_repository.dart';
import 'package:track_children/features/growth/growth_weight_detail.dart';
import 'package:track_children/features/growth/growth_weight_velocity.dart';
import 'package:track_children/features/growth/growth_weight_velocity_data.dart';
import 'package:track_children/features/growth/growth_weight_velocity_axes.dart';

class VelocityRepository extends GrowthRepository {
  VelocityRepository(this.reference);
  final GrowthWeightVelocityReference? reference;
  @override
  DateTime get dateOfBirth => DateTime(2024, 5, 15);
  @override
  Future<List<GrowthMetricViewData>> loadOverview() async => const [];
  @override
  Future<List<GrowthMeasurementDraft>> weightMeasurements() async => [
    GrowthMeasurementDraft(value: 8.2, measuredAt: DateTime(2025, 3, 15)),
    GrowthMeasurementDraft(value: 8.5, measuredAt: DateTime(2025, 4, 15)),
  ];
  @override
  Future<GrowthWeightVelocityReference?> weightVelocityReference() async =>
      reference;
}

void main() {
  test('Mock Z-score is tied to its original measurement interval and gain', () {
    final repository = MockGrowthRepository();
    final point = GrowthWeightVelocityPoint(10, 300, DateTime(2025,3,15), DateTime(2025,4,15));
    expect(repository.weightVelocityDisplayZScore(point), .6);
    expect(repository.weightVelocityDisplayZScore(GrowthWeightVelocityPoint(10, 400, point.from, point.to)), isNull);
    expect(MockGrowthRepository(referenceSex: GrowthReferenceSex.girls).weightVelocityDisplayZScore(point), isNull);
  });
  test(
    'Velocity axes have proportional ages and readable bounds containing data',
    () {
      expect(growthVelocityAgeTicks(0, 12), [0, 2, 4, 6, 8, 10, 12]);
      expect(growthVelocityAgeTicks(9, 10), [9, 10]);
      expect(growthVelocityAgeTicks(12, 36), [12, 18, 24, 30, 36]);
      final axis = growthVelocityValueAxis([-123, 300, 1844]);
      expect(axis.min, lessThanOrEqualTo(-123));
      expect(axis.max, greaterThanOrEqualTo(1844));
      expect(axis.ticks, contains(0));
      expect(axis.step, 500);
      expect(growthVelocityValueAxis([]).max, greaterThan(0));
    },
  );
  final json = jsonDecode(
    File('assets/data/who/weight_velocity_1month.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final reference = GrowthWeightVelocityReference.fromJson(
    json,
    GrowthReferenceSex.boys,
  );
  test('WHO rows and exact month increments preserve actual intervals', () {
    expect(reference.rows.length, 12);
    expect(reference.rows.first.low, 321);
    expect(reference.rows.first.high, 1608);
    final bands = reference.bands(0, 60, 28 / 31);
    expect(bands.length, 12);
    expect(bands.first.start, 0);
    expect(bands.first.end, 28 / 31);
    expect(bands[1].start, bands.first.end);
    expect(bands[1].end, 2);
    expect(bands.last.end, 12);
    for (var i = 0; i < bands.length; i++) {
      expect(bands[i].low, reference.rows[i].low);
      expect(bands[i].high, reference.rows[i].high);
    }
    expect(reference.bands(12, 36, 28 / 31), isEmpty);
    final filtered = reference.bands(9, 10, 28 / 31);
    expect(filtered.length, 1);
    expect(filtered.single.start, 9);
    expect(filtered.single.end, 10);
    expect(filtered.single.low, reference.rows[9].low);
    expect(filtered.single.high, reference.rows[9].high);
    expect(
      GrowthWeightVelocityReference.fromJson(
        json,
        GrowthReferenceSex.girls,
      ).rows.first.low,
      358,
    );
    final birth = DateTime(2024, 5, 15);
    final readings = [
      GrowthMeasurementDraft(value: 8, measuredAt: DateTime(2025, 1, 15)),
      GrowthMeasurementDraft(value: 8.2, measuredAt: DateTime(2025, 2, 15)),
      GrowthMeasurementDraft(value: 8.1, measuredAt: DateTime(2025, 3, 15)),
      GrowthMeasurementDraft(value: 8.5, measuredAt: DateTime(2025, 5, 15)),
      GrowthMeasurementDraft(value: 9, measuredAt: DateTime(2025, 6, 15)),
    ];
    final points = growthWeightMonthlyIncrements(readings, birth);
    expect(points.length, 2);
    expect(points[0].grams, closeTo(200, .001));
    expect(points[1].grams, closeTo(-100, .001));
    expect(growthWeightMonthlyIncrements(readings, null), isEmpty);
  });
  testWidgets(
    'Switches tabs, shows WHO reference, hover detail and explanation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = VelocityRepository(reference);
      await tester.pumpWidget(
        MaterialApp(home: GrowthWeightDetailScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tốc độ'));
      await tester.pumpAndSettle();
      expect(find.text('Tốc độ tăng cân theo tháng'), findsOneWidget);
      expect(find.text('WHO: \u22122 \u0111\u1ebfn +2 SD'), findsOneWidget);
      final chart = find
          .descendant(
            of: find.byType(GrowthWeightVelocityTab),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is MouseRegion && widget.child is GestureDetector,
            ),
          )
          .last;
      await tester.ensureVisible(chart);
      await tester.pumpAndSettle();
      final origin = tester.getTopLeft(chart);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      final axis = growthVelocityValueAxis(
        reference.rows.expand((r) => [r.low, r.high]),
      );
      final low = axis.min, high = axis.max;
      await mouse.moveTo(
        origin +
            Offset(
              62 + 10.5 / 12 * 274,
              12 + (high - 300) / (high - low) * 224,
            ),
      );
      await tester.pump();
      expect(
        find.text(
          '300 g/tháng\nZ-score v\u1eadn t\u1ed1c: Ch\u01b0a c\u00f3 d\u1eef li\u1ec7u\n10–11 tháng\n15/04/2025',
        ),
        findsOneWidget,
      );
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(
        find.text(
          '300 g/tháng\nZ-score v\u1eadn t\u1ed1c: Ch\u01b0a c\u00f3 d\u1eef li\u1ec7u\n10–11 tháng\n15/04/2025',
        ),
        findsNothing,
      );
      await mouse.removePointer();
      await tester.ensureVisible(find.byTooltip('Giải thích tốc độ tăng cân'));
      await tester.tap(find.byTooltip('Giải thích tốc độ tăng cân'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('velocity-age-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('velocity-age-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3–5 tuổi').last);
      await tester.pumpAndSettle();
      expect(find.text('WHO: \u22122 \u0111\u1ebfn +2 SD'), findsNothing);
      expect(
        find.text('Chưa có tham chiếu WHO chu kỳ 1 tháng cho khoảng tuổi này.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('velocity-age-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('velocity-age-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10–12 tháng').last);
      await tester.pumpAndSettle();
      expect(find.text('WHO: \u22122 \u0111\u1ebfn +2 SD'), findsOneWidget);
      await tester.tap(find.text('Tổng quan'));
      await tester.pumpAndSettle();
      expect(find.byType(GrowthWeightVelocityTab), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Narrow large-text layout and missing-reference state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: GrowthWeightVelocityTab(
              repository: VelocityRepository(null),
              readings: const [],
              easyRead: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa đủ hai số đo đúng mốc tháng để hiển thị mức tăng trong 2–12 tháng tuổi.'), findsOneWidget);
    expect(find.text('WHO: \u22122 \u0111\u1ebfn +2 SD'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
