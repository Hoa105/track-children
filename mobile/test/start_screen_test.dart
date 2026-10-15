import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/splash/start_screen.dart';
import 'package:track_children/features/splash/splash_screen.dart';

void main() {
  for (final width in [320.0, 430.0]) {
    testWidgets('startup artwork and transition at width $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(home: StartScreen(onLoginRequired: () {})),
      );
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage(
            'assets/images/scenery/backgrounds/start_screen.png',
          ),
          tester.element(find.byType(StartScreen)),
        );
      });
      await tester.pump();
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.cover);
      final rect = tester.getRect(find.byType(Image));
      expect(rect, Rect.fromLTWH(0, 0, width, 800));
      expect(find.byType(SplashScreen), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
