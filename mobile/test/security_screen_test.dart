import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:track_children/features/settings/security_screen.dart';
import 'package:track_children/services/auth_service.dart';

http.Response jsonResponse(Map<String, dynamic> value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Map<String, dynamic> session() => {
  'accessToken': 'new-access',
  'refreshToken': 'new-refresh',
  'user': {'id': 'user'},
};
Map<String, dynamic> ticket() => {
  'transactionId': 'ticket',
  'transactionToken': 'secret',
  'targetMasked': 'n***@example.com',
  'expiresAt': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
  'resendAvailableAt': DateTime.now()
      .add(const Duration(seconds: 60))
      .toIso8601String(),
};
Future<void> tap(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets('owned children block delete before reauth or API deletion', (
    tester,
  ) async {
    final calls = <String>[];
    AuthService.instance = AuthService(
      client: MockClient((request) async {
        calls.add(request.url.path);
        return jsonResponse({
          'hasPassword': true,
          'providers': ['google'],
          'ownedChildren': 1,
          'phone': '+84912345678',
        });
      }),
    );
    await tester.pumpWidget(const MaterialApp(home: SecurityScreen()));
    await tester.pumpAndSettle();
    await tap(tester, 'Xóa tài khoản');
    expect(
      find.text(
        'Hãy chuyển quyền hoặc xóa từng hồ sơ trẻ đang sở hữu trước khi xóa tài khoản.',
      ),
      findsOneWidget,
    );
    expect(
      calls.where(
        (p) => p.endsWith('/account/delete') || p.endsWith('/reauth'),
      ),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('email change requires current proof then new-channel OTP', (
    tester,
  ) async {
    final calls = <String>[];
    AuthService.instance = AuthService(
      client: MockClient((request) async {
        final path = request.url.path;
        calls.add(path);
        if (path.endsWith('/security')) {
          return jsonResponse({
            'hasPassword': true,
            'providers': [],
            'ownedChildren': 0,
          });
        }
        if (path.endsWith('/reauth')) {
          final body = jsonDecode(request.body);
          expect(body['action'], 'change_email');
          expect(body['target'], 'new@example.com');
          expect(body['currentPassword'], 'Current!9');
          return jsonResponse(ticket());
        }
        if (path.endsWith('/email/start')) return jsonResponse(ticket());
        if (path.endsWith('/email/verify')) {
          expect(jsonDecode(request.body)['code'], '012345');
          return jsonResponse(session());
        }
        fail('Unexpected request $path');
      }),
    );
    await tester.pumpWidget(const MaterialApp(home: SecurityScreen()));
    await tester.pumpAndSettle();
    await tap(tester, 'Email');
    await tester.enterText(find.byType(TextFormField), 'new@example.com');
    await tap(tester, 'Tiếp tục');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tap(tester, 'Mật khẩu hiện tại');
    await tester.enterText(find.byType(TextFormField), 'Current!9');
    await tap(tester, 'Tiếp tục');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('security-otp')), findsOneWidget);
    expect(calls.where((p) => p.endsWith('/email/verify')), isEmpty);
    await tester.enterText(
      find.byKey(const ValueKey('security-otp')),
      '012345',
    );
    await tester.pump();
    await tap(tester, 'Xác minh');
    expect(calls.where((p) => p.endsWith('/email/verify')).length, 1);
    expect(AuthService.instance.signedIn, true);
    await tester.pumpWidget(const SizedBox());
  });
  test(
    'setup password accepts replacement credentials and preserves confirmation',
    () async {
      final service = AuthService(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/auth/v2/password/setup');
          final body = jsonDecode(request.body);
          expect(body['newPassword'], 'Q7!m2#Zx');
          expect(body['confirmPassword'], 'Q7!m2#Zx');
          return jsonResponse(session());
        }),
      );
      await service.setupPassword(ticket(), 'Q7!m2#Zx', 'Q7!m2#Zx');
      expect(service.signedIn, true);
    },
  );
}
