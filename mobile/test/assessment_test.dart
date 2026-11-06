import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/services/demo_store.dart';
import 'package:track_children/services/app_notifications.dart';
import 'package:track_children/features/assessment/assessment_reminders.dart';
import 'package:track_children/features/assessment/assessment_models.dart';
import 'package:track_children/features/assessment/assessment_repository.dart';
import 'package:track_children/features/assessment/assessment_screen.dart';
import 'package:track_children/features/assessment/assessment_question_screen.dart';
import 'package:track_children/features/assessment/assessment_result_screen.dart';
import 'package:track_children/features/assessment/assessment_widgets.dart';

Map<String, dynamic> clone(Map<String, dynamic> m) =>
    assessmentMap(jsonDecode(jsonEncode(m)));

class FakeAssessmentRepository implements AssessmentRepository {
  bool failSave = false, failLoad = false;
  int starts = 0;
  Map<String, dynamic>? row;
  final completed = <Map<String, dynamic>>[];
  @override
  bool get isDemo => false;
  final List<Map<String, dynamic>> questions = [
    for (var i = 0; i < 2; i++)
      {
        'id': 'q$i',
        'code': 'q$i',
        'domain': i == 0 ? 'gross_motor' : 'language_communication',
        'payload': {
          'question_vi': 'Câu hỏi kỹ năng số ${i + 1}',
          'instruction_vi': 'Quan sát bé trong lúc vui chơi hằng ngày.',
          'skill_name': 'Kỹ năng ${i + 1}',
          'media': [],
        },
        'source_refs': [],
      },
  ];
  @override
  Future<Map<String, dynamic>> overview(String c) async {
    if (failLoad) throw const AssessmentProblem('Chưa tải được dữ liệu');
    return {
      'age_months': 12,
      'can_edit': true,
      'guidance_required': false,
      'set': {'id': 'set', 'count': 2},
      'draft': row?['status'] == 'in_progress' ? clone(row!) : null,
      'today': '2026-11-06',
      'past_drafts': [],
      'completed_milestones': completed.isEmpty ? [] : [12],
      'latest_completed': completed.isEmpty
          ? null
          : {'id': completed.last['id']},
      'milestones': [
        {'age_months': 9, 'opens_on': '2026-08-01', 'closes_on': '2026-11-01'},
        {'age_months': 12, 'opens_on': '2026-11-01', 'closes_on': '2027-02-01'},
        {'age_months': 15, 'opens_on': '2027-02-01', 'closes_on': '2027-05-01'},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> history(
    String c, {
    int? age,
    int offset = 0,
  }) async => {
    'items': completed
        .where((r) => age == null || age == 12)
        .map(
          (r) => {
            'id': r['id'],
            'age_months': 12,
            'completed_at': r['completed_at'],
            'attempt_number': 1,
            'summary': r['result']['sections']['overview'],
          },
        )
        .toList(),
    'has_more': false,
  };
  @override
  Future<AssessmentAttempt> start(
    String c,
    String id, {
    bool guidance = false,
  }) async {
    starts++;
    row ??= {
      'id': id,
      'age_months': 12,
      'status': 'in_progress',
      'version': 1,
      'answers': <String, String>{},
      'questions': questions,
      'editable': true,
      'regression': null,
      'caregiver_concern': null,
      'result': null,
    };
    return AssessmentAttempt(clone(row!));
  }

  @override
  Future<AssessmentAttempt> load(String c, String id) async =>
      AssessmentAttempt(
        clone(completed.where((r) => r['id'] == id).firstOrNull ?? row!),
      );
  @override
  Future<AssessmentAttempt> save(
    String c,
    AssessmentAttempt a,
    Map<String, String> answers,
    String? regression,
    String? concern,
  ) async {
    if (failSave) throw const AssessmentProblem('Chưa kết nối được máy chủ');
    row = {
      ...a.data,
      'version': a.version + 1,
      'answers': answers,
      'regression': regression,
      'caregiver_concern': concern,
    };
    return AssessmentAttempt(clone(row!));
  }

  @override
  Future<AssessmentAttempt> complete(String c, AssessmentAttempt a) async {
    final n = a.answers.values.where((v) => v == 'not_yet').length,
        o = a.answers.values.where((v) => v == 'not_observed').length;
    row = {
      ...a.data,
      'status': 'completed',
      'editable': false,
      'completed_at': '2026-11-06T09:30:00+07:00',
      'result': {
        'sections': {
          'overview': {'achieved': 2 - n - o, 'not_yet': n, 'not_observed': o},
          'skills_to_note': {
            'all': [
              for (final q in questions)
                if (a.answers[q['code']] != 'achieved')
                  {
                    'question_id': q['code'],
                    'domain': q['domain'],
                    'skill_name': q['payload']['skill_name'],
                    'status': a.answers[q['code']],
                  },
            ],
          },
          'overall_comment': {
            'paragraphs': [
              {
                'id': 'skills',
                'text': 'Kết quả bài đánh giá ghi nhận kỹ năng cần chú ý.',
              },
            ],
            'sources': [],
          },
          'next_steps': {
            'action_plan': {
              'actions': [
                {
                  'id': 'contact',
                  'body': 'Trao đổi với nhân viên y tế có chuyên môn.',
                  'items': [],
                },
                {
                  'id': 'prepare',
                  'body': '',
                  'items': ['Ghi lại kỹ năng và thời điểm quan sát.'],
                },
              ],
              'observation_timing': '',
            },
          },
        },
      },
    };
    completed.add(clone(row!));
    return AssessmentAttempt(clone(row!));
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
    await DemoStore.instance.login(DemoStore.demoEmail, DemoStore.password);
    await DemoStore.instance.selectChild('child_an');
  });
  test('demo history migrates the previous storage key without losing answers', () async {
    final prefs = await SharedPreferences.getInstance();
    final repo = DemoAssessmentRepository();
    final currentKey = repo.key('child_an');
    final oldKey = currentKey.replaceFirst('assessment_demo_v1/', 'development_demo_v1/');
    final stored = [{'id': 'saved-attempt', 'answers': {'q1': 'achieved'}}];
    await prefs.setString(oldKey, jsonEncode(stored));
    expect(await repo.rows('child_an'), stored);
    expect(prefs.getString(currentKey), jsonEncode(stored));
    expect(prefs.containsKey(oldKey), isFalse);
    expect(await repo.rows('child_other'), isEmpty);
  });
  test('calendar windows skip missed ages and include full 60th month', () {
    final b = DateTime(2021, 1, 31);
    expect(monthAnniversary(b, 1), DateTime(2021, 2, 28));
    expect(assessmentAge(b, DateTime(2022, 3, 1)), 12);
    expect(assessmentAge(b, DateTime(2026, 2, 20)), 60);
    expect(assessmentAge(b, DateTime(2026, 2, 28)), isNull);
  });
  testWidgets(
    'complete skill assessment, open result and immutable answers from history',
    (tester) async {
      final repo = FakeAssessmentRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: AssessmentScreen(childId: 'child_an', repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bắt đầu đánh giá'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bắt đầu đánh giá').last);
      await tester.tap(find.text('Bắt đầu đánh giá').last);
      await tester.pumpAndSettle();
      expect(find.byType(AssessmentChoice), findsNWidgets(3));
      expect(
        tester
            .widgetList<AssessmentChoice>(find.byType(AssessmentChoice))
            .every((x) => !x.selected),
        isTrue,
      );
      await tester.ensureVisible(find.text('Chưa làm được'));
      await tester.tap(find.text('Chưa làm được'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Câu tiếp theo'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Chưa quan sát').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chưa quan sát').first);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Câu tiếp theo'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Xem kết quả'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Không').first);
      await tester.tap(find.text('Không').first);
      await tester.pump();
      await tester.ensureVisible(find.text('Không').last);
      await tester.tap(find.text('Không').last);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Xem kết quả'));
      await tester.pumpAndSettle();
      expect(find.text('Kết quả đánh giá'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Hướng dẫn tiếp theo'), 400);
      expect(find.text('Hướng dẫn tiếp theo'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Xem lại đáp án'), 300);
      await tester.tap(find.text('Xem lại đáp án'));
      await tester.pumpAndSettle();
      expect(find.byType(AssessmentAnswersScreen), findsOneWidget);
      expect(find.byType(AssessmentChoice), findsNothing);
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Về đánh giá'), 300);
      await tester.tap(find.text('Về đánh giá'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lịch sử'));
      await tester.pumpAndSettle();
      expect(find.text('Mốc 12 tháng'), findsOneWidget);
      expect(repo.completed.length, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed save retains answer locally and never enables silent completion',
    (tester) async {
      final repo = FakeAssessmentRepository()..failSave = true;
      final a = await repo.start('child_an', 'attempt-offline');
      await tester.pumpWidget(
        MaterialApp(
          home: AssessmentQuestionScreen(
            childId: 'child_an',
            attempt: a,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Đã làm được'));
      await tester.tap(find.text('Đã làm được'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.textContaining('chưa đồng bộ'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().any((k) => k.startsWith('assessment_pending/')),
        isTrue,
      );
      expect(repo.completed, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final width in [320.0, 430.0]) {
    testWidgets('assessment layouts fit width $width at large text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1000);
      addTearDown(tester.view.reset);
      final repo = FakeAssessmentRepository();
      Widget wrap(Widget screen) => MaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: screen,
      );
      await tester.pumpWidget(
        wrap(AssessmentScreen(childId: 'child_an', repository: repo)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final a = await repo.start('child_an', 'layout');
      await tester.pumpWidget(
        wrap(
          AssessmentQuestionScreen(
            childId: 'child_an',
            attempt: a,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Chưa quan sát').first, 200);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      final saved = await repo.save(
        'child_an',
        a,
        {'q0': 'not_yet', 'q1': 'not_observed'},
        'no',
        'no',
      );
      final completed = await repo.complete('child_an', saved);
      await tester.pumpWidget(
        wrap(
          AssessmentResultScreen(
            childId: 'child_an',
            attempt: completed,
            isDemo: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Hướng dẫn tiếp theo'), 300);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        wrap(
          AssessmentScreen(
            childId: 'child_an',
            initialHistory: true,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('history empty and error are distinct states', (tester) async {
    final repo = FakeAssessmentRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: AssessmentScreen(
          childId: 'child_an',
          initialHistory: true,
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa có bài đánh giá'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    repo.failLoad = true;
    await tester.pumpWidget(
      MaterialApp(
        home: AssessmentScreen(childId: 'child_an', repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa tải được dữ liệu'), findsOneWidget);
    expect(find.text('Chưa có bài đánh giá'), findsNothing);
  });
  test('demo saves resumable answers, isolates children and expires missed milestones', () async {
    final birth = DateTime.parse(
      DemoStore.instance.childById('child_an')!['date_of_birth'] as String,
    );
    var clock = monthAnniversary(birth, 12);
    final repo = DemoAssessmentRepository(clock: () => clock);
    final a = await repo.start('child_an', 'demo-attempt');
    final saved = await repo.save(
      'child_an',
      a,
      {for (final q in a.questions) q['code'] as String: 'achieved'},
      'no',
      'no',
    );
    expect(
      (await repo.load('child_an', a.id)).answers.length,
      a.questions.length,
    );
    final done = await repo.complete('child_an', saved);
    expect((await repo.history('child_an'))['items'], hasLength(1));
    expect((await repo.history('child_linh'))['items'], isEmpty);
    expect((await repo.complete('child_an', saved)).result, done.result);
    final draft = await repo.start('child_an', 'next-attempt');
    clock = monthAnniversary(birth, 15);
    expect((await repo.overview('child_an'))['age_months'], 15);
    expect((await repo.overview('child_an'))['draft'], isNull);
    expect((await repo.load('child_an', draft.id)).editable, isFalse);
    await expectLater(
      repo.complete('child_an', draft),
      throwsA(isA<AssessmentProblem>()),
    );
  });
  test('assessment reminders use fixed ids and stop after completion or milestone change', () {
    final store = DemoStore.instance, child = store.child!;
    final c = child['id'] as String;
    final state = {
      'age_months': 12,
      'set': {'count': 2},
      'completed_milestones': [],
      'milestones': [
        {'age_months': 12, 'opens_on': '2026-11-01'},
      ],
    };
    AssessmentReminders.instance.put(c, state);
    List<CareNotification> reminders(DateTime d) => careNotifications(
      store,
      now: d,
    ).where((n) => n.kind == 'assessment').toList();
    expect(
      reminders(DateTime(2026, 11, 1)).single.id,
      '$c:assessment:12:open',
    );
    expect(
      reminders(DateTime(2026, 11, 8)).single.id,
      '$c:assessment:12:repeat',
    );
    expect(reminders(DateTime(2026, 12, 2)), isEmpty);
    AssessmentReminders.instance.put(c, {
      ...state,
      'completed_milestones': [12],
    });
    expect(reminders(DateTime(2026, 11, 8)), isEmpty);
  });
}
