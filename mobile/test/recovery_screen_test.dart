import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:track_children/features/auth/recovery_screen.dart';
import 'package:track_children/services/auth_service.dart';

Map<String, dynamic> grant() => {
  'transactionId': 'root',
  'transactionToken': 'secret',
  'expiresAt': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
  'resendAvailableAt': DateTime.now()
      .add(const Duration(seconds: 60))
      .toIso8601String(),
};
http.Response response(Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Future<void> next(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('recovery-next'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String value) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final additional in [false, true]) {
    testWidgets(
      'recovery ${additional ? 'requires independent email' : 'validates Vietnamese password'}',
      (tester) async {
        final calls = <String>[];
        AuthService.instance = AuthService(
          client: MockClient((request) async {
            final path = request.url.path;
            calls.add(path);
            if (path.endsWith('/email/start')) {
              return response({...grant(), 'transactionId': 'email-child'});
            }
            if (path.endsWith('/email/verify')) {
              expect(jsonDecode(request.body)['transactionId'], 'email-child');
              return response({'verified': true});
            }
            if (path.endsWith('/verify')) {
              return response({
                ...grant(),
                'requiresAdditionalVerification': additional,
                'verificationOptions': ['email', 'support'],
              });
            }
            if (path.endsWith('/complete')) {
              final body = jsonDecode(request.body);
              expect(body['transactionId'], 'root');
              expect(body['newPassword'], 'Q7!m2#Zx');
              return response({'reset': true});
            }
            return response(grant());
          }),
        );
        await tester.pumpWidget(
          const MaterialApp(home: RecoveryScreen(initialAccount: '0912345678')),
        );
        await tester.pumpAndSettle();
        await next(tester);
        await enter(tester, 'recovery-code', '012345');
        await next(tester);
        if (additional) {
          expect(find.byKey(const ValueKey('recovery-password')), findsNothing);
          expect(find.text('belonkhon@gmail.com'), findsOneWidget);
          final email = find.text('Xác minh qua email');
          await tester.ensureVisible(email);
          await tester.tap(email);
          await tester.pumpAndSettle();
          await enter(tester, 'recovery-email-code', '123456');
          await next(tester);
        }
        await enter(tester, 'recovery-password', 'Mậtkhẩu8!');
        await enter(tester, 'recovery-confirm', 'Mậtkhẩu8!');
        await next(tester);
        expect(calls.where((p) => p.endsWith('/complete')), isEmpty);
        expect(
          find.text('Mật khẩu không được chứa dấu, khoảng trắng hoặc emoji.'),
          findsOneWidget,
        );
        await enter(tester, 'recovery-password', 'Q7!m2#Zx');
        await enter(tester, 'recovery-confirm', 'Q7!m2#Zx');
        await next(tester);
        expect(calls.where((p) => p.endsWith('/complete')).length, 1);
        expect(AuthService.instance.signedIn, false);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
