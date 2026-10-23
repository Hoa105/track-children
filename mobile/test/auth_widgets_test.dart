import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:track_children/features/auth/login_screen.dart';
import 'package:track_children/features/auth/sign_up_screen.dart';
import 'package:track_children/features/auth/otp_dialog.dart';
import 'package:track_children/services/auth_service.dart';
import 'package:track_children/services/social_identity.dart';

Map<String, dynamic> challenge(String id) => {
  'verificationId': id,
  'registrationToken': 'registration-secret',
  'targetMasked': '+84******678',
  'deliveryStatus': 'sent',
  'expiresAt': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
  'resendAvailableAt': DateTime.now()
      .subtract(const Duration(seconds: 1))
      .toIso8601String(),
};
http.Response response(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status);
Map<String, dynamic> get result => {
  'accessToken': 'access',
  'refreshToken': 'refresh',
  'user': {'id': 'parent'},
};

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });
  testWidgets('Google login goes directly to provider without a terms dialog', (
    tester,
  ) async {
    var opened = false;
    AuthService.instance = AuthService(
      socialIdentityProvider: (_, _) async => {'idToken': 'signed-token'},
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/social');
        return response({...result, 'isNewUser': false});
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          onSignUp: () {},
          onBack: () {},
          onLoginSuccess: () => opened = true,
        ),
      ),
    );
    final google = find.widgetWithText(OutlinedButton, 'Tiếp tục với Google');
    await tester.ensureVisible(google);
    await tester.tap(google);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(opened, true);
  });
  testWidgets('Google cancellation is visible instead of silently returning', (
    tester,
  ) async {
    AuthService.instance = AuthService(
      socialIdentityProvider: (_, _) async =>
          throw const SocialIdentityException('SOCIAL_CANCELLED'),
      client: MockClient((_) async => throw StateError('No request expected')),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(onSignUp: () {}, onBack: () {}),
      ),
    );
    final google = find.widgetWithText(OutlinedButton, 'Tiếp tục với Google');
    await tester.ensureVisible(google);
    await tester.tap(google);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Chưa đăng nhập được. Kiểm tra mạng và thử lại.',
      ),
      findsOneWidget,
    );
  });
  testWidgets(
    'Google registration requires consent and opens child form after session',
    (tester) async {
      var calls = 0;
      var opened = false;
      AuthService.instance = AuthService(
        socialIdentityProvider: (provider, nonce) async {
          expect(provider, 'google');
          return {'idToken': 'provider-signed-token'};
        },
        client: MockClient((request) async {
          calls++;
          final body = jsonDecode(request.body) as Map;
          expect(request.url.path, '/api/v1/auth/social');
          expect(body['idToken'], 'provider-signed-token');
          expect(body['acceptedTerms'], true);
          expect(body.containsKey('password'), false);
          return response({...result, 'isNewUser': true});
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SignUpScreen(
            onLogin: () {},
            onChildProfilePreview: () => opened = true,
          ),
        ),
      );
      final google = find.widgetWithText(OutlinedButton, 'Tiếp tục với Google');
      await tester.ensureVisible(google);
      await tester.tap(google);
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.ensureVisible(google);
      await tester.tap(google);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(opened, true);
      expect(AuthService.instance.signedIn, true);
    },
  );
  testWidgets('local preview is visibly marked as a test code', (tester) async {
    final preview = challenge('preview')
      ..['deliveryStatus'] = 'preview'
      ..['devOtp'] = '123456';
    await tester.pumpWidget(MaterialApp(home: OtpDialog(challenge: preview)));
    expect(find.textContaining('Mã thử nghiệm: 123456'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed resend still replaces the invalidated challenge', (
    tester,
  ) async {
    String? submittedId;
    AuthService.instance = AuthService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/resend')) {
          return response(
            challenge('replacement')..['deliveryStatus'] = 'failed',
          );
        }
        submittedId =
            (jsonDecode(request.body) as Map)['verificationId'] as String;
        return response(result);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(home: OtpDialog(challenge: challenge('original'))),
    );
    await tester.tap(find.text('Gửi lại OTP'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(submittedId, 'replacement');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'OTP error, resend replacement and success use server challenge',
    (tester) async {
      var verified = false;
      final requests = <Map<String, dynamic>>[];
      AuthService.instance = AuthService(
        client: MockClient((r) async {
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          requests.add(body);
          if (r.url.path.endsWith('/resend')) {
            return response(challenge('replacement'));
          }
          if (body['verificationId'] != 'replacement' ||
              body['code'] != '876540') {
            return response({
              'error': {'code': 'OTP_INVALID'},
            }, 400);
          }
          return response(result);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  verified =
                      await showOtpVerificationDialog(
                        context,
                        challenge: challenge('original'),
                      ) ==
                      true;
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '000000');
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(find.text('Mã OTP chưa đúng.'), findsOneWidget);
      expect(verified, isFalse);
      await tester.tap(find.text('Gửi lại OTP'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '876540');
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(verified, isTrue);
      expect(requests.last['verificationId'], 'replacement');
      expect(AuthService.instance.signedIn, isTrue);
    },
  );

  testWidgets('pending login continues through OTP before navigation', (
    tester,
  ) async {
    var loggedIn = false;
    AuthService.instance = AuthService(
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) {
          return response({
            'error': {
              'code': 'VERIFICATION_REQUIRED',
              'details': {'registration': challenge('pending')},
            },
          }, 403);
        }
        return response(result);
      }),
    );
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
    await tester.enterText(
      find.byType(TextFormField).first,
      'parent@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Password12345!');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Xác thực OTP'), findsOneWidget);
    expect(loggedIn, isFalse);
    await tester.enterText(find.byType(TextField).last, '876540');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(loggedIn, isTrue);
  });
  testWidgets('OTP blocks confirmation after five wrong attempts', (
    tester,
  ) async {
    var calls = 0;
    AuthService.instance = AuthService(
      client: MockClient((request) async {
        calls++;
        return response({
          'error': {'code': 'OTP_INVALID'},
        }, 400);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(home: OtpDialog(challenge: challenge('limited'))),
    );
    await tester.enterText(find.byType(TextField), '012345');
    for (var i = 0; i < 5; i++) {
      final button = find.byType(FilledButton);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }
    expect(calls, 5);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('expired OTP cannot be submitted', (tester) async {
    final expired = challenge('expired')
      ..['expiresAt'] = DateTime.now()
          .subtract(const Duration(seconds: 1))
          .toIso8601String();
    await tester.pumpWidget(MaterialApp(home: OtpDialog(challenge: expired)));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
