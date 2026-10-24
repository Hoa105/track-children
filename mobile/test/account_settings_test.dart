import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/services/demo_store.dart';
import 'package:track_children/features/account/account_settings_screen.dart';
import 'package:track_children/features/settings/live_change_password_dialog.dart';
import 'package:track_children/services/auth_service.dart';

void main() {
  late AuthService original;
  setUp(() {
    original = AuthService.instance;
    AuthService.instance = AuthService();
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
  });
  tearDown(() => AuthService.instance = original);

  for (final editing in [false, true]) {
    testWidgets(
      'cache renders immediately; background response respects editing=$editing',
      (tester) async {
        final response = Completer<http.Response>();
        AuthService.instance = AuthService(
          client: MockClient((_) => response.future),
        )..user = {'id': 'server-user'};
        await DemoStore.instance.bindAuthenticatedUser({
          'id': 'server-user',
          'displayName': 'Cached',
          'defaultRelationship': 'mother',
        });
        await tester.pumpWidget(
          const MaterialApp(home: AccountSettingsScreen(fullName: 'Cached')),
        );
        expect(find.text('Cached'), findsWidgets);
        if (editing) {
          await tester.tap(find.byIcon(Icons.edit_outlined));
          await tester.pump();
          await tester.enterText(find.byType(TextFormField).first, 'My draft');
        }
        response.complete(
          http.Response(
            jsonEncode({
              'id': 'server-user',
              'displayName': 'Fresh',
              'email': 'fresh@example.com',
              'phone': null,
              'defaultRelationship': 'other_guardian',
            }),
            200,
          ),
        );
        await tester.pumpAndSettle();
        final fields = tester
            .widgetList<TextField>(find.byType(TextField))
            .toList();
        expect(fields.first.controller!.text, editing ? 'My draft' : 'Fresh');
        expect(DemoStore.instance.parent['fullName'], 'Fresh');
        expect(AuthService.instance.user!['displayName'], 'Fresh');
        if (!editing) {
          expect(fields[2].controller!.text, 'fresh@example.com');
          expect(fields[3].controller!.text, '');
        }
      },
    );
  }

  testWidgets('offline refresh keeps cached profile visible', (tester) async {
    AuthService.instance = AuthService(
      client: MockClient((_) async {
        throw http.ClientException('offline');
      }),
    )..user = {'id': 'server-user'};
    await tester.pumpWidget(
      const MaterialApp(home: AccountSettingsScreen(fullName: 'Cached')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cached'), findsWidgets);
    expect(AuthService.instance.signedIn, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('revoked session requests login again', (tester) async {
    var requestedLogin = false;
    AuthService.instance = AuthService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'code': 'SESSION_REVOKED'},
          }),
          401,
        ),
      ),
    )..user = {'id': 'server-user'};
    await tester.pumpWidget(
      MaterialApp(
        home: AccountSettingsScreen(
          fullName: 'Cached',
          onSessionExpired: () => requestedLogin = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(AuthService.instance.signedIn, false);
    expect(requestedLogin, true);
  });

  testWidgets('editing keeps email and phone read-only', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AccountSettingsScreen()));
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pump();
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields[0].readOnly, false);
    expect(fields[1].readOnly, true);
    expect(fields[2].readOnly, true);
    expect(fields[3].readOnly, true);
  });

  testWidgets('wrong password keeps dialog open for correction', (
    tester,
  ) async {
    final original = AuthService.instance;
    addTearDown(() => AuthService.instance = original);
    AuthService.instance = AuthService(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'code': 'INVALID_CREDENTIALS'},
          }),
          401,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => const LiveChangePasswordDialog(),
                ),
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'wrong-password');
    await tester.enterText(fields.at(1), 'new-password');
    await tester.enterText(fields.at(2), 'new-password');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(find.byType(LiveChangePasswordDialog), findsOneWidget);
    expect(find.text('Mật khẩu hiện tại chưa đúng.'), findsOneWidget);
  });
}
