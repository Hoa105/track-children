import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:track_children/features/auth/sign_up_screen.dart';
import 'package:track_children/features/auth/social_profile_screen.dart';
import 'package:track_children/services/auth_service.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  for (final provider in ['Google', 'Apple']) {
    for (final cancel in [false, true]) {
      testWidgets(
        '$provider requires profile and explicit consent; cancel=$cancel',
        (tester) async {
          var selected = false;
          var submitted = false;
          var existing = false;
          var created = false;
          AuthService.instance = AuthService(
            socialIdentityProvider: (name, nonce) async {
              expect(name, provider.toLowerCase());
              if (provider == 'Apple') expect(nonce, 'nonce');
              selected = true;
              return {
                'idToken': 'signed-token',
                'displayName': 'Người chăm sóc',
                'email': 'parent@example.com',
              };
            },
            client: MockClient((request) async {
              if (request.url.path.endsWith('/challenge')) {
                return http.Response(
                  jsonEncode({
                    'nonce': 'nonce',
                    'challenge': 'signed-challenge',
                  }),
                  200,
                );
              }
              expect(selected, true);
              if (request.url.path.endsWith('/social/start')) {
                final body = jsonDecode(request.body) as Map;
                expect(body['provider'], provider.toLowerCase());
                expect(body.containsKey('acceptedTerms'), false);
                if (provider == 'Apple') {
                  expect(body['challenge'], 'signed-challenge');
                }
                return http.Response(
                  jsonEncode({
                    'requiresProfile': true,
                    'transactionId': 'social-registration',
                    'transactionToken': 'test-transaction-token',
                    'documentsDigest': 'test-documents-digest',
                    'displayName': 'Người chăm sóc',
                  }),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                );
              }
              expect(request.url.path, endsWith('/social/complete'));
              submitted = true;
              final body = jsonDecode(request.body) as Map;
              expect(body['acceptedTerms'], true);
              expect(body['defaultRelationship'], 'other_guardian');
              expect(body.containsKey('email'), false);
              expect(body['transactionId'], 'social-registration');
              expect(body['documentsDigest'], 'test-documents-digest');
              return http.Response(
                jsonEncode({
                  'accessToken': 'access',
                  'refreshToken': 'refresh',
                  'user': {'id': 'parent'},
                  'isNewUser': true,
                }),
                200,
              );
            }),
          );
          await tester.pumpWidget(
            MaterialApp(
              home: SignUpScreen(
                onLogin: () {},
                onChildProfilePreview: () => created = true,
                onExistingAccount: () => existing = true,
              ),
            ),
          );
          final button = find.widgetWithText(
            OutlinedButton,
            'Tiếp tục với $provider',
          );
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(selected, true);
          expect(submitted, false);
          expect(find.byType(SocialProfileScreen), findsOneWidget);
          if (cancel) {
            await tester.tap(find.byTooltip('Quay lại'));
            await tester.pumpAndSettle();
            expect(submitted, false);
            expect(AuthService.instance.signedIn, false);
            expect(created || existing, false);
          } else {
            final finish = find.widgetWithText(
              FilledButton,
              'Hoàn tất đăng ký',
            );
            await tester.ensureVisible(finish);
            await tester.tap(finish);
            await tester.pumpAndSettle();
            expect(submitted, false);
            final role = find.widgetWithText(ChoiceChip, 'Khác');
            await tester.ensureVisible(role);
            await tester.tap(role);
            await tester.pumpAndSettle();
            await tester.ensureVisible(finish);
            await tester.tap(finish);
            await tester.pumpAndSettle();
            expect(submitted, false);
            final consent = find.byKey(const ValueKey('registration-consent'));
            await tester.ensureVisible(consent);
            await tester.tap(consent);
            await tester.pumpAndSettle();
            await tester.ensureVisible(finish);
            await tester.tap(finish);
            await tester.pumpAndSettle();
            expect(submitted, true);
            expect(existing, false);
            expect(created, true);
            expect(AuthService.instance.signedIn, true);
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
