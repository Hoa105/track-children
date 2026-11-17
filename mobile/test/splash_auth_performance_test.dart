import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/auth/auth_layout.dart';
import 'package:track_children/features/auth/auth_screen.dart';
import 'package:track_children/features/splash/splash_screen.dart';

void main() {
  testWidgets('diagnose splash and auth first render costs', (tester) async {
    final assets = [
      'assets/images/scenery/backgrounds/splash_1.png',
      'assets/images/scenery/backgrounds/splash_2.png',
      for (final pose in AuthMascotPose.values) AuthMascot.asset(pose),
    ];

    for (final asset in assets) {
      final loadTimer = Stopwatch()..start();
      final bytes = await rootBundle.load(asset);
      loadTimer.stop();

      final decodeTimer = Stopwatch()..start();
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        codec.dispose();
      });
      decodeTimer.stop();

      debugPrint(
        '[ui-perf] $asset: ${(bytes.lengthInBytes / 1024).round()} KB, '
        'bundle ${loadTimer.elapsedMilliseconds} ms, '
        'decode ${decodeTimer.elapsedMilliseconds} ms',
      );
    }

    await tester.pumpWidget(
      MaterialApp(home: SplashScreen(onLoginRequired: () {})),
    );
    expect(find.byType(PageView), findsOneWidget);
    debugPrint('[ui-perf] Splash page is built on its first frame.');

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          onLoginSuccess: () {},
          onChildProfilePreview: () {},
          onBack: () {},
        ),
      ),
    );

    final cardOpacity = find
        .ancestor(
          of: find.byKey(const ValueKey('auth-form-surface')),
          matching: find.byType(Opacity),
        )
        .first;
    expect(tester.widget<Opacity>(cardOpacity).opacity, 0);
    expect(find.byType(AuthMascot), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(cardOpacity).opacity, 1);
    debugPrint('[ui-perf] Auth form entrance completes within 450 ms.');
  });
}
