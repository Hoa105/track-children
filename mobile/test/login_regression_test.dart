import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:track_children/features/auth/login_screen.dart';
import 'package:track_children/services/auth_service.dart';
import 'package:track_children/services/social_identity.dart';

http.Response reply(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status);
Map<String, dynamic> get session => {
  'accessToken': 'access-test',
  'refreshToken': 'refresh-test',
  'user': {'id': 'parent-test', 'email': 'parent@example.com'},
};
Matcher authError(String code) =>
    isA<AuthException>().having((e) => e.code, 'code', code);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  for (final response in [
    http.Response('Internal Server Error', 500),
    reply({
      'error': {'code': 'DATABASE_UNAVAILABLE'},
    }, 503),
    http.Response('not JSON', 200),
  ]) {
    test(
      'restore preserves saved session on temporary server response ${response.statusCode} ${response.body}',
      () async {
        FlutterSecureStorage.setMockInitialValues({
          'auth.refresh': 'refresh-test',
        });
        final service = AuthService(client: MockClient((_) async => response));
        expect(await service.restore(), false);
        expect(
          await const FlutterSecureStorage().read(key: 'auth.refresh'),
          'refresh-test',
        );
      },
    );
  }

  test('malformed success response has a distinct protocol error', () async {
    final service = AuthService(
      client: MockClient((_) async => http.Response('[]', 200)),
    );
    await expectLater(
      service.login('parent@example.com', 'secret'),
      throwsA(authError('SERVER_RESPONSE_INVALID')),
    );
  });

  for (final code in [
    'INVALID_CREDENTIALS',
    'ACCOUNT_LOCKED',
    'LOGIN_TEMPORARILY_LOCKED',
    'RATE_LIMITED',
    'ACCOUNT_UNAVAILABLE',
    'AUTH_NOT_CONFIGURED',
  ]) {
    test('rejected password login: $code leaves no session', () async {
      final service = AuthService(
        client: MockClient(
          (_) async => reply({
            'error': {'code': code},
          }, code.contains('LOCKED') ? 429 : 403),
        ),
      );
      await expectLater(
        service.login('parent@example.com', 'wrong'),
        throwsA(authError(code)),
      );
      expect(service.signedIn, false);
      expect(
        await const FlutterSecureStorage().read(key: 'auth.refresh'),
        isNull,
      );
    });
  }

  for (final failure in [
    http.ClientException('offline'),
    TimeoutException('timeout'),
  ]) {
    test(
      'password login transport ${failure.runtimeType} is retryable',
      () async {
        var offline = true;
        final service = AuthService(
          client: MockClient((_) async {
            if (offline) throw failure;
            return reply(session);
          }),
        );
        await expectLater(
          service.login('parent@example.com', 'secret'),
          throwsA(authError('NETWORK_ERROR')),
        );
        expect(service.signedIn, false);
        offline = false;
        await service.login('parent@example.com', 'secret');
        expect(service.signedIn, true);
      },
    );
  }

  test('remembered login restores session after app restart', () async {
    final client = MockClient(
      (r) async =>
          reply(r.url.path.endsWith('/me') ? session['user']! : session),
    );
    await AuthService(client: client).login('parent@example.com', 'secret');
    final restarted = AuthService(client: client);
    expect(await restarted.restore(), true);
    expect(restarted.user!['id'], 'parent-test');
  });

  test(
    'offline restore preserves remembered refresh token for retry',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'auth.refresh': 'refresh-test',
      });
      final service = AuthService(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      expect(await service.restore(), false);
      expect(
        await const FlutterSecureStorage().read(key: 'auth.refresh'),
        'refresh-test',
      );
    },
  );

  test(
    'HTTP 500 HTML is a server error rather than a network failure',
    () async {
      final service = AuthService(
        client: MockClient(
          (_) async => http.Response('Internal Server Error', 500),
        ),
      );
      await expectLater(
        service.login('parent@example.com', 'secret'),
        throwsA(authError('HTTP_500')),
      );
    },
  );

  for (final code in [
    'SOCIAL_CANCELLED',
    'SOCIAL_SIGN_IN_FAILED',
    'SOCIAL_AUTH_NOT_CONFIGURED',
    'GOOGLE_CLIENT_ID_MISSING',
    'GOOGLE_OAUTH_CONFIGURATION_ERROR',
    'SOCIAL_TOKEN_INVALID',
    'SOCIAL_PLATFORM_UNSUPPORTED',
  ]) {
    test('Google SDK error $code sends no backend request', () async {
      var calls = 0;
      final service = AuthService(
        socialIdentityProvider: (_, _) async =>
            throw SocialIdentityException(code),
        client: MockClient((_) async {
          calls++;
          return reply(session);
        }),
      );
      await expectLater(
        service.socialRegister('google', acceptedTerms: true),
        throwsA(authError(code)),
      );
      expect(calls, 0);
      expect(service.signedIn, false);
    });
  }

  for (final code in [
    'SOCIAL_ACCOUNT_CONFLICT',
    'SOCIAL_PROVIDER_UNAVAILABLE',
    'SOCIAL_TOKEN_INVALID',
    'SOCIAL_EMAIL_NOT_VERIFIED',
    'ACCOUNT_UNAVAILABLE',
  ]) {
    test('Google backend rejection $code never saves tokens', () async {
      final service = AuthService(
        socialIdentityProvider: (_, _) async => {'idToken': 'provider-token'},
        client: MockClient(
          (_) async => reply({
            'error': {'code': code},
          }, 403),
        ),
      );
      await expectLater(
        service.socialRegister('google', acceptedTerms: true),
        throwsA(authError(code)),
      );
      expect(service.signedIn, false);
      expect(
        await const FlutterSecureStorage().read(key: 'auth.refresh'),
        isNull,
      );
    });
  }

  for (final account in ['wrong@email', 'abc123']) {
    testWidgets('invalid account $account is rejected before API call', (
      tester,
    ) async {
      var calls = 0;
      AuthService.instance = AuthService(
        client: MockClient((_) async {
          calls++;
          return reply(session);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(onSignUp: () {}, onBack: () {}),
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), account);
      await tester.enterText(find.byType(TextFormField).at(1), 'secret');
      final submit = find.widgetWithText(FilledButton, 'Đăng nhập');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(AuthService.instance.signedIn, false);
    });
  }

  for (final code in [
    'INVALID_CREDENTIALS',
    'ACCOUNT_LOCKED',
    'NETWORK_ERROR',
  ]) {
    testWidgets('login shows $code and allows retry without navigating', (
      tester,
    ) async {
      var navigated = false;
      AuthService.instance = AuthService(
        client: MockClient((_) async {
          if (code == 'NETWORK_ERROR') throw http.ClientException('offline');
          return reply({
            'error': {'code': code},
          }, 403);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            onSignUp: () {},
            onBack: () {},
            onLoginSuccess: () => navigated = true,
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'parent@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'secret');
      final submit = find.widgetWithText(FilledButton, 'Đăng nhập');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      final message = code == 'INVALID_CREDENTIALS'
          ? 'Email/số điện thoại hoặc mật khẩu không đúng'
          : AuthException(code, {}).toString();
      expect(find.text(message), findsOneWidget);
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      expect(navigated, false);
    });
  }

  testWidgets('invalid empty form does not call API', (tester) async {
    var calls = 0;
    AuthService.instance = AuthService(
      client: MockClient((_) async {
        calls++;
        return reply(session);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(onSignUp: () {}, onBack: () {}),
      ),
    );
    final submit = find.widgetWithText(FilledButton, 'Đăng nhập');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Vui lòng nhập mật khẩu.'), findsOneWidget);
  });

  testWidgets(
    'double submit sends one request and successful login navigates once',
    (tester) async {
      final pending = Completer<http.Response>();
      var calls = 0;
      var navigations = 0;
      AuthService.instance = AuthService(
        client: MockClient((_) {
          calls++;
          return pending.future;
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            onSignUp: () {},
            onBack: () {},
            onLoginSuccess: () => navigations++,
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'parent@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'secret');
      final submit = find.byType(FilledButton).first;
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.tap(submit);
      await tester.pump(const Duration(milliseconds: 100));
      expect(calls, 1);
      expect(navigations, 0);
      pending.complete(reply(session));
      await tester.pumpAndSettle();
      expect(navigations, 1);
    },
  );
}
