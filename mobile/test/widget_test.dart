import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/auth/login_screen.dart';
import 'package:track_children/features/auth/sign_up_screen.dart';
import 'package:track_children/features/home/home_screen.dart';
import 'package:track_children/features/splash/start_screen.dart';
import 'package:track_children/main.dart';
import 'package:track_children/services/demo_store.dart';

import 'dart:convert';

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
      const AssetImage('assets/images/scenery/backgrounds/start_screen.png'),
      tester.element(find.byType(StartScreen)),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
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
  testWidgets('startup introduction completes into login', (tester) async {
    await openIntroduction(tester);
    expect(find.text('Chăm sóc bé dễ dàng hơn'), findsOneWidget);
    await tester.ensureVisible(find.text('Tiếp tục'));
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text('Đồng hành cùng bé mỗi ngày'), findsOneWidget);
    await tester.ensureVisible(find.text('Bắt đầu'));
    await tester.tap(find.text('Bắt đầu'));
    await tester.pumpAndSettle();
    expect(find.text('Chào mừng bạn trở lại'), findsOneWidget);
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
      expect(find.text('Chăm sóc bé dễ dàng hơn'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
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
  testWidgets('signup role selection uses current parent roles', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SignUpScreen(onLogin: () {}, onChildProfilePreview: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Người giám hộ khác'));
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Mẹ')).selected,
      true,
    );
    await tester.tap(find.text('Người giám hộ khác'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(
            find.widgetWithText(ChoiceChip, 'Người giám hộ khác'),
          )
          .selected,
      true,
    );
    expect(find.text('Đây có phải lần đầu bạn có con?'), findsNothing);
  });
  testWidgets(
    'signup accepts server terms and verifies OTP before child form',
    (tester) async {
      var openChild = false;
      await tester.pumpWidget(
        MaterialApp(
          home: SignUpScreen(
            onLogin: () {},
            onChildProfilePreview: () => openChild = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final values = [
        'Phụ huynh thử',
        'new.parent@example.test',
        'abcdefgh',
        'abcdefgh',
      ];
      for (var i = 0; i < values.length; i++) {
        await tester.enterText(find.byType(TextFormField).at(i), values[i]);
      }
      await tester.ensureVisible(find.byType(Checkbox));
      final termsLink = find.text('Tôi đồng ý với Điều khoản sử dụng & Chính sách quyền riêng tư');
      await tester.ensureVisible(termsLink);
      await tester.tap(termsLink);
      await tester.pumpAndSettle();
      expect(find.textContaining('Test terms'), findsOneWidget);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Xác thực OTP'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '734821',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận'));
      await tester.pumpAndSettle();
      expect(openChild, true);
      expect(AuthService.instance.user!['email'], 'new.parent@example.test');
      expect(DemoStore.instance.children, isEmpty);
    },
  );
  testWidgets(
    'signup switches to phone without requiring email or display name',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SignUpScreen(onLogin: () {}, onChildProfilePreview: () {}),
        ),
      );
      await tester.pumpAndSettle();
      final phoneOption = find.byKey(
        const ValueKey('registration-method-selector'),
      );
      await tester.ensureVisible(phoneOption);
      await tester.tap(phoneOption);
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(4));
      await tester.enterText(find.byType(TextFormField).at(1), '0912345678');
      await tester.enterText(find.byType(TextFormField).at(2), 'abcdefgh');
      await tester.enterText(find.byType(TextFormField).at(3), 'abcdefgh');
      final form = tester.widget<Form>(find.byType(Form));
      expect(
        (form.key as GlobalKey<FormState>).currentState!.validate(),
        isTrue,
      );
      await tester.pumpAndSettle();
    },
  );
  testWidgets('standalone Home has shortcuts but no private measurements', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(childName: 'An')),
    );
    await tester.pumpAndSettle();
    expect(find.text('An'), findsOneWidget);
    for (final label in [
      'Lượng sữa',
      'Tiêm chủng',
      'Mọc răng',
      'Hoạt động',
      'Nhật ký',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    await tester.scrollUntilVisible(
      find.text('Cân nặng'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Chưa có số đo'), findsWidgets);
    expect(find.text('12,5 kg'), findsNothing);
    expect(find.text('Bé ăn ngon hơn'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
