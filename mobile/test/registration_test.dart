import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:track_children/features/auth/otp_dialog.dart';
import 'package:track_children/features/auth/sign_up_screen.dart';
import 'package:track_children/services/auth_service.dart';

Map<String, dynamic> challenge(String id) => {
  'verificationId': id,
  'registrationToken': 'signed-$id',
  'targetMasked': 'p***@example.com',
  'expiresAt': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
  'resendAvailableAt': DateTime.now()
      .subtract(const Duration(seconds: 1))
      .toIso8601String(),
};
http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('invalid form and missing consent never call registration API', (
    tester,
  ) async {
    var calls = 0;
    AuthService.instance = AuthService(
      client: MockClient((_) async {
        calls++;
        return json({});
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SignUpScreen(onLogin: () {}, onChildProfilePreview: () {}),
      ),
    );
    final submit = find.widgetWithText(FilledButton, 'Đăng ký');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Vui lòng đồng ý với các điều khoản.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(1), 'bad-email');
    await tester.enterText(find.byType(TextFormField).at(2), 'short');
    await tester.enterText(find.byType(TextFormField).at(3), 'different');
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Email chưa đúng định dạng.'), findsOneWidget);
    expect(find.text('Mật khẩu cần có 8–64 ký tự.'), findsOneWidget);
    expect(find.text('Mật khẩu chưa trùng khớp.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'social registration sends the entered name and selected relationship',
    () async {
      final auth = AuthService(
        socialIdentityProvider: (_, _) async => {
          'idToken': 'provider-token',
          'displayName': 'Provider Name',
        },
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          expect(body['displayName'], 'Tên đã nhập');
          expect(body['defaultRelationship'], 'grandmother');
          expect(body.containsKey('password'), false);
          return json({
            'accessToken': 'access',
            'refreshToken': 'refresh',
            'user': {'id': 'parent'},
            'isNewUser': true,
          });
        }),
      );
      expect(
        await auth.socialRegister(
          'google',
          acceptedTerms: true,
          displayName: ' Tên đã nhập ',
          relationship: 'grandmother',
        ),
        true,
      );
    },
  );

  for (final phone in [false, true]) {
    testWidgets(
      'registration ${phone ? 'phone' : 'email'} resumes replacement OTP and creates session',
      (tester) async {
        var registrations = 0;
        var navigated = false;
        AuthService.instance = AuthService(
          client: MockClient((request) async {
            final body = jsonDecode(request.body) as Map;
            if (request.url.path.endsWith('/register')) {
              registrations++;
              expect(
                body.keys,
                unorderedEquals([
                  'displayName',
                  phone ? 'phone' : 'email',
                  'password',
                  'defaultRelationship',
                  'acceptedTerms',
                ]),
              );
              expect(body['displayName'], 'Phụ huynh');
              expect(body['defaultRelationship'], 'other_guardian');
              expect(
                body[phone ? 'phone' : 'email'],
                phone ? '0912345678' : 'parent@example.com',
              );
              return json(challenge('original'), 201);
            }
            if (request.url.path.endsWith('/resend'))
              return json(challenge('replacement'));
            expect(request.url.path, '/api/v1/auth/register/verify');
            expect(body['verificationId'], 'replacement');
            expect(body['registrationToken'], 'signed-replacement');
            expect(body['code'], '123456');
            return json({
              'accessToken': 'access',
              'refreshToken': 'refresh',
              'user': {
                'id': 'parent',
                'displayName': 'Phụ huynh',
                'defaultRelationship': 'other_guardian',
              },
            });
          }),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: SignUpScreen(
              onLogin: () {},
              onChildProfilePreview: () => navigated = true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (phone) {
          final selector = find.byKey(
            const ValueKey('registration-method-selector'),
          );
          await tester.ensureVisible(selector);
          await tester.tap(selector);
          await tester.pumpAndSettle();
        }
        await tester.enterText(
          find.byType(TextFormField).at(1),
          phone ? '0912345678' : 'parent@example.com',
        );
        await tester.enterText(find.byType(TextFormField).at(2), 'password123');
        await tester.enterText(find.byType(TextFormField).at(3), 'password123');
        final guardian = find.widgetWithText(ChoiceChip, 'Người giám hộ khác');
        await tester.ensureVisible(guardian);
        await tester.tap(guardian);
        await tester.ensureVisible(find.byType(Checkbox));
        await tester.tap(find.byType(Checkbox));
        final submit = find.widgetWithText(FilledButton, 'Đăng ký');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(find.byType(OtpDialog), findsOneWidget);
        expect(navigated, false);
        expect(AuthService.instance.signedIn, false);
        await tester.tap(find.text('Gửi lại OTP'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hủy'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(registrations, 1);
        await tester.enterText(
          find.descendant(
            of: find.byType(OtpDialog),
            matching: find.byType(TextField),
          ),
          '123456',
        );
        await tester.tap(find.text('Xác nhận'));
        await tester.pumpAndSettle();
        expect(navigated, true);
        expect(
          AuthService.instance.user!['defaultRelationship'],
          'other_guardian',
        );
        expect(
          await const FlutterSecureStorage().read(key: 'auth.refresh'),
          'refresh',
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('OTP resend respects server Retry-After', (tester) async {
    var calls = 0;
    AuthService.instance = AuthService(
      client: MockClient((_) async {
        calls++;
        return http.Response(
          jsonEncode({
            'error': {'code': 'RATE_LIMITED'},
          }),
          429,
          headers: {'retry-after': '3600'},
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(home: OtpDialog(challenge: challenge('limited'))),
    );
    await tester.tap(find.text('Gửi lại OTP'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    final resend = find.widgetWithText(TextButton, 'Gửi lại sau 3600 giây');
    expect(resend, findsOneWidget);
    expect(tester.widget<TextButton>(resend).onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('deployed legal documents can be read and accepted', (
    tester,
  ) async {
    AuthService.instance = AuthService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/legal-documents');
        return json({
          'documents': [
            for (final type in ['terms', 'privacy', 'data_policy'])
              {'docType': type, 'version': 'v1', 'content': 'Nội dung $type'},
          ],
        });
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SignUpScreen(onLogin: () {}, onChildProfilePreview: () {}),
      ),
    );
    final terms = find.text(
      'Tôi đồng ý với Điều khoản sử dụng & Chính sách quyền riêng tư',
    );
    await tester.ensureVisible(terms);
    await tester.tap(terms);
    await tester.pumpAndSettle();
    expect(find.textContaining('Chính sách dữ liệu — v1'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Đồng ý'));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, true);
  });
}
