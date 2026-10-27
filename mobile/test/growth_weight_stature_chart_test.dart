import 'package:flutter/material.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_models.dart';
import 'package:track_children/features/growth/growth_weight_stature_chart.dart';

void main() {
  test('Stature range is centered and clamped to WHO limits', () {
    expect(growthStatureDisplayRange(76.5, 5, 45, 110), (min: 71.5, max: 81.5));
    expect(growthStatureDisplayRange(76.5, 10, 45, 110), (
      min: 66.5,
      max: 86.5,
    ));
    expect(growthStatureDisplayRange(76.5, 20, 45, 110), (
      min: 56.5,
      max: 96.5,
    ));
    expect(growthStatureDisplayRange(47, 5, 45, 110), (min: 45.0, max: 52.0));
    expect(growthStatureDisplayRange(108, 5, 45, 110), (
      min: 103.0,
      max: 110.0,
    ));
    expect(growthStatureDisplayRange(76.5, null, 45, 110), (
      min: 45.0,
      max: 110.0,
    ));
    expect(growthStatureDisplayRange(null, 5, 45, 110), (
      min: 45.0,
      max: 110.0,
    ));
  });
  final raw = jsonDecode(
    File('assets/data/who/weight_for_stature_curves.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  test('WHO tables cover both sexes and length/height domains', () {
    for (final sex in GrowthReferenceSex.values) {
      for (final length in [true, false]) {
        final ref = GrowthStatureReference.fromJson(raw, sex, length);
        expect(ref.rows.length, length ? 131 : 111);
        expect(ref.rows.first[0], length ? 45 : 65);
        expect(ref.rows.last[0], length ? 110 : 120);
        expect(ref.sourceUrl, contains('cdn.who.int'));
      }
    }
    final ref = GrowthStatureReference.fromJson(
      raw,
      GrowthReferenceSex.boys,
      true,
    );
    expect(ref.rows.first, [45, 1.9, 2, 2.4, 3, 3.3]);
    final broken = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
    broken['tables']['length_boys'][0][2] = 0;
    expect(
      () => GrowthStatureReference.fromJson(
        broken,
        GrowthReferenceSex.boys,
        true,
      ),
      throwsFormatException,
    );
  });
  testWidgets('WHO chart and shared legend render with and without paired readings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final length in [true, false]) {
      final date = DateTime(length ? 2025 : 2026, 6, 15);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GrowthWeightStatureChart(
                reference: GrowthStatureReference.fromJson(
                  raw,
                  GrowthReferenceSex.girls,
                  length,
                ),
                dateOfBirth: DateTime(2024, 5, 15),
                useLength: length,
                statureLabel: length ? 'chiều dài' : 'chiều cao',
                weights: [GrowthMeasurementDraft(value: 10, measuredAt: date)],
                statures: [
                  GrowthMeasurementDraft(
                    value: 80,
                    measuredAt: date,
                    method: length
                        ? GrowthMeasurementMethod.recumbent
                        : GrowthMeasurementMethod.standing,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Số đo của trẻ'), findsOneWidget);
      expect(find.text('Phù hợp với tuổi'), findsOneWidget);
      expect(find.text('+3 SD'), findsOneWidget);
      final region = find
          .descendant(
            of: find.byType(GrowthWeightStatureChart),
            matching: find.byType(MouseRegion),
          )
          .last;
      final topLeft = tester.getTopLeft(region);
      final maxKg = length ? 30.0 : 35.0;
      final x = 62 + (80 - (length ? 45 : 65)) / (length ? 65 : 55) * 244;
      final y = 12 + (1 - 10 / maxKg) * 174;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(topLeft + Offset(x, y));
      await tester.pump();
      expect(
        find.text(
          '10 kg\nZ-score: Ch\u01b0a c\u00f3 d\u1eef li\u1ec7u\n80 cm\n15/06/${length ? 2025 : 2026}',
        ),
        findsOneWidget,
      );
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(
        find.text(
          '10 kg\nZ-score: Ch\u01b0a c\u00f3 d\u1eef li\u1ec7u\n80 cm\n15/06/${length ? 2025 : 2026}',
        ),
        findsNothing,
      );
      await mouse.removePointer();
      await tester.tap(find.byKey(const ValueKey('stature-range-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('±5 cm').last);
      await tester.pumpAndSettle();
      expect(find.text('75–85 cm · Số đo hiện tại: 80 cm'), findsOneWidget);
      await tester.tap(
        find.byTooltip(
          'Giải thích biểu đồ cân nặng theo ${length ? 'chiều dài' : 'chiều cao'}',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.textContaining('±5 cm nghĩa là'), findsOneWidget);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('stature-range-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toàn bộ').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('Only pairs same-day readings with the age-appropriate method', (
    tester,
  ) async {
    final birth = DateTime(2024, 5, 15);
    Future<void> show(
      DateTime date,
      bool length,
      GrowthMeasurementMethod method,
    ) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrowthWeightStatureChart(
            dateOfBirth: birth,
            useLength: length,
            statureLabel: length ? 'chiều dài' : 'chiều cao',
            weights: [GrowthMeasurementDraft(value: 10, measuredAt: date)],
            statures: [
              GrowthMeasurementDraft(
                value: 80,
                measuredAt: date,
                method: method,
              ),
            ],
          ),
        ),
      ),
    );
    await show(DateTime(2026, 5, 14), true, GrowthMeasurementMethod.recumbent);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.textContaining('Chưa có cặp số đo'), findsNothing);
    await show(DateTime(2026, 5, 15), false, GrowthMeasurementMethod.recumbent);
    expect(find.textContaining('Chưa có cặp số đo'), findsOneWidget);
    await show(DateTime(2026, 5, 15), false, GrowthMeasurementMethod.standing);
    expect(find.textContaining('Chưa có cặp số đo'), findsNothing);
    expect(find.text('Cân nặng theo chiều cao'), findsOneWidget);
  });
}
