import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/splash/native_startup_screen.dart';
import 'package:track_children/features/splash/splash_screen.dart';
import 'package:track_children/features/splash/start_screen.dart';

Future<void> loadIntroduction(WidgetTester tester) async {
  final context = tester.element(find.byType(NativeStartupScreen));
  await tester.runAsync(() async {
    await precacheImage(
      const AssetImage('assets/images/scenery/backgrounds/splash_1.png'),
      context,
    );
  });
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
    'native cover waits for initialization and the destination frame',
    (tester) async {
      final initialization = Completer<void>();
      var readySignals = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        startLaunchChannel,
        (call) async {
          expect(call.method, 'contentReady');
          expect(find.byType(SplashScreen), findsOneWidget);
          expect(find.byType(StartScreen), findsNothing);
          readySignals++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          startLaunchChannel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: NativeStartupScreen(
            onLoginRequired: () {},
            initialize: () => initialization.future,
          ),
        ),
      );
      await loadIntroduction(tester);
      await tester.pump(const Duration(seconds: 5));
      expect(readySignals, 0);
      expect(find.byType(SplashScreen), findsNothing);
      initialization.complete();
      await tester.pumpAndSettle();
      expect(readySignals, 1);
      expect(find.text('Bỏ qua'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('initialization error reveals a usable retry page', (
    tester,
  ) async {
    var calls = 0;
    var readySignals = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      startLaunchChannel,
      (call) async {
        readySignals++;
        expect(find.text('Thử lại'), findsOneWidget);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        startLaunchChannel,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NativeStartupScreen(
          onLoginRequired: () {},
          initialize: () async {
            if (++calls == 1) throw StateError('startup failed');
          },
        ),
      ),
    );
    await loadIntroduction(tester);
    await tester.pumpAndSettle();
    expect(readySignals, 1);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(readySignals, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('disposing while initializing never releases another screen', (
    tester,
  ) async {
    final initialization = Completer<void>();
    var readySignals = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      startLaunchChannel,
      (_) async {
        readySignals++;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        startLaunchChannel,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NativeStartupScreen(
          onLoginRequired: () {},
          initialize: () => initialization.future,
        ),
      ),
    );
    await loadIntroduction(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    initialization.complete();
    await tester.pump();
    expect(readySignals, 0);
    expect(tester.takeException(), isNull);
  });
}
