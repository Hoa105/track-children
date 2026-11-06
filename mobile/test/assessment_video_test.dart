import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/assessment/assessment_question_screen.dart';

import 'assessment_test.dart' show FakeAssessmentRepository;

import 'package:track_children/features/assessment/assessment_video.dart';
import 'package:track_children/features/assessment/assessment_widgets.dart';

void main() {
  testWidgets('Back in fullscreen does not leave or complete the assessment', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = FakeAssessmentRepository();
    final a = await repo.start('child_an', 'fullscreen-test');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => AssessmentQuestionScreen(
                    childId: 'child_an',
                    attempt: a,
                    repository: repo,
                  ),
                ),
              ),
              child: const Text('Open assessment'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open assessment'));
    await tester.pumpAndSettle();
    AssessmentVideoPlayback.fullscreen.value = true;
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AssessmentQuestionScreen), findsOneWidget);
    expect(repo.completed, isEmpty);
    AssessmentVideoPlayback.fullscreen.value = false;
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AssessmentQuestionScreen), findsNothing);
  });

  testWidgets(
    'video has a large inline frame and only starts after a play tap',
    (tester) async {
      var created = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: AssessmentVideoFrame(
                videoId: 'WNXmcmAyC98',
                playerBuilder: (id) {
                  created++;
                  return Text('Inline player: $id');
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.byKey(const ValueKey('assessment-video-surface')))
            .height,
        greaterThanOrEqualTo(220),
      );
      expect(created, 0);
      expect(find.text('Xem video hướng dẫn'), findsNothing);
      await tester.tap(find.byIcon(Icons.play_circle_fill_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Inline player: WNXmcmAyC98'), findsOneWidget);
      expect(created, 1);
    },
  );
  testWidgets(
    'changing question video disposes playback and returns to preview',
    (tester) async {
      final id = ValueNotifier('WNXmcmAyC98');
      var disposed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: id,
              builder: (context, value, _) => AssessmentVideoFrame(
                videoId: value,
                playerBuilder: (id) => _FakePlayer(onDispose: () => disposed++),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.play_circle_fill_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(_FakePlayer), findsOneWidget);
      id.value = 'nGCOOQU9Hdk';
      await tester.pumpAndSettle();
      expect(disposed, 1);
      expect(find.byType(_FakePlayer), findsNothing);
      expect(find.byIcon(Icons.play_circle_fill_rounded), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      id.dispose();
    },
  );
  testWidgets(
    'question and answer review use embedded media instead of an external video button',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: assessmentMedia({
                'skill_name': 'Kỹ năng thử',
                'media': {
                  'type': 'youtube',
                  'youtube_id': 'WNXmcmAyC98',
                  'attribution': 'CDC',
                },
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AssessmentVideoFrame), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Xem video hướng dẫn'),
        findsNothing,
      );
      expect(find.text('CDC'), findsOneWidget);
    },
  );
  for (final width in [320.0, 430.0, 760.0]) {
    testWidgets(
      'inline video fits $width with large text and missing thumbnail',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(36),
                child: AssessmentVideoFrame(
                  videoId: 'WNXmcmAyC98',
                  caption: 'CDC — Milestones in Action',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.play_circle_fill_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'invalid video does not initialize a player or block the question',
    (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssessmentVideoFrame(
              videoId: 'invalid',
              playerBuilder: (_) {
                called = true;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Video chưa có thông tin hợp lệ'),
        findsOneWidget,
      );
      expect(called, isFalse);
      expect(find.byIcon(Icons.play_circle_fill_rounded), findsNothing);
    },
  );
}

class _FakePlayer extends StatefulWidget {
  const _FakePlayer({required this.onDispose});
  final VoidCallback onDispose;
  @override
  State<_FakePlayer> createState() => _FakePlayerState();
}

class _FakePlayerState extends State<_FakePlayer> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Text('Playing inline');
}
