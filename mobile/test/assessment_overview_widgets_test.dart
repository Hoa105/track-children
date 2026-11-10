import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/assessment/assessment_overview_widgets.dart';

void main() {
  testWidgets(
    'milestone selection changes details and opens only completed history',
    (tester) async {
      int? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssessmentMilestones(
              milestones: const [
                {
                  'age_months': 9,
                  'opens_on': '2026-08-01',
                  'closes_on': '2026-11-01',
                },
                {
                  'age_months': 12,
                  'opens_on': '2026-11-01',
                  'closes_on': '2027-02-01',
                },
                {
                  'age_months': 15,
                  'opens_on': '2027-02-01',
                  'closes_on': '2027-05-01',
                },
              ],
              today: DateTime(2026, 11, 6),
              currentAge: 12,
              completed: {9},
              draftAge: null,
              onHistory: (age) => opened = age,
            ),
          ),
        ),
      );
      expect(find.text('Mốc 12 tháng'), findsOneWidget);
      expect(find.text('Xem lịch sử'), findsNothing);
      await tester.tap(find.text('15 tháng'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Chưa đến ·'), findsOneWidget);
      expect(find.text('Xem lịch sử'), findsNothing);
      await tester.tap(find.text('9 tháng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem lịch sử'));
      expect(opened, 9);
      expect(tester.takeException(), isNull);
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets('age filter selects, cancels and clears at text scale $scale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 760);
      addTearDown(tester.view.reset);
      int? age;
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => AssessmentAgeFilter(
                age: age,
                onChanged: (value) => update(() {
                  age = value;
                  calls++;
                }),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Tất cả mốc tuổi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2 tháng'));
      await tester.pumpAndSettle();
      expect(age, 2);
      expect(calls, 1);
      await tester.tap(find.text('2 tháng'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Đóng bộ lọc'));
      await tester.pumpAndSettle();
      expect(age, 2);
      expect(calls, 1);
      await tester.tap(find.text('2 tháng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tất cả mốc tuổi'));
      await tester.pumpAndSettle();
      expect(age, isNull);
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    });
  }
}
