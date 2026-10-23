import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:track_children/features/auth/login_screen.dart';
import 'package:track_children/features/auth/otp_dialog.dart';
import 'package:track_children/services/auth_service.dart';

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
