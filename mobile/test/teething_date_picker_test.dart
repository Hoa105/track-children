import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/teething/teething_date_picker.dart';
import 'package:track_children/features/teething/tooth_chart.dart';
import 'package:track_children/models/tooth.dart';

void main() {
  testWidgets(
    'day and month wheels wrap without empty ends in a compact frame',
    (tester) async {
      var date = DateTime(2025, 4, 30);
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: TeethingDatePicker(
                value: date,
                firstDate: DateTime(2023, 1, 1),
                lastDate: DateTime(2026, 11, 4),
                onChanged: (value) => setState(() => date = value),
              ),
            ),
          ),
        ),
      );
      CupertinoPicker picker(String label) => tester.widget<CupertinoPicker>(
        find.byKey(Key('teething-date-$label')),
      );
      expect(
        picker('Ngày').childDelegate,
        isA<ListWheelChildLoopingListDelegate>(),
      );
      expect(
        picker('Tháng').childDelegate,
        isA<ListWheelChildLoopingListDelegate>(),
      );
      expect(
        tester.getSize(find.byKey(const Key('teething-date-picker'))).height,
        lessThan(180),
      );
      picker('Ngày').scrollController!.jumpToItem(30);
      await tester.pumpAndSettle();
      expect(date, DateTime(2025, 4, 1));
      picker('Ngày').scrollController!.jumpToItem(-1);
      await tester.pumpAndSettle();
      expect(date, DateTime(2025, 4, 30));
      picker('Tháng').scrollController!.jumpToItem(12);
      await tester.pumpAndSettle();
      expect(date, DateTime(2025, 1, 30));
      picker('Tháng').scrollController!.jumpToItem(-1);
      await tester.pumpAndSettle();
      expect(date, DateTime(2025, 12, 30));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('numeric wheels handle leap years and lifetime boundaries', (
    tester,
  ) async {
    var date = DateTime(2024, 1, 31);
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: TeethingDatePicker(
              value: date,
              firstDate: DateTime(2023, 10, 15),
              lastDate: DateTime(2026, 11, 4),
              onChanged: (value) => setState(() => date = value),
            ),
          ),
        ),
      ),
    );
    Future<void> select(String label, int index) async {
      tester
          .widget<CupertinoPicker>(find.byKey(Key('teething-date-$label')))
          .onSelectedItemChanged!(index);
      await tester.pumpAndSettle();
    }

    await select('Tháng', 1);
    expect(date, DateTime(2024, 2, 29));
    await select('Năm', 2);
    expect(date, DateTime(2025, 2, 28));
    await select('Năm', 3);
    await select('Tháng', 10);
    expect(date, DateTime(2026, 11, 4));
    await select('Năm', 0);
    expect(date, DateTime(2023, 11, 4));
    await select('Tháng', 0);
    expect(date, DateTime(2023, 10, 15));
    expect(tester.takeException(), isNull);
  });

  testWidgets('only recorded teeth have numbers in tracking mode', (
    tester,
  ) async {
    final tooth = PrimaryTooth.all.first;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ToothChart(
            eruptedIds: {tooth.id},
            ageMonths: 12,
            showPairNumbers: true,
            onToothTap: (_) {},
          ),
        ),
      ),
    );
    for (final item in PrimaryTooth.all) {
      expect(
        find.byKey(Key('reference-pair-${item.id}')),
        item.id == tooth.id ? findsOneWidget : findsNothing,
      );
      final illustration = tester.widget<ToothIllustration>(
        find.descendant(
          of: find.byKey(Key('tooth-target-${item.id}')),
          matching: find.byType(ToothIllustration),
        ),
      );
      expect(illustration.erupted, item.id == tooth.id);
      expect(
        illustration.expected,
        item.id != tooth.id && item.eruptionMonths.$1 <= 12,
      );
      final opacity = tester.widget<AnimatedOpacity>(
        find.descendant(
          of: find.byKey(Key('tooth-target-${item.id}')),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(
        opacity.opacity,
        item.id == tooth.id
            ? 1
            : item.eruptionMonths.$1 <= 12
            ? .72
            : .55,
      );
    }
  });
}
