import 'package:flutter/material.dart';
import 'package:track_children/features/teething/teething_age_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/teething/teething_reference_data.dart';
import 'package:track_children/features/teething/teething_reference_tab.dart';
import 'package:track_children/models/tooth.dart';
import 'package:track_children/features/teething/tooth_chart.dart';

void main() {
  testWidgets(
    'large tooth targets select the correct tooth on a narrow screen',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      addTearDown(tester.view.reset);
      PrimaryTooth? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToothChart(
              eruptedIds: PrimaryTooth.all.map((tooth) => tooth.id).toSet(),
              ageMonths: 12,
              showPairNumbers: true,
              onToothTap: (tooth) => selected = tooth,
            ),
          ),
        ),
      );
      for (final tooth in PrimaryTooth.all) {
        final target = find.byKey(Key('tooth-target-${tooth.id}'));
        expect(tester.getSize(target).width, greaterThanOrEqualTo(56));
        final number = find.byKey(Key('reference-pair-${tooth.id}'));
        final targetRect = tester.getRect(target);
        final numberRect = tester.getRect(number);
        expect(numberRect.center.dx, closeTo(targetRect.center.dx, .1));
        expect(numberRect.bottom, lessThan(targetRect.center.dy));
        expect(targetRect.contains(numberRect.bottomRight), isTrue);
        await tester.tap(target);
        expect(selected?.id, tooth.id);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('age strip scrolls through intermediate positions', (
    tester,
  ) async {
    var month = 8;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Scaffold(
              body: TeethingAgeSelector(
                month: month,
                currentMonth: 8,
                maxMonth: 60,
                onChanged: (value) => setState(() => month = value),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scroll = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const Key('teething-age-selector')),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    final start = scroll.pixels;
    update(() => month = 25);
    await tester.pump();
    expect(scroll.pixels, start);
    // Start the ticker scheduled by the post-layout centering callback.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final middle = scroll.pixels;
    await tester.pumpAndSettle();
    expect(middle, greaterThan(start));
    expect(middle, lessThan(scroll.pixels));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tooth color interpolates and respects reduced motion', (
    tester,
  ) async {
    var reference = false;
    var reducedMotion = false;
    late StateSetter update;
    // Keep the illustration mounted while changing its target palette.
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MediaQuery(
              data: MediaQueryData(disableAnimations: reducedMotion),
              child: Center(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: ToothIllustration(
                    erupted: false,
                    reference: reference,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    CustomPainter painter() => tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(ToothIllustration),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter!;
    final initial = painter();
    update(() => reference = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final middle = painter();
    await tester.pumpAndSettle();
    final end = painter();
    expect(middle.shouldRepaint(initial), isTrue);
    expect(end.shouldRepaint(middle), isTrue);
    update(() {
      reference = false;
      reducedMotion = true;
    });
    await tester.pumpAndSettle();
    expect(painter().shouldRepaint(initial), isFalse);
  });

  test('reference schedule matches the supplied 0–60 month table', () {
    expect(TeethingReferenceData.possibleTeethCountAt(0), 0);
    expect(TeethingReferenceData.possibleTeethCountAt(5), 0);
    expect(TeethingReferenceData.possibleTeethCountAt(6), 2);
    expect(TeethingReferenceData.possibleTeethCountAt(10), 8);
    expect(TeethingReferenceData.possibleTeethCountAt(23), 18);
    expect(TeethingReferenceData.possibleTeethCountAt(25), 20);
    expect(TeethingReferenceData.possibleTeethCountAt(60), 20);
    expect(TeethingReferenceData.pairCodesAt(10), {1, 2, 3, 4});
  });

  test('all primary teeth have unique valid FDI identifiers', () {
    final codes = PrimaryTooth.all.map((tooth) => tooth.fdiCode).toSet();
    expect(codes, hasLength(20));
    expect(
      codes,
      containsAll(['51', '61', '71', '81', '55', '65', '75', '85']),
    );
  });

  for (final width in [320.0, 390.0, 700.0]) {
    testWidgets('age selection and pair numbers at $width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1100);
      addTearDown(tester.view.reset);
      var month = 7;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: Column(
                  children: [
                    TeethingAgeSelector(
                      month: month,
                      currentMonth: 7,
                      maxMonth: 60,
                      onChanged: (value) => setState(() => month = value),
                    ),
                    Expanded(
                      child: TeethingReferenceTab(initialAgeMonths: month),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(Slider), findsNothing);
      await tester.pumpAndSettle();
      expect(
        tester.widget<ToothChart>(find.byType(ToothChart)).referenceIds,
        hasLength(2),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('reference-age-10')),
        100,
        scrollable: find.descendant(
          of: find.byKey(const Key('teething-age-selector')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reference-age-10')));
      await tester.pumpAndSettle();
      final chart = tester.widget<ToothChart>(find.byType(ToothChart));
      expect(chart.referenceIds, hasLength(8));
      expect(chart.onToothTap, isNull);
      for (final tooth in PrimaryTooth.all) {
        expect(
          tester
              .widget<Text>(find.byKey(Key('reference-pair-${tooth.id}')))
              .data,
          '${tooth.pairCode}',
        );
      }
      await tester.scrollUntilVisible(
        find.byKey(const Key('reference-age-25')),
        150,
        scrollable: find.descendant(
          of: find.byKey(const Key('teething-age-selector')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reference-age-25')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ToothChart>(find.byType(ToothChart)).referenceIds,
        hasLength(20),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tapping a reference tooth selects its pair eruption month', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.reset);
    var month = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: TeethingReferenceTab(
              initialAgeMonths: month,
              onMonthSelected: (value) => setState(() => month = value),
            ),
          ),
        ),
      ),
    );

    final tooth = PrimaryTooth.all.firstWhere(
      (item) => item.pairCode == 10,
    );
    await tester.tap(find.byKey(Key('tooth-target-${tooth.id}')));
    await tester.pumpAndSettle();

    expect(month, tooth.eruptionMonths.$1);
    expect(month, 25);
    expect(tester.widget<ToothChart>(find.byType(ToothChart)).ageMonths, 25);
    for (final pairTooth in TeethingReferenceData.pair(tooth.pairCode)) {
      final selectedIllustration = tester.widget<ToothIllustration>(
        find.descendant(
          of: find.byKey(Key('tooth-target-${pairTooth.id}')),
          matching: find.byType(ToothIllustration),
        ),
      );
      expect(selectedIllustration.selectedReference, isTrue);
    }
    expect(
      tester
          .widget<ToothChart>(find.byType(ToothChart))
          .selectedReferenceId,
      tooth.id,
    );
  });
}
