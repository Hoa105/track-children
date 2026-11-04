import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/teething/teething_date_picker.dart';
import 'package:track_children/features/teething/tooth_chart.dart';
import 'package:track_children/models/tooth.dart';

void main() {
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
            ageMonths: 60,
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
      expect(illustration.expected, isFalse);
      expect(illustration.erupted, item.id == tooth.id);
    }
  });
}
