import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:track_children/features/auth/auth_layout.dart';
import 'package:track_children/features/auth/login_screen.dart';
import 'package:track_children/features/auth/sign_up_screen.dart';
import 'package:track_children/services/auth_service.dart';

import 'registration_steps_test.dart'
    show FakeRegistrationGateway, enter, tapNext;

void main() {
  setUpAll(() async {
    await (FontLoader('Nunito')..addFont(
          Future.value(
            ByteData.sublistView(
              await File('assets/fonts/nunito/Nunito-Variable.ttf')
                  .readAsBytes(),
            ),
          ),
        ))
        .load();
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config = jsonDecode(await configFile.readAsString()) as Map;
    final flutterPackage = (config['packages'] as List).cast<Map>().singleWhere(
      (p) => p['name'] == 'flutter',
    );
    final flutterUri = configFile.uri.resolve("${flutterPackage['rootUri']}/");
    final font = File.fromUri(
      flutterUri.resolve(
        '../../bin/cache/artifacts/material_fonts/materialicons-regular.otf',
      ),
    );
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(ByteData.sublistView(await font.readAsBytes())),
        ))
        .load();
  });
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.instance = AuthService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'accessToken': 'test-access',
            'refreshToken': 'test-refresh',
            'user': {'id': 'parent'},
          }),
          200,
        ),
      ),
    );
  });

  for (final signup in [false, true]) {
    testWidgets(
      '${signup ? 'signup' : 'login'} keeps mascot attached while height changes',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 800);
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            home: signup
                ? SignUpScreen(onLogin: () {}, onChildProfilePreview: () {})
                : LoginScreen(onSignUp: () {}, onBack: () {}),
          ),
        );
        await tester.pumpAndSettle();
        final mascot = find.byType(AuthMascot);
        final form = find.byKey(const ValueKey('auth-form-surface'));
        final originalTop = tester.getRect(mascot).top;

        void checkAttachment() {
          final mascotRect = tester.getRect(mascot);
          final formRect = tester.getRect(form);
          expect(
            formRect.top - mascotRect.top,
            closeTo(mascotRect.height * .9, .1),
          );
          expect(mascotRect.center.dx, closeTo(formRect.center.dx, .1));
          expect(tester.takeException(), isNull);
        }

        for (final height in [568.0, 640.0, 932.0, 1200.0, 800.0]) {
          tester.view.physicalSize = Size(360, height);
          await tester.pumpAndSettle();
          checkAttachment();
          expect(tester.getRect(mascot).top, closeTo(originalTop, .1));
        }
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -120),
        );
        await tester.pumpAndSettle();
        checkAttachment();
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        checkAttachment();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    for (final size in [const Size(320, 568), const Size(360, 800)]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '${signup ? 'signup' : 'login'} ${size.width} text $scale keyboard and scrolling',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
            tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.reset);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final key = GlobalKey();
            await tester.pumpWidget(
              RepaintBoundary(
                key: key,
                child: MaterialApp(
                  home: signup
                      ? SignUpScreen(
                          onLogin: () {},
                          onChildProfilePreview: () {},
                        )
                      : LoginScreen(onSignUp: () {}, onBack: () {}),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.byType(AuthMascot), findsOneWidget);
            final surface = find.byKey(const ValueKey('auth-form-surface'));
            final before = tester.getRect(surface);
            // Switching expressions must not move the form surface.
            tester
                .widget<AuthMascot>(find.byType(AuthMascot))
                .controller
                .showError();
            await tester.pumpAndSettle();
            expect(tester.getRect(surface), before);
            tester
                .widget<AuthMascot>(find.byType(AuthMascot))
                .controller
                .edited();
            await tester.pumpAndSettle();
            if (size.width == 360 && scale == 1) {
              await capture(tester, key, signup ? 'signup_top' : 'login');
            }
            final password = find.byType(TextFormField).at(signup ? 0 : 1);
            await tester.ensureVisible(password);
            await tester.tap(password);
            tester.view.viewInsets = const FakeViewPadding(bottom: 280);
            await tester.pumpAndSettle();
            await tester.ensureVisible(password);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              tester.getRect(password).bottom,
              lessThanOrEqualTo(size.height - 280),
            );
            tester.view.viewInsets = const FakeViewPadding();
            FocusManager.instance.primaryFocus?.unfocus();
            await tester.pumpAndSettle();
            final submit = find.widgetWithText(
              FilledButton,
              signup ? 'Tiếp tục' : 'Đăng nhập',
            );
            await tester.ensureVisible(submit);
            await tester.pumpAndSettle();
            expect(tester.getSize(submit).height, greaterThanOrEqualTo(48));
            expect(tester.takeException(), isNull);
            if (signup && size.width == 360 && scale == 1) {
              await capture(tester, key, 'signup_form');
            }
          },
        );
      }
    }
  }

  testWidgets(
    'login mascot follows focus, visibility, error recovery and success without delaying callback',
    (tester) async {
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            onSignUp: () {},
            onBack: () {},
            onLoginSuccess: () => completed = true,
          ),
        ),
      );
      final mascot = tester
          .widget<AuthMascot>(find.byType(AuthMascot))
          .controller;
      expect(mascot.pose, AuthMascotPose.welcome);
      await tester.pumpAndSettle();
      expect(mascot.pose, AuthMascotPose.idle);
      await tester.enterText(
        find.byType(TextFormField).first,
        'parent@example.com',
      );
      await tester.pumpAndSettle();
      expect(mascot.pose, AuthMascotPose.typing);
      final password = find.byType(TextFormField).at(1);
      await tester.ensureVisible(password);
      await tester.enterText(password, 'password123');
      await tester.pumpAndSettle();
      expect(mascot.pose, AuthMascotPose.passwordHidden);
      await tester.tap(find.byTooltip('Hiện mật khẩu'));
      await tester.pumpAndSettle();
      expect(mascot.pose, AuthMascotPose.passwordVisible);
      mascot.showError();
      await tester.pumpAndSettle();
      expect(mascot.pose, AuthMascotPose.error);
      await tester.enterText(password, 'password1234');
      await tester.pumpAndSettle();
      expect(mascot.pose, AuthMascotPose.passwordVisible);
      final submit = find.widgetWithText(FilledButton, 'Đăng nhập');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(mascot.pose, AuthMascotPose.success);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'signup mascot follows the focused password field and reduced motion skips entrance',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: SignUpScreen(
              registrationGateway: FakeRegistrationGateway(),
              onLogin: () {},
              onChildProfilePreview: () {},
            ),
          ),
        ),
      );
      final mascot = tester
          .widget<AuthMascot>(find.byType(AuthMascot))
          .controller;
      expect(mascot.pose, AuthMascotPose.idle);
      await enter(tester, 'registration-phone', '0912345678');
      await tapNext(tester);
      await enter(tester, 'registration-otp', '012345');
      await tapNext(tester);
      final first = find.byKey(const ValueKey('registration-password'));
      final confirm = find.byKey(const ValueKey('registration-confirm'));
      await tester.ensureVisible(first);
      await tester.enterText(first, 'password123');
      await tester.tap(find.byTooltip('Hiện mật khẩu'));
      await tester.pumpAndSettle();
      expect(mascot.pose, AuthMascotPose.passwordVisible);
      await tester.ensureVisible(confirm);
      await tester.enterText(confirm, 'password123');
      await tester.pumpAndSettle();
      expect(mascot.pose, AuthMascotPose.passwordHidden);
      await tester.tap(find.byTooltip('Hiện xác nhận mật khẩu'));
      await tester.pumpAndSettle();
      expect(mascot.pose, AuthMascotPose.passwordVisible);
      await tester.enterText(confirm, 'different123');
      final button = find.widgetWithText(FilledButton, 'Tiếp tục');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(mascot.pose, AuthMascotPose.error);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final context = tester.element(find.byType(AuthLayout));
    for (final pose in AuthMascotPose.values) {
      await precacheImage(AssetImage(AuthMascot.asset(pose)), context);
    }
  });
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final snapshot = await boundary.toImage();
    final bytes = await snapshot.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/auth_review');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    snapshot.dispose();
  });
}
