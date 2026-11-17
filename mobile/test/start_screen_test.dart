import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/splash/start_screen.dart';
import 'package:track_children/features/splash/splash_screen.dart';

Future<void> loadPoses(WidgetTester tester) async {
  final context = tester.element(find.byType(StartScreen));
  await tester.runAsync(() async {
    for (final pose in ['idle', 'happy', 'welcome']) {
      await precacheImage(
        AssetImage(
          'assets/images/scenery/backgrounds/start-assets/mascot/$pose.png',
        ),
        context,
      );
    }
  });
  await tester.pump();
  // Establish the ticker timestamp after the first decoded frame starts it.
  await tester.pump();
}

class MissingMascotBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key.contains('/mascot/')) {
      return Future.error(StateError('Simulated missing mascot'));
    }
    return rootBundle.load(key);
  }
}

class DelayedStartBundle extends CachingAssetBundle {
  final ready = Completer<void>();
  @override
  Future<ByteData> load(String key) async {
    if (key.contains('/mascot/')) await ready.future;
    return rootBundle.load(key);
  }
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          startLaunchChannel,
          (_) async => {'supported': false},
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(startLaunchChannel, null);
  });
  testWidgets('title is visible in its final position before artwork loads', (
    tester,
  ) async {
    final bundle = DelayedStartBundle();
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: bundle,
          child: StartScreen(onLoginRequired: () {}),
        ),
      ),
    );
    final title = find.byKey(const ValueKey('start-title'));
    final initial = tester.getRect(title);
    expect(initial.center.dy, lessThan(tester.view.physicalSize.height / 2));
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: title, matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, 1);
    bundle.ready.complete();
    await loadPoses(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getRect(title), initial);
    expect(find.byKey(const ValueKey('launch-wordmark')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('slow image decoding does not skip the first animation poses', (
    tester,
  ) async {
    final bundle = DelayedStartBundle();
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: bundle,
          child: StartScreen(onLoginRequired: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('idle')), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
    bundle.ready.complete();
    await loadPoses(tester);
    expect(find.byKey(const ValueKey('idle')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 550));
    expect(find.byKey(const ValueKey('happy')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'Start renders before initialization and waits for it to finish',
    (tester) async {
      final ready = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StartScreen(
            onLoginRequired: () {},
            initialize: () {
              calls++;
              return ready.future;
            },
          ),
        ),
      );
      expect(find.text('Bé lớn khôn'), findsOneWidget);
      final titleOpacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('Bé lớn khôn'),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(titleOpacity.opacity, 1);
      final sloganOpacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('Cùng con lớn khôn mỗi ngày'),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(sloganOpacity.opacity, 0);
      await loadPoses(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byKey(const ValueKey('welcome')), findsOneWidget);
      ready.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('initialization failure stays on Start and can retry', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StartScreen(
          onLoginRequired: () {},
          initialize: () async {
            if (++calls == 1) throw StateError('startup failed');
          },
        ),
      ),
    );
    await loadPoses(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(SplashScreen), findsNothing);
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('asset failure still advances without an error widget', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: MissingMascotBundle(),
          child: StartScreen(onLoginRequired: () {}),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('unmount during mascot animation cancels timer and ticker', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: StartScreen(onLoginRequired: () {})),
    );
    await loadPoses(tester);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(320, 568),
    const Size(360, 800),
    const Size(430, 932),
  ]) {
    testWidgets('Start safe area and large text at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(home: StartScreen(onLoginRequired: () {})),
      );
      await loadPoses(tester);
      await tester.pump(const Duration(milliseconds: 1200));
      expect(
        tester.getRect(find.text('Bé lớn khôn')).top,
        greaterThanOrEqualTo(24),
      );
      expect(
        tester.getRect(find.text('Cùng con lớn khôn mỗi ngày')).bottom,
        lessThan(size.height - 24),
      );
      expect(find.byKey(const ValueKey('welcome')), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byType(SplashScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('pose timeline finishes once and disposes safely', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: StartScreen(onLoginRequired: () {})),
    );
    await loadPoses(tester);
    expect(find.byKey(const ValueKey('idle')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 550));
    expect(find.byKey(const ValueKey('happy')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const ValueKey('happy')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 310));
    expect(find.byKey(const ValueKey('welcome')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 10));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion preserves transition', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StartScreen(onLoginRequired: () => calls++),
        ),
      ),
    );
    await loadPoses(tester);
    expect(find.byKey(const ValueKey('welcome')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 10));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
