import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/auth/login_screen.dart';
import 'package:track_children/features/auth/sign_up_screen.dart';
import 'package:track_children/features/child/child_profile_selection_screen.dart';
import 'package:track_children/features/home/home_screen.dart';
import 'package:track_children/features/splash/start_screen.dart';
import 'package:track_children/main.dart';
import 'package:track_children/services/demo_store.dart';

import 'dart:convert';

import 'registration_steps_test.dart' as steps;

import 'package:track_children/features/auth/social_profile_screen.dart';
import 'package:track_children/features/auth/social_provider_icon.dart';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:track_children/services/auth_service.dart';

Future<void> openIntroduction(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const TrackChildrenApp());
  await tester.runAsync(
    () => precacheImage(
      const AssetImage(
        'assets/images/scenery/backgrounds/start-assets/mascot/idle.png',
      ),
      tester.element(find.byType(StartScreen)),
    ),
  );
  await tester.pump();
  // Let the native handoff and first image frame finish before advancing time.
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          startLaunchChannel,
          (_) async => {'supported': false},
        );
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
    FlutterSecureStorage.setMockInitialValues({});
    AuthService.instance = AuthService(
      client: MockClient((request) async {
        final body = request.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(request.body) as Map<String, dynamic>;
        Object result;
        if (request.url.path.endsWith('/legal-documents')) {
          result = {
            'documents': [
              {
                'id': 'legal-id',
                'docType': 'terms',
                'version': '1',
                'content': 'Test terms',
                'isRequired': true,
              },
            ],
          };
        } else if (request.url.path.endsWith('/children')) {
          result = {'children': []};
        } else if (request.url.path.endsWith('/register')) {
          expect(
            body.containsKey('email') != body.containsKey('phone'),
            isTrue,
          );
          expect(body.containsKey('username'), isFalse);
          expect(body['acceptedTerms'], isTrue);
          expect(body['defaultRelationship'], isNotNull);

          result = {
            'verificationId': 'otp-id',
            'registrationToken': 'test-secret',
            'targetMasked': '+84******003',
            'expiresAt': DateTime.now()
                .add(const Duration(minutes: 5))
                .toIso8601String(),
            'resendAvailableAt': DateTime.now()
                .add(const Duration(seconds: 60))
                .toIso8601String(),
            'deliveryStatus': 'sent',
          };
        } else {
          if (body['password'] == 'wrong') {
            return http.Response(
              jsonEncode({
                'error': {'code': 'INVALID_CREDENTIALS'},
              }),
              401,
            );
          }
          if (request.url.path.endsWith('/verify') &&
              body['code'] != '734821') {
            return http.Response(
              jsonEncode({
                'error': {'code': 'OTP_INVALID'},
              }),
              400,
            );
          }
          result = {
            'accessToken': 'test-access',
            'refreshToken': 'test-refresh',
            'user': {
              'id': 'server-user',
              'email': request.url.path.endsWith('/verify')
                  ? 'new.parent@example.test'
                  : body['email'],
            },
          };
        }
        return http.Response(jsonEncode(result), 200);
      }),
    );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(startLaunchChannel, null);
  });
  testWidgets('first startup introduction completes into signup', (
    tester,
  ) async {
    await openIntroduction(tester);
    expect(find.text('Cùng con lớn khôn mỗi ngày'), findsOneWidget);
    await tester.ensureVisible(find.text('Tiếp tục'));
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text('Lưu giữ hành trình, cùng nhau chăm bé'), findsOneWidget);
    await tester.ensureVisible(find.text('Bắt đầu'));
    await tester.tap(find.text('Bắt đầu'));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);
  });
  testWidgets(
    'completion persists while introduction remains visible on restart',
    (tester) async {
      await openIntroduction(tester);
      await tester.ensureVisible(find.text('Tiếp tục'));
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bắt đầu'));
      await tester.tap(find.text('Bắt đầu'));
      await tester.pumpAndSettle();
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'track_children_onboarding_completed',
        ),
        true,
      );
      await tester.pumpWidget(const SizedBox());
      await openIntroduction(tester);
      expect(find.text('Cùng con lớn khôn mỗi ngày'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final systemBack in [false, true]) {
    testWidgets('profile picker back preserves session (system: $systemBack)', (
      tester,
    ) async {
      await openIntroduction(tester);
      await tester.tap(find.text('Bỏ qua'));
      await tester.pumpAndSettle();

      if (find.byType(SignUpScreen).evaluate().isNotEmpty) {
        final link = find.widgetWithText(TextButton, 'Đăng nhập');
        await tester.ensureVisible(link);
        await tester.tap(link);
        await tester.pumpAndSettle();
      }
      Future<void> login(String email) async {
        await tester.enterText(find.byType(TextFormField).first, email);
        await tester.enterText(
          find.byType(TextFormField).at(1),
          DemoStore.password,
        );
        final button = find.widgetWithText(FilledButton, 'Đăng nhập');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      await login('first@example.test');
      expect(find.byType(ChildProfileSelectionScreen), findsOneWidget);
      final user = Map<String, dynamic>.from(AuthService.instance.user!);
      if (systemBack) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.byTooltip('Quay lại'));
      }
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ChildProfileSelectionScreen), findsNothing);
      expect(AuthService.instance.signedIn, isTrue);
      expect(AuthService.instance.user, user);

      await login('second@example.test');
      expect(find.byType(ChildProfileSelectionScreen), findsOneWidget);
      expect(AuthService.instance.user!['email'], 'second@example.test');
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('login validates and authenticates shared parent fixture', (
    tester,
  ) async {
    var loggedIn = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          onSignUp: () {},
          onBack: () {},
          onLoginSuccess: () => loggedIn = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'Đăng nhập');
    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Vui lòng nh\u1eadp email ho\u1eb7c s\u1ed1 \u0111i\u1ec7n tho\u1ea1i.',
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'demo@trackchildren.vn',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(loggedIn, false);
    await tester.enterText(
      find.byType(TextFormField).at(1),
      DemoStore.password,
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(loggedIn, true);
    expect(AuthService.instance.user!['email'], 'demo@trackchildren.vn');
  });
  testWidgets('profile role selection has no implicit choice', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SocialProfileScreen(
          provider: SocialProvider.google,
          account: {'displayName': 'Parent'},
        ),
      ),
    );
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Mẹ')).selected,
      false,
    );
    final other = find.widgetWithText(ChoiceChip, 'Khác');
    await tester.ensureVisible(other);
    await tester.tap(other);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(other).selected, true);
  });

  testWidgets(
    'signup verifies OTP and explicitly accepts policies before completion',
    (tester) async {
      var opened = false;
      final gateway = steps.FakeRegistrationGateway();
      await tester.pumpWidget(
        MaterialApp(
          home: SignUpScreen(
            registrationGateway: gateway,
            onLogin: () {},
            onChildProfilePreview: () => opened = true,
          ),
        ),
      );
      await steps.enter(tester, 'registration-phone', '0912345678');
      await steps.tapNext(tester);
      expect(gateway.completions, 0);
      await steps.enter(tester, 'registration-otp', '012345');
      await steps.tapNext(tester);
      await steps.enter(tester, 'registration-password', 'Q7!m2#Zx');
      await steps.enter(tester, 'registration-confirm', 'Q7!m2#Zx');
      await steps.tapNext(tester);
      await steps.enter(tester, 'registration-name', 'Phụ huynh thử');
      final role = find.widgetWithText(ChoiceChip, 'Mẹ');
      await tester.ensureVisible(role);
      await tester.tap(role);
      await tester.pumpAndSettle();
      final read = find.text('Đọc điều khoản và chính sách');
      await tester.ensureVisible(read);
      await tester.tap(read);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Điều khoản sử dụng'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Test terms'), findsOneWidget);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      await steps.tapNext(tester);
      expect(opened, false);
      expect(gateway.completions, 0);
      final consent = find.byKey(const ValueKey('registration-consent'));
      await tester.ensureVisible(consent);
      await tester.tap(consent);
      await tester.pumpAndSettle();
      await steps.tapNext(tester);
      expect(opened, true);
      expect(gateway.completions, 1);
      expect(gateway.saved!['acceptedTerms'], true);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'signup starts with phone only and rejects an email in that field',
    (tester) async {
      final gateway = steps.FakeRegistrationGateway();
      await tester.pumpWidget(
        MaterialApp(
          home: SignUpScreen(
            registrationGateway: gateway,
            onLogin: () {},
            onChildProfilePreview: () {},
          ),
        ),
      );
      expect(find.byType(TextFormField), findsOneWidget);
      await steps.enter(tester, 'registration-phone', 'parent@example.com');
      await steps.tapNext(tester);
      expect(gateway.starts, 0);
      await steps.enter(tester, 'registration-phone', '0912345678');
      await steps.tapNext(tester);
      expect(gateway.starts, 1);
      expect(find.byKey(const ValueKey('registration-otp')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('standalone Home has shortcuts but no private measurements', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(childName: 'An')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bé An'), findsOneWidget);
    for (final label in [
      'Lượng sữa',
      'Tiêm chủng',
      'Mọc răng',
      'Hoạt động',
      'Nhật ký',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('Cân nặng'), findsNothing);
    expect(find.text('Chiều cao'), findsNothing);
    expect(find.text('12,5 kg'), findsNothing);
    expect(find.text('Bé ăn ngon hơn'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
