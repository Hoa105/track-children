import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/assessment/assessment_question_screen.dart';

import 'assessment_test.dart' show FakeAssessmentRepository;

import 'package:track_children/features/assessment/assessment_video.dart';
import 'package:track_children/features/assessment/assessment_widgets.dart';

void main() {
  testWidgets(
    'one video surface follows scroll and survives fullscreen moves',
    (tester) async {
      final fullscreen = ValueNotifier(false);
      final scroll = ScrollController();
      var disposed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssessmentVideoViewport(
              child: ListView(
                controller: scroll,
                children: [
                  const SizedBox(height: 160),
                  SizedBox(
                    height: 220,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: fullscreen,
                      builder: (_, value, _) => AssessmentVideoSurface(
                        fullscreen: value,
                        onExitFullscreen: () => fullscreen.value = false,
                        child: _FakePlayer(onDispose: () => disposed++),
                      ),
                    ),
                  ),
                  const SizedBox(height: 1000),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final player = find.byType(_FakePlayer);
      final state = tester.state(player);
      final originalTop = tester.getTopLeft(player).dy;
      scroll.jumpTo(70);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(player).dy, closeTo(originalTop - 70, 0.1));
      expect(player, findsOneWidget);
      fullscreen.value = true;
      await tester.pumpAndSettle();
      expect(player, findsOneWidget);
      expect(tester.state(player), same(state));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(fullscreen.value, isFalse);
      expect(player, findsOneWidget);
      expect(tester.state(player), same(state));
      expect(tester.getTopLeft(player).dy, closeTo(originalTop - 70, 0.1));
      expect(disposed, 0);
      await tester.pumpWidget(const SizedBox());
      expect(disposed, 1);
      fullscreen.dispose();
      scroll.dispose();
    },
  );

  testWidgets(
    'question progress scrolls with content and resets on next question',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 650);
      addTearDown(tester.view.reset);
      final repo = FakeAssessmentRepository();
      final attempt = await repo.start('child_an', 'scroll-progress');
      await tester.pumpWidget(
        MaterialApp(
          home: AssessmentQuestionScreen(
            childId: 'child_an',
            attempt: attempt,
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final progress = find.byType(AssessmentProgress);
      final initialY = tester.getTopLeft(progress).dy;
      await tester.drag(find.byType(ListView), const Offset(0, -80));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(progress).dy, lessThan(initialY - 40));
      expect(find.text('Câu tiếp theo').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Câu tiếp theo'));
      await tester.pumpAndSettle();
      expect(find.text('Câu 2/2').hitTestable(), findsOneWidget);
      expect(tester.getTopLeft(progress).dy, closeTo(initialY, 1));
      AssessmentVideoPlayback.fullscreen.value = true;
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Câu tiếp theo'), findsNothing);
      expect(
        tester.getSize(find.byType(AssessmentVideoViewport)),
        const Size(390, 650),
      );
      AssessmentVideoPlayback.fullscreen.value = false;
      await tester.pumpAndSettle();
      expect(find.text('Câu tiếp theo').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('inline video portals cannot cover controls above the viewport', (
    tester,
  ) async {
    final portal = OverlayPortalController();
    var headerTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                height: 80,
                child: TextButton(
                  onPressed: () => headerTaps++,
                  child: const Text('Header'),
                ),
              ),
              Expanded(
                child: AssessmentVideoViewport(
                  child: OverlayPortal(
                    controller: portal,
                    overlayChildBuilder: (_) => Positioned(
                      top: -80,
                      left: 0,
                      right: 0,
                      height: 300,
                      child: GestureDetector(
                        onTap: () {},
                        child: const ColoredBox(color: Colors.black),
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    portal.show();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Header'));
    expect(headerTaps, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

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
