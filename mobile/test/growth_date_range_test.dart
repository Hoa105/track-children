import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/growth/growth_chart.dart';
import 'package:track_children/features/growth/growth_screen.dart';
import 'package:track_children/services/demo_store.dart';

Future<void> choose(WidgetTester tester, DateTimeRange? range) async {
  await tester.ensureVisible(find.byTooltip('Tùy chọn'));
  await tester.tap(find.byTooltip('Tùy chọn'));
  await tester.pumpAndSettle();
  expect(find.byType(DateRangePickerDialog), findsOneWidget);
  Navigator.of(tester.element(find.byType(DateRangePickerDialog))).pop(range);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
  });
  testWidgets(
    'custom range shared by all metrics, inclusive endpoints, cancel and presets',
    (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final end = today.subtract(const Duration(days: 28));
      final start = end.subtract(const Duration(days: 84));
      await tester.pumpWidget(
        const MaterialApp(home: GrowthScreen(childName: 'Range')),
      );
      await tester.pumpAndSettle();
      await choose(tester, DateTimeRange(start: start, end: end));
      for (final tab in ['Cân nặng', 'Chiều cao', 'Vòng đầu', 'BMI']) {
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(tab).first);
        await tester.tap(find.text(tab).first);
        await tester.pump();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        final chart = tester.widget<GrowthChart>(find.byType(GrowthChart));
        expect(chart.values.length, 4);
        expect(chart.rangeStart, start);
        expect(chart.rangeEnd, end);
        expect(chart.dates.first, start);
        expect(chart.dates.last, end);
        expect(chart.previewAnchor, today);
      }
      await choose(tester, null);
      expect(
        tester.widget<GrowthChart>(find.byType(GrowthChart)).values.length,
        4,
      );
      await tester.ensureVisible(find.text('Tất cả'));
      await tester.tap(find.text('Tất cả'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<GrowthChart>(find.byType(GrowthChart)).values.length,
        7,
      );
      expect(
        tester.widget<GrowthChart>(find.byType(GrowthChart)).rangeStart,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'same-day range includes late measurements and empty range can be reset',
    (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final day = today.subtract(const Duration(days: 10));
      SharedPreferences.setMockInitialValues({
        'growth_v1_Range': jsonEncode([
          {
            'date': day
                .add(const Duration(hours: 23, minutes: 59))
                .toIso8601String(),
            'v0': 8.1,
            'v1': 68,
            'v2': 43,
          },
          {'date': today.toIso8601String(), 'v0': 8.4, 'v1': 69, 'v2': 44},
        ]),
      });
      await tester.pumpWidget(
        const MaterialApp(home: GrowthScreen(childName: 'Range')),
      );
      await tester.pumpAndSettle();
      await choose(tester, DateTimeRange(start: day, end: day));
      expect(tester.widget<GrowthChart>(find.byType(GrowthChart)).values, [
        8.1,
      ]);
      expect(tester.widget<GrowthChart>(find.byType(GrowthChart)).dates, [day]);
      await choose(
        tester,
        DateTimeRange(
          start: day.subtract(const Duration(days: 5)),
          end: day.subtract(const Duration(days: 1)),
        ),
      );
      expect(find.byType(GrowthChart), findsNothing);
      expect(
        find.textContaining('Chưa có số đo trong khoảng này.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Tất cả'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<GrowthChart>(find.byType(GrowthChart)).values.length,
        2,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
