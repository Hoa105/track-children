import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/auth/auth_layout.dart';

class DelayedMascotBundle extends CachingAssetBundle {
  final gate = Completer<void>();
  @override
  Future<ByteData> load(String key) async {
    if (key.endsWith('/error.png')) await gate.future;
    return rootBundle.load(key);
  }
}

Future<void> warmMascot(WidgetTester tester, {AssetBundle? bundle}) async {
  final context = tester.element(find.byType(AuthMascot));
  await tester.runAsync(() async {
    for (final pose in AuthMascotPose.values) {
      await precacheImage(
        AssetImage(AuthMascot.asset(pose), bundle: bundle),
        context,
      );
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'switching fields emits the final focus pose without an idle frame',
    (tester) async {
      final controller = AuthMascotController()..begin(reducedMotion: true);
      final text = controller.field();
      var hidden = true;
      final password = controller.field(obscured: () => hidden);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(focusNode: text),
                TextField(focusNode: password),
                SizedBox(
                  width: 160,
                  height: 150,
                  child: AuthMascot(controller: controller),
                ),
              ],
            ),
          ),
        ),
      );
      await warmMascot(tester);
      final poses = <AuthMascotPose>[];
      controller.addListener(() => poses.add(controller.pose));
      text.requestFocus();
      await tester.pumpAndSettle();
      expect(poses, [AuthMascotPose.typing]);
      poses.clear();
      password.requestFocus();
      await tester.pumpAndSettle();
      expect(poses, [AuthMascotPose.passwordHidden]);
      hidden = false;
      controller.visibilityChanged();
      controller.visibilityChanged();
      expect(poses, [
        AuthMascotPose.passwordHidden,
        AuthMascotPose.passwordVisible,
      ]);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rapid pose changes continue the current blend and settle on the latest pose',
    (tester) async {
      final controller = AuthMascotController()..begin(reducedMotion: true);
      final text = controller.field();
      final password = controller.field(obscured: () => true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(focusNode: text),
                TextField(focusNode: password),
                SizedBox(
                  width: 160,
                  height: 150,
                  child: AuthMascot(controller: controller),
                ),
              ],
            ),
          ),
        ),
      );
      await warmMascot(tester);
      Map<AuthMascotPose, double> weights() => {
        for (final opacity in tester.widgetList<Opacity>(
          find.descendant(
            of: find.byType(AuthMascot),
            matching: find.byType(Opacity),
          ),
        ))
          (opacity.key! as ValueKey<AuthMascotPose>).value: opacity.opacity,
      };
      text.requestFocus();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final before = weights();
      expect(before.length, 2);
      password.requestFocus();
      await tester.pump();
      await tester.pump();
      final after = weights();
      for (final entry in before.entries) {
        expect(after[entry.key], closeTo(entry.value, .00001));
      }
      for (var i = 0; i < 8; i++) {
        if (i.isEven) {
          text.requestFocus();
        } else {
          password.requestFocus();
        }
        await tester.pump(const Duration(milliseconds: 30));
        expect(weights().values.reduce((a, b) => a + b), closeTo(1, .00001));
      }
      await tester.pumpAndSettle();
      expect(weights(), {AuthMascotPose.passwordHidden: 1.0});
      expect(
        find.descendant(
          of: find.byType(AuthMascot),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a slow image keeps the old pose visible and cannot overwrite a newer result',
    (tester) async {
      final controller = AuthMascotController()..begin(reducedMotion: true);
      final bundle = DelayedMascotBundle();
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultAssetBundle(
            bundle: bundle,
            child: Center(
              child: SizedBox(
                width: 160,
                height: 150,
                child: AuthMascot(controller: controller),
              ),
            ),
          ),
        ),
      );
      final context = tester.element(find.byType(AuthMascot));
      await tester.runAsync(
        () => precacheImage(
          AssetImage(AuthMascot.asset(AuthMascotPose.idle), bundle: bundle),
          context,
        ),
      );
      await tester.pumpAndSettle();
      controller.showError();
      await tester.pumpAndSettle();
      String visibleAsset() =>
          (tester
                      .widget<Image>(
                        find.descendant(
                          of: find.byType(AuthMascot),
                          matching: find.byType(Image),
                        ),
                      )
                      .image
                  as AssetImage)
              .assetName;
      expect(visibleAsset(), AuthMascot.asset(AuthMascotPose.idle));
      controller.showSuccess();
      await tester.runAsync(
        () => precacheImage(
          AssetImage(AuthMascot.asset(AuthMascotPose.success), bundle: bundle),
          context,
        ),
      );
      await tester.pumpAndSettle();
      expect(visibleAsset(), AuthMascot.asset(AuthMascotPose.success));
      bundle.gate.complete();
      await warmMascot(tester, bundle: bundle);
      expect(visibleAsset(), AuthMascot.asset(AuthMascotPose.success));
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
