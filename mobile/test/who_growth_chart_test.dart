import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/growth/growth_chart.dart';
import 'package:track_children/services/who_growth_reference.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all WHO metrics cover both sexes with correct reference and transition',
    () async {
      final ref = await WhoGrowthReference.load();
      final birth = DateTime(2020, 1, 15);
      for (final metric in ['weight', 'height', 'head', 'bmi']) {
        for (final sex in ['boys', 'girls']) {
          for (var m = 0; m <= 60; m++) {
            final row = ref.at(metric, sex, birth, DateTime(2020, 1 + m, 15))!;
            expect(row[0], lessThan(row[1]));
            expect(row[1], lessThan(row[2]));
          }
          expect(ref.at(metric, sex, birth, DateTime(2019, 12, 31)), isNull);
          expect(ref.at(metric, sex, birth, DateTime(2025, 1, 16)), isNull);
        }
      }
      expect(ref.at('weight', 'boys', birth, birth)![1], 3.3);
      expect(ref.at('head', 'girls', birth, birth)![1], 33.9);
      expect(ref.at('height', 'boys', birth, DateTime(2022, 1, 15))![1], 87.1);
      expect(
        ref.at('height', 'boys', birth, DateTime(2022, 1, 14))![1],
        greaterThan(87.7),
      );
    },
  );
  for (final metric in ['weight', 'height', 'head', 'bmi']) {
    testWidgets('$metric chart displays child and WHO at narrow width', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GrowthChart(
              values: const [7.2, 8.4],
              dates: [DateTime(2026, 8, 15), DateTime(2026, 10, 15)],
              metric: metric,
              childName: 'Test',
              preview: true,
              unit: 'kg',
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(find.text('Trung vị WHO'), findsOneWidget);
      final paint = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('growth-who-chart')),
      );
      expect((paint.painter! as GrowthChartPainter).hasReference, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('missing profile keeps child data and omits WHO', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrowthChart(
            values: const [8.4],
            dates: [DateTime(2026, 10, 15)],
            metric: 'weight',
            childName: 'Test',
            preview: false,
            unit: 'kg',
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.text('Số đo của bé'), findsOneWidget);
    expect(find.text('Trung vị WHO'), findsNothing);
    expect(find.text('Chưa có thông tin đối chiếu WHO.'), findsOneWidget);
  });
}
