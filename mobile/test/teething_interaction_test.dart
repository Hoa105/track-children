import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/teething/teething_age_selector.dart';
import 'package:track_children/features/teething/teething_screen.dart';
import 'package:track_children/features/teething/tooth_chart.dart';
import 'package:track_children/models/tooth.dart';
import 'package:track_children/services/demo_store.dart';

void main() {
  testWidgets('selecting a visible month does not move the age strip', (
    tester,
  ) async {
    var month = 6;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => TeethingAgeSelector(
              month: month,
              currentMonth: 24,
              maxMonth: 60,
              onChanged: (value) => update(() => month = value),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
    final offset = scroll.position.pixels;
    await tester.tap(find.byKey(const Key('reference-age-7')));
    await tester.pumpAndSettle();
    expect(month, 7);
    expect(scroll.position.pixels, offset);
  });

  testWidgets('external age update does not interrupt a drag', (tester) async {
    var month = 6;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return TeethingAgeSelector(
                month: month,
                currentMonth: 24,
                maxMonth: 60,
                onChanged: (value) => setState(() => month = value),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TeethingAgeSelector)),
    );
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();
    final offset = scroll.position.pixels;
    update(() => month = 25);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(scroll.position.pixels, offset);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reference taps update next frame without rebuilding tracking chart',
    (tester) async {
      DemoStore.resetInstanceForTesting();
      SharedPreferences.setMockInitialValues({});
      final childId = await DemoStore.instance.saveChild(null, {
        'full_name': 'Interaction test',
        'date_of_birth': '2025-01-01',
        'gender': 'female',
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 1000);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: TeethingScreen(childId: childId)),
      );
      await tester.pumpAndSettle();
      ToothChart tracking() => tester
          .widgetList<ToothChart>(find.byType(ToothChart, skipOffstage: false))
          .singleWhere((chart) => chart.referenceIds == null);
      final before = tracking();
      final tooth = PrimaryTooth.all.firstWhere(
        (tooth) => tooth.pairCode == 10,
      );
      await tester.tap(find.byKey(Key('tooth-target-${tooth.id}')));
      await tester.pump();
      final reference = tester.widget<ToothChart>(find.byType(ToothChart));
      expect(reference.ageMonths, tooth.eruptionMonths.$1);
      expect(reference.selectedReferenceId, tooth.id);
      expect(identical(tracking(), before), isTrue);
      await tester.pumpAndSettle();
      final referenceBeforeSwitch = tester.widget<ToothChart>(
        find.byType(ToothChart),
      );
      await tester.tap(find.byKey(const Key('teething-tab-child')));
      await tester.pumpAndSettle();
      expect(identical(tracking(), before), isTrue);
      final hiddenReference = find.byWidgetPredicate(
        (widget) => widget is ToothChart && widget.referenceIds != null,
        skipOffstage: false,
      );
      expect(
        identical(
          tester.widget<ToothChart>(hiddenReference),
          referenceBeforeSwitch,
        ),
        isTrue,
      );
      expect(
        TickerMode.valuesOf(tester.element(hiddenReference)).enabled,
        isFalse,
      );
      expect(
        TickerMode.valuesOf(tester.element(find.byType(ToothChart))).enabled,
        isTrue,
      );
      await tester.tap(find.byKey(const Key('teething-tab-reference')));
      await tester.pumpAndSettle();
      expect(
        identical(
          tester.widget<ToothChart>(find.byType(ToothChart)),
          referenceBeforeSwitch,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
