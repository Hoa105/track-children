import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/assessment/assessment_home_card.dart';
import 'package:track_children/features/assessment/assessment_repository.dart';
import 'package:track_children/features/assessment/assessment_screen.dart';

class ReminderRepository extends Fake implements AssessmentRepository {
  ReminderRepository(this.value, {this.fail = false});
  Map<String, dynamic> value;
  final bool fail;
  @override
  bool get isDemo => true;
  @override
  Future<Map<String, dynamic>> overview(String childId) async {
    if (fail) throw StateError('offline');
    return value;
  }

  @override
  Future<Map<String, dynamic>> history(
    String childId, {
    int? age,
    int offset = 0,
  }) async => {'items': [], 'has_more': false};
}

void main() {
  final due = <String, dynamic>{
    'age_months': 9,
    'set': {'count': 10},
    'latest_completed': null,
    'draft': null,
    'today': '2026-11-16',
    'milestones': [],
    'can_edit': true,
  };
  for (final scenario in ['not_due', 'completed', 'unavailable', 'offline']) {
    testWidgets('reminder collapses for $scenario', (tester) async {
      final value = {...due};
      if (scenario == 'not_due') value['age_months'] = null;
      if (scenario == 'completed') value['latest_completed'] = {'id': 'done'};
      if (scenario == 'unavailable') value['set'] = null;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AssessmentHomeCard(
                  childId: 'child',
                  reminderOnly: true,
                  repository: ReminderRepository(
                    value,
                    fail: scenario == 'offline',
                  ),
                ),
                const SizedBox(key: ValueKey('next'), height: 10),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('home-assessment-reminder')),
        findsNothing,
      );
      expect(tester.getTopLeft(find.byKey(const ValueKey('next'))).dy, 0);
      expect(tester.takeException(), isNull);
    });
  }
  for (final draft in [false, true]) {
    testWidgets(
      'due reminder supports draft=$draft and refreshes after navigation',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 800);
        addTearDown(tester.view.reset);
        final repo = ReminderRepository({
          ...due,
          if (draft)
            'draft': {
              'id': 'draft',
              'answers': {},
              'questions': [{}],
            },
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AssessmentHomeCard(
                childId: 'child',
                reminderOnly: true,
                repository: repo,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final cta = find.text(draft ? 'Tiếp tục đánh giá' : 'Đánh giá ngay');
        expect(cta, findsOneWidget);
        expect(find.text('Đến lịch đánh giá phát triển'), findsOneWidget);
        await tester.tap(cta);
        await tester.pumpAndSettle();
        expect(find.byType(AssessmentScreen), findsOneWidget);
        expect(
          tester
              .widget<AssessmentScreen>(find.byType(AssessmentScreen))
              .childId,
          'child',
        );
        repo.value = {
          ...due,
          'latest_completed': {'id': 'done'},
        };
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('home-assessment-reminder')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
