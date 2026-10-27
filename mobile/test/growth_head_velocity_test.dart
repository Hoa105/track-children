import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_head_detail.dart';
import 'package:track_children/features/growth/growth_repository.dart';
import 'package:track_children/features/growth/growth_stature_velocity.dart';
import 'package:track_children/features/growth/growth_stature_velocity_reference.dart';

final readings = [
  for (var i = 0; i < 4; i++)
    GrowthMeasurementDraft(
      value: [43.5, 44.0, 44.2, 45.0][i],
      measuredAt: DateTime(2025, i + 1, 15),
    ),
];

class HeadVelocityRepo extends GrowthRepository {
  @override
  DateTime get dateOfBirth => DateTime(2024, 5, 15);
  @override
  Future<List<GrowthMetricViewData>> loadOverview() async => [];
  @override
  Future<List<GrowthMeasurementDraft>> measurements(
    GrowthMetric metric,
  ) async => readings;
  @override
  Future<GrowthStatureVelocityReference?> headVelocityReference() async =>
      GrowthStatureVelocityReference.fromJson(
        jsonDecode(
          File('assets/data/who/head_velocity_2month.json').readAsStringSync(),
        ),
        'boys',
        maxAgeMonths: 12,
      );
}

void main() {
  test('Head increments accept method-free readings and limit two-month WHO domain to 12 months', () {
    final points = growthStatureMonthlyIncrements(
      readings,
      DateTime(2024, 5, 15),
      months: 2,
      headCircumference: true,
    );
    expect(points.length, 2);
    expect(points.last.change, 1);
    expect(points.last.startMonth, 9);
    final later = [
      GrowthMeasurementDraft(value: 45, measuredAt: DateTime(2025, 4, 15)),
      GrowthMeasurementDraft(value: 46, measuredAt: DateTime(2025, 6, 15)),
    ];
    expect(
      growthStatureMonthlyIncrements(
        later,
        DateTime(2024, 5, 15),
        months: 2,
        headCircumference: true,
      ),
      isEmpty,
    );
    expect(
      growthStatureMonthlyIncrements(
        readings,
        DateTime(2024, 5, 15),
        months: 2,
      ),
      isEmpty,
    );
  });
  testWidgets('Head WHO assets load 11 original intervals per sex', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final sex in GrowthReferenceSex.values) {
        final ref = (await MockGrowthRepository(referenceSex: sex)
            .headVelocityReference())!;
        expect(ref.rows.length, 11);
        expect(ref.rows.last.start, 10);
        expect(ref.sourceUrl, contains('head-circumference-velocity'));
        if (sex == GrowthReferenceSex.boys) {
          expect(ref.rows.first.low, 3.2);
          expect(ref.rows.first.high, 6.2);
        }
      }
    });
  });
  testWidgets('Head tab opens in WHO mode with head-specific explanation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: GrowthHeadDetailScreen(repository: HeadVelocityRepo())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tốc độ'));
    await tester.pumpAndSettle();
    final tab = tester.widget<GrowthStatureVelocityTab>(
      find.byType(GrowthStatureVelocityTab),
    );
    expect(tab.headCircumference, isTrue);
    expect(find.text('+1 cm/2 tháng'), findsOneWidget);
    expect(
      find.textContaining('vòng đầu trong khoảng 0–12 tháng'),
      findsOneWidget,
    );
    expect(find.text('WHO · −2 SD đến +2 SD · kỳ 2 tháng'), findsOneWidget);
    await tester.ensureVisible(find.text('Vì sao có kết luận này?'));
    await tester.tap(find.text('Vì sao có kết luận này?'));
    await tester.pumpAndSettle();
    expect(find.text('Căn cứ đánh giá'), findsOneWidget);
    expect(find.textContaining('Kỳ 9–11 tháng · Bé trai'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Head velocity handles narrow large text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: GrowthStatureVelocityTab(
              repository: HeadVelocityRepo(),
              readings: readings,
              name: 'Vòng đầu',
              headCircumference: true,
              easyRead: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
