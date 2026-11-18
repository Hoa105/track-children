import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:track_children/features/auth/auth_layout.dart';
import 'package:track_children/features/auth/login_screen.dart';
import 'package:track_children/features/auth/registration_gateway.dart';
import 'package:track_children/features/auth/sign_up_screen.dart';
import 'package:track_children/features/auth/social_profile_screen.dart';
import 'package:track_children/features/auth/social_provider_icon.dart';
import 'package:track_children/services/auth_service.dart';

class FakeRegistrationGateway implements RegistrationGateway {
  int starts = 0, completions = 0;
  Map<String, dynamic>? saved;
  Map<String, dynamic> challenge() => {
    'targetMasked': '+84******123',
    'expiresAt': DateTime.now()
        .add(const Duration(minutes: 5))
        .toIso8601String(),
    'resendAvailableAt': DateTime.now().toIso8601String(),
  };
  @override
  Future<Map<String, dynamic>> start(String phone) async {
    starts++;
    return challenge();
  }

  @override
  Future<Map<String, dynamic>> resend(Map<String, dynamic> value) async =>
      challenge();
  @override
  Future<Map<String, dynamic>> verify(
    Map<String, dynamic> value,
    String code,
  ) async {
    if (code != '012345') throw AuthException('OTP_INVALID', {});
    return {
      'grant': 'test-only',
      'expiresAt': DateTime.now()
          .add(const Duration(minutes: 10))
          .toIso8601String(),
    };
  }

  @override
  Future<void> complete(
    Map<String, dynamic> grant,
    Map<String, dynamic> profile,
  ) async {
    completions++;
    saved = profile;
  }
}

Future<void> tapNext(WidgetTester tester) async {
  final next = find.byKey(const ValueKey('registration-next'));
  await tester.ensureVisible(next);
  await tester.tap(next);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String value) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
}

void main() {
  setUpAll(() async {
    await (FontLoader('Nunito')
          ..addFont(rootBundle.load('assets/fonts/nunito/Nunito-Variable.ttf')))
        .load();
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config = jsonDecode(await configFile.readAsString()) as Map;
    final package = (config['packages'] as List).cast<Map>().singleWhere(
      (p) => p['name'] == 'flutter',
    );
    final flutterUri = configFile.uri.resolve("${package['rootUri']}/");
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
  });

  testWidgets('four steps require OTP and explicit profile consent', (
    tester,
  ) async {
    final gateway = FakeRegistrationGateway();
    bool completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SignUpScreen(
          registrationGateway: gateway,
          onLogin: () {},
          onChildProfilePreview: () => completed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Email'), findsNothing);
    expect(tester.getSize(find.byType(AuthMascot)).height, 180);
    await enter(tester, 'registration-phone', '0912345678');
    await tapNext(tester);
    expect(find.byKey(const ValueKey('registration-step-2')), findsOneWidget);
    await enter(tester, 'registration-otp', '999999');
    await tapNext(tester);
    expect(find.text('Mã OTP chưa đúng.'), findsOneWidget);
    expect(find.byKey(const ValueKey('registration-password')), findsNothing);
    await enter(tester, 'registration-otp', '012345');
    await tapNext(tester);
    expect(find.byKey(const ValueKey('registration-step-3')), findsOneWidget);
    await enter(tester, 'registration-password', 'Mậtkhẩu8!');
    await enter(tester, 'registration-confirm', 'Mậtkhẩu8!');
    await tapNext(tester);
    expect(
      find.text('Mật khẩu không được chứa dấu, khoảng trắng hoặc emoji.'),
      findsOneWidget,
    );
    await enter(tester, 'registration-password', 'Q7!m2#Zx');
    await enter(tester, 'registration-confirm', 'Q7!m2#Zx');
    await tapNext(tester);
    expect(find.byKey(const ValueKey('registration-step-4')), findsOneWidget);
    expect(tester.getSize(find.byType(AuthMascot)).height, 180);
    await tapNext(tester);
    expect(gateway.completions, 0);
    await enter(tester, 'registration-name', 'Nguyễn Thị Ánh');
    final role = find.widgetWithText(ChoiceChip, 'Mẹ');
    await tester.ensureVisible(role);
    await tester.tap(role);
    await tester.pumpAndSettle();
    await tapNext(tester);
    expect(completed, false);
    final consent = find.byKey(const ValueKey('registration-consent'));
    await tester.ensureVisible(consent);
    await tester.tap(consent);
    await tester.pumpAndSettle();
    await tapNext(tester);
    expect(completed, true);
    expect(gateway.completions, 1);
    expect(gateway.saved?['displayName'], 'Nguyễn Thị Ánh');
    expect(gateway.saved?['acceptedTerms'], true);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('edit phone returns to step one without verification', (
    tester,
  ) async {
    final gateway = FakeRegistrationGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: SignUpScreen(
          registrationGateway: gateway,
          onLogin: () {},
          onChildProfilePreview: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await enter(tester, 'registration-phone', '0912345678');
    await tapNext(tester);
    final edit = find.text('Sửa số điện thoại');
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('registration-step-1')), findsOneWidget);
    expect(gateway.completions, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('production adapter fails safely without legacy register call', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SignUpScreen(onLogin: () {}, onChildProfilePreview: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await enter(tester, 'registration-phone', '0912345678');
    await tapNext(tester);
    expect(find.byKey(const ValueKey('registration-step-1')), findsOneWidget);
    expect(
      find.textContaining('Đăng ký bằng số điện thoại đang được cập nhật.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'social profile requires name role and consent; reading is not consent',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SocialProfileScreen(
            provider: SocialProvider.apple,
            account: {'displayName': 'Đỗ Đức'},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('registration-step-4')), findsNothing);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('registration-consent')),
            )
            .value,
        false,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Mẹ'))
            .selected,
        false,
      );
      final submit = find.widgetWithText(FilledButton, 'Hoàn tất đăng ký');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng chọn vai trò với bé.'), findsOneWidget);
      expect(
        find.text('Vui lòng đồng ý với điều khoản và chính sách.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final screen in ['login', 'signup', 'social']) {
    testWidgets('$screen small screen large text, shared mascot size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          home: switch (screen) {
            'login' => LoginScreen(onSignUp: () {}, onBack: () {}),
            'social' => const SocialProfileScreen(
              provider: SocialProvider.apple,
              account: {'displayName': 'Đỗ Đức'},
            ),
            _ => SignUpScreen(onLogin: () {}, onChildProfilePreview: () {}),
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(AuthMascot)).height, 180);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('capture signup steps for visual review', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1000);
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          home: SignUpScreen(
            registrationGateway: FakeRegistrationGateway(),
            onLogin: () {},
            onChildProfilePreview: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(int step) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/auth_review').create(recursive: true);
        await File('build/auth_review/step_$step.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture(1);
    await enter(tester, 'registration-phone', '0912345678');
    await tapNext(tester);
    await capture(2);
    await enter(tester, 'registration-otp', '012345');
    await tapNext(tester);
    await capture(3);
    await enter(tester, 'registration-password', 'Q7!m2#Zx');
    await enter(tester, 'registration-confirm', 'Q7!m2#Zx');
    await tapNext(tester);
    await capture(4);
    await tester.pumpWidget(const SizedBox());
  });
}
