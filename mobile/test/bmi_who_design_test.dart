import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_visuals.dart';
import 'package:track_children/features/growth/growth_repository.dart';
import 'package:track_children/features/growth/growth_bmi_detail.dart';
import 'package:track_children/features/growth/weight_chart_view.dart';

import 'growth_bmi_detail_test.dart' show BmiRepo;

class _PositionRepo extends BmiRepo {
  _PositionRepo(this.birth, this.date, this.method);
  final DateTime birth, date;
  final GrowthMeasurementMethod? method;
  @override
  DateTime get dateOfBirth => birth;
  @override
  Future<List<GrowthMeasurementDraft>> weightMeasurements() async => [
    GrowthMeasurementDraft(value: 12, measuredAt: date),
  ];
  @override
  Future<List<GrowthMeasurementDraft>> measurements(
    GrowthMetric metric,
  ) async => [
    GrowthMeasurementDraft(value: 85, measuredAt: date, method: method),
  ];
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final entry in {
      'Nunito': 'assets/fonts/nunito/Nunito-Variable.ttf',
      'DancingScript': 'assets/fonts/dancing_script/DancingScript-Variable.ttf',
    }.entries) {
      await (FontLoader(entry.key)..addFont(
            Future.value(
              ByteData.sublistView(File(entry.value).readAsBytesSync()),
            ),
          ))
          .load();
    }
  });
  test(
    'Local BMI normalizes stature before squaring at WHO 730/731-day boundary',
    () async {
      final birth = DateTime(2023, 1, 1);
      final before = (await _PositionRepo(
        birth,
        birth.add(const Duration(days: 730)),
        GrowthMeasurementMethod.standing,
      ).bmiMeasurements()).single;
      expect(before.value, closeTo(12 / (.857 * .857), 1e-10));
      expect(before.method, GrowthMeasurementMethod.recumbent);
      final after = (await _PositionRepo(
        birth,
        birth.add(const Duration(days: 731)),
        GrowthMeasurementMethod.recumbent,
      ).bmiMeasurements()).single;
      expect(after.value, closeTo(12 / (.843 * .843), 1e-10));
      expect(after.method, GrowthMeasurementMethod.standing);
      expect(
        await _PositionRepo(
          birth,
          birth.add(const Duration(days: 100)),
          GrowthMeasurementMethod.standing,
        ).bmiMeasurements(),
        isEmpty,
      );
      expect(
        await _PositionRepo(
          birth,
          birth.add(const Duration(days: 400)),
          null,
        ).bmiMeasurements(),
        isEmpty,
      );
    },
  );
  testWidgets(
    'BMI overview and expanded chart follow weight design and preserve WHO segments',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Nunito'),
          home: GrowthBmiDetailScreen(repository: BmiRepo()),
        ),
      );
      await tester.pumpAndSettle();
      final chart = tester.widget<WeightChartView>(
        find.byType(WeightChartView),
      );
      expect(chart.dataColor, growthGreen);
      expect(chart.curves.where((r) => r.x == 730).length, 1);
      expect(chart.curves.where((r) => r.x == 731).length, 1);
      expect(
        tester.widget<Text>(find.text('Tổng quan')).style!.color,
        growthGreen,
      );
      expect(find.text('Tốc độ'), findsNothing);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/bmi-overview.png'),
      );
      await tester.tap(find.byTooltip('Phóng to biểu đồ'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<WeightChartView>(find.byType(WeightChartView))
            .last
            .expanded,
        isTrue,
      );
      await expectLater(
        find.byType(Scaffold).last,
        matchesGoldenFile('goldens/bmi-overview-expanded.png'),
      );
      await tester.tap(find.byTooltip('Thông tin biểu đồ').last);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Không dùng ngưỡng BMI người lớn'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
