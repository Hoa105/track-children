import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/splash/start_screen.dart';
import 'package:track_children/features/splash/splash_screen.dart';

Future<void> loadPoses(WidgetTester tester) async {
  final context = tester.element(find.byType(StartScreen));
  await tester.runAsync(() async {
    for (final pose in ['idle', 'jump', 'welcome', 'happy']) {
      await precacheImage(
        AssetImage(
          'assets/images/scenery/backgrounds/start-assets/mascot/$pose.png',
        ),
        context,
      );
    }
  });
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

void main() {
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

  testWidgets('unmount during jump cancels timer and ticker', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: StartScreen(onLoginRequired: () {})),
    );
    await loadPoses(tester);
    await tester.pump(const Duration(milliseconds: 300));
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
      expect(find.byKey(const ValueKey('happy')), findsOneWidget);
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
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const ValueKey('jump')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const ValueKey('welcome')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('happy')), findsOneWidget);
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
    expect(find.byKey(const ValueKey('happy')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 10));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
