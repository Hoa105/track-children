import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/auth/forgot_password_sheet.dart';

class _Recovery extends PasswordRecovery {
  String? password;
  @override
  Future<Map<String, dynamic>> send(String account) async => {
    'targetMasked': 'p***@example.com',
    'expiresAt': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
  };
  @override
  Future<String> verify(Map<String, dynamic> challenge, String code) async {
    expect(code, '012345');
    return 'verified-reset-token';
  }
  @override
  Future<void> reset(String token, String value) async {
    expect(token, 'verified-reset-token');
    password = value;
  }
}

void main() {
  testWidgets('recovery opens password popup only after OTP verification', (tester) async {
    final recovery = _Recovery();
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () => showForgotPasswordSheet(context, recovery: recovery), child: const Text('Open')),
    ))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Đặt mật khẩu mới'), findsNothing);
    await tester.enterText(find.byType(TextFormField), 'parent@example.com');
    await tester.tap(find.text('Gửi mã OTP'));
    await tester.pumpAndSettle();
    expect(find.text('Xác minh OTP'), findsOneWidget);
    expect(find.text('Đặt mật khẩu mới'), findsNothing);
    await tester.enterText(find.byType(TextFormField), '012345');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(find.text('Đặt mật khẩu mới'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'abcdefgh');
    await tester.enterText(find.byType(TextFormField).last, 'abcdefgh');
    await tester.tap(find.text('Lưu mật khẩu'));
    await tester.pumpAndSettle();
    expect(recovery.password, 'abcdefgh');
    expect(find.byType(AlertDialog), findsNothing);
  });
}
