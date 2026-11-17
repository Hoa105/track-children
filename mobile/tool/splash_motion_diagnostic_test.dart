import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/splash/splash_screen.dart';

class DeferredSplashBundle extends CachingAssetBundle {
  final ready = Completer<void>();
  @override
  Future<ByteData> load(String key) async {
    if (key.contains('/splash_')) await ready.future;
    return rootBundle.load(key);
  }
}

void main() {
  testWidgets('measure layout movement while splash image decodes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bundle = DeferredSplashBundle();
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: bundle,
          child: SplashScreen(onLoginRequired: () {}),
        ),
      ),
    );
    await tester.pump();
    final title = find.text('Cùng con lớn khôn mỗi ngày');
    final art = find.byType(FittedBox).first;
    final titleBefore = tester.getRect(title);
    final artBefore = tester.getRect(art);
    bundle.ready.complete();
    await tester.runAsync(
      () => precacheImage(
        AssetImage(
          'assets/images/scenery/backgrounds/splash_1.png',
          bundle: bundle,
        ),
        tester.element(find.byType(SplashScreen)),
      ),
    );
    await tester.pumpAndSettle();
    final titleAfter = tester.getRect(title);
    final artAfter = tester.getRect(art);
    expect(artBefore.height, greaterThan(0));
    expect(artAfter, artBefore);
    expect(titleAfter, titleBefore);
    debugPrint('[splash-motion] title before=$titleBefore after=$titleAfter');
    debugPrint('[splash-motion] artwork before=$artBefore after=$artAfter');
    debugPrint(
      '[splash-motion] title vertical shift=${titleAfter.top - titleBefore.top} dp',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
