import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/weight_chart_view.dart';
import 'package:track_children/features/growth/growth_classification_labels.dart';

void main() {
  test('canonical labels have no numbers and keep their assessment colors', () {
    expect(growthClassificationLabels.length,31);
    for(final label in growthClassificationLabels.values) {
      expect(RegExp(r'\d|\bSD\b').hasMatch(label),isFalse);
    }
    expect(growthClassificationLabel('wfa','WITHIN_RANGE'),'Phù hợp');
    expect(growthClassificationLabel('wfh','WITHIN_RANGE'),'Cân đối');
    expect(weightClassificationColor('Phù hợp'),weightClassificationColor('WITHIN_RANGE'));
    expect(weightClassificationColor('Rất gầy'),weightClassificationColor('SEVERE_WASTING'));
  });
  test('full assessment labels receive the same positive color as WITHIN_RANGE', () {
    for (final label in ['Phù hợp với tuổi', 'Cân đối với chiều dài', 'Cân đối với chiều cao', '  PHÙ HỢP VỚI TUỔI  ']) {
      expect(weightClassificationColor(label), weightClassificationColor('WITHIN_RANGE'));
    }
    expect(weightClassificationColor('Phù hợp với tuổi'), isNot(weightClassificationColor(null)));
    expect(weightClassificationColor('Kết quả chưa xác định'), weightClassificationColor(null));
  });
  setUpAll(() async {
    final font = FontLoader('Nunito')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            await File('assets/fonts/nunito/Nunito-Variable.ttf').readAsBytes(),
          ),
        ),
      );
    await font.load();
    await (FontLoader('DancingScript')..addFont(
          Future.value(
            ByteData.sublistView(
              await File(
                'assets/fonts/dancing_script/DancingScript-Variable.ttf',
              ).readAsBytes(),
            ),
          ),
        ))
        .load();
    final config = File('.dart_tool/package_config.json').absolute;
    final packages =
        jsonDecode(await config.readAsString())['packages'] as List;
    final flutter = packages.singleWhere((p) => p['name'] == 'flutter');
    final flutterRoot = config.uri.resolve('${flutter['rootUri']}/');
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            await File.fromUri(
              flutterRoot.resolve(
                '../../bin/cache/artifacts/material_fonts/materialicons-regular.otf',
              ),
            ).readAsBytes(),
          ),
        ),
      );
    await icons.load();
  });
  test('age ticks and value axis preserve data with readable steps', () {
    expect(weightAgeRanges[0], (start: 0, end: 60));
    expect(weightAgeRanges[3], (start: 0, end: 4));
    expect(weightAgeRanges[6], (start: 4, end: 7));
    expect(weightAgeRanges[9], (start: 7, end: 10));
    expect(weightAgeRanges[12], (start: 10, end: 13));
    expect(weightAgeRanges[36], (start: 12, end: 48));
    expect(weightAgeRanges[60], (start: 48, end: 60));
    expect(weightAgeTicks(0,4), [0,1,2,3,4]);
    expect(weightAgeTicks(0, 3), [0, 1, 2, 3]);
    expect(weightAgeTicks(36, 60), [36, 42, 48, 54, 60]);
    final axis = weightValueAxis([2.1, 17, 35]);
    expect(axis.min, lessThanOrEqualTo(2.1));
    expect(axis.max, greaterThan(35));
    expect([.5, 1, 2, 2.5, 5, 10, 20, 50, 100], contains(axis.step));
  });
  for (final age in [true, false]) {
    testWidgets('${age ? 'WFA' : 'WFL'} compact and expanded layouts', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final json = jsonDecode(
        (await tester.runAsync(
          () => rootBundle.loadString(
            age
                ? 'assets/data/who/weight_for_age_curves.json'
                : 'assets/data/who/weight_for_stature_curves.json',
          ),
        ))!,
      ) as Map;
      final rows =
          (json['tables'] as Map)[age ? 'boys' : 'length_boys'] as List;
      final curves = <WeightCurve>[
        for (final raw in rows)
          (
            x: age
                ? weightAgeTick((raw as List)[0] as int)
                : ((raw as List)[0] as num).toDouble(),
            kg: (raw as List)
                .skip(1)
                .map((v) => (v as num).toDouble())
                .toList(),
          ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Nunito'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RepaintBoundary(
                key: const Key('chart-capture'),
                child: ColoredBox(
                  color: Colors.white,
                  child: WeightChartView(
                    title: age
                        ? 'Cân nặng theo tuổi'
                        : 'Cân nặng theo chiều dài',
                    age: age,
                    start: age ? 0 : 45,
                    end: age ? 60 : 110,
                    curves: curves,
                    points: [
                      (
                        x: age ? 365 : 75,
                        kg: 9.5,
                        date: DateTime(2025, 1, 1),
                        z: .2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const Key('chart-capture')),
        matchesGoldenFile('goldens/${age ? 'wfa' : 'wfl'}-360.png'),
      );
      expect(find.byKey(const Key('weight-chart-legend')), findsNothing);
      final plot = tester.getRect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter.runtimeType.toString() == '_WeightPainter'));
      final yAxis = weightValueAxis([9.5, ...curves.expand((p) => [p.kg.first,p.kg.last])]);
      final anchor = plot.topLeft + Offset(34 + (age ? 365/1826 : (75-45)/65) * (plot.width-50),
        20 + (yAxis.max-9.5)/(yAxis.max-yAxis.min)*(plot.height-62));
      final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(anchor); await tester.pump();
      expect(find.byKey(const Key('weight-point-popover')), findsOneWidget);
      expect(find.text('9.5 kg'), findsOneWidget);
      expect(find.text('Z-score: 0.20'), findsOneWidget);
      final popoverRect = tester.getRect(find.byKey(const Key('weight-point-popover')));
      expect(popoverRect.bottom, lessThan(anchor.dy));
      expect(popoverRect.width, lessThanOrEqualTo(185));
      expect(find.textContaining('Ngày đo:'), findsNothing);
      await mouse.moveTo(Offset.zero); await tester.pump();
      expect(find.byKey(const Key('weight-point-popover')), findsNothing);
      await mouse.removePointer();
      expect(find.text(age ? 'Theo tuổi' : 'Theo chiều dài'), findsOneWidget);
      if (age) {
        tester.view.physicalSize = const Size(658, 360);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButton<int>).first);
        await tester.pumpAndSettle();
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -120));
        await tester.pumpAndSettle();
        await tester.tap(find.text('1–3 tuổi').last);
        await tester.pumpAndSettle();
        expect(tester.widget<DropdownButton<int>>(find.byType(DropdownButton<int>).first).value,36);
        await expectLater(find.byKey(const Key('chart-capture')),
          matchesGoldenFile('goldens/wfa-reference-layout.png'));
        tester.view.physicalSize = const Size(360, 800);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Phóng to biểu đồ'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('weight-chart-legend')), findsOneWidget);
      expect(find.text(age ? 'Theo tuổi' : 'Theo chiều dài'), findsNothing);
      expect(find.text(age ? 'Cân nặng theo tuổi' : 'Cân nặng theo chiều dài'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(Scaffold).last,
        matchesGoldenFile('goldens/${age ? 'wfa' : 'wfl'}-expanded.png'),
      );
      tester.view.physicalSize = const Size(800, 360);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
