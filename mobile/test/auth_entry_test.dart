import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/auth/auth_screen.dart';
import 'package:track_children/features/auth/login_screen.dart';
import 'package:track_children/features/auth/sign_up_screen.dart';
import 'package:track_children/services/auth_entry_preferences.dart';

void main() {
  test(
    'first auth visit is persisted independently from introduction',
    () async {
      SharedPreferences.setMockInitialValues({
        'track_children_onboarding_completed': true,
      });
      expect(await AuthEntryPreferences().takeFirstVisit(), true);
      expect(await AuthEntryPreferences().takeFirstVisit(), false);
    },
  );

  testWidgets('first visit opens signup and allows switching to login', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          initialSignUp: true,
          onLoginSuccess: () {},
          onChildProfilePreview: () {},
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);
    final link = find.text('Đã có tài khoản? Đăng nhập');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('returning auth entry keeps login as default', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          onLoginSuccess: () {},
          onChildProfilePreview: () {},
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SignUpScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
