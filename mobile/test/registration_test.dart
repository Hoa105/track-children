import 'dart:convert';

import 'registration_steps_test.dart' as steps;

import 'package:track_children/features/auth/social_profile_screen.dart';
import 'package:track_children/features/auth/social_provider_icon.dart';

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

  testWidgets('invalid phone never calls registration API', (tester) async {
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
    await steps.tapNext(tester);
    expect(calls, 0);
    await steps.enter(tester, 'registration-phone', 'bad-email');
    await steps.tapNext(tester);
    expect(calls, 0);
    expect(find.byKey(const ValueKey('registration-step-1')), findsOneWidget);
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
          if (request.url.path.endsWith('/social/start')) {
            expect(body['idToken'], 'provider-token');
            return json({
              'requiresProfile': true,
              'transactionId': 'id',
              'transactionToken': 'token',
              'documentsDigest': 'digest',
              'displayName': 'Provider Name',
            });
          }
          expect(request.url.path, endsWith('/social/complete'));
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

  for (final invalid in [false, true]) {
    testWidgets(
      'phone-first registration validates OTP before profile; invalid=$invalid',
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
        await steps.enter(
          tester,
          'registration-otp',
          invalid ? '999999' : '012345',
        );
        await steps.tapNext(tester);
        if (invalid) {
          expect(
            find.byKey(const ValueKey('registration-step-2')),
            findsOneWidget,
          );
          expect(opened, false);
          expect(gateway.completions, 0);
        } else {
          await steps.enter(tester, 'registration-password', 'Q7!m2#Zx');
          await steps.enter(tester, 'registration-confirm', 'Q7!m2#Zx');
          await steps.tapNext(tester);
          await steps.enter(tester, 'registration-name', 'Phụ huynh');
          final role = find.widgetWithText(ChoiceChip, 'Khác');
          await tester.ensureVisible(role);
          await tester.tap(role);
          await tester.pumpAndSettle();
          await steps.tapNext(tester);
          expect(gateway.completions, 0);
          expect(opened, false);
          final consent = find.byKey(const ValueKey('registration-consent'));
          await tester.ensureVisible(consent);
          await tester.tap(consent);
          await tester.pumpAndSettle();
          await steps.tapNext(tester);
          expect(opened, true);
          expect(gateway.completions, 1);
          expect(gateway.saved!['defaultRelationship'], 'other_guardian');
        }
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
      const MaterialApp(
        home: SocialProfileScreen(
          provider: SocialProvider.google,
          account: {'displayName': 'Parent'},
        ),
      ),
    );
    final consent = find.byKey(const ValueKey('registration-consent'));
    expect(tester.widget<CheckboxListTile>(consent).value, false);
    final read = find.text('Đọc điều khoản và chính sách');
    await tester.ensureVisible(read);
    await tester.tap(read);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chính sách dữ liệu'));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung data_policy'), findsOneWidget);
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(consent).value, false);
    await tester.ensureVisible(consent);
    await tester.tap(consent);
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(consent).value, true);
    await tester.pumpWidget(const SizedBox());
  });
}
