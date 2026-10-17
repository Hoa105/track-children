import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/services/auth_service.dart';
import 'package:track_children/services/demo_store.dart';

final profile = <String, dynamic>{
  'id': 'server-user',
  'email': 'parent@example.com',
  'fullName': 'Parent',
  'username': 'parent',
  'phone': '+84912345678',
  'relationship': 'mother',
};
Map<String, dynamic> tokens(String suffix, {bool withUser = true}) => {
  'accessToken': 'access-$suffix',
  'refreshToken': 'refresh-$suffix',
  'expiresIn': 900,
  'sessionExpiresAt': '2026-11-16T03:00:00Z',
  if (withUser) 'user': profile,
};
http.Response jsonResponse(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'rememberMe saves only refresh secret and restore verifies server identity',
    () async {
      final calls = <String>[];
      final client = MockClient((r) async {
        calls.add(r.url.path);
        if (r.url.path.endsWith('/me')) return jsonResponse(profile);
        return jsonResponse(
          tokens(r.url.path.endsWith('/refresh') ? 'new' : 'old'),
        );
      });
      final service = AuthService(client: client);
      await service.login('parent@example.com', 'Password12345!');
      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'auth.refresh'), 'refresh-old');
      final all = await storage.readAll();
      expect(all.values, isNot(contains('Password12345!')));
      expect(all.values, isNot(contains('access-old')));
      final restarted = AuthService(client: client);
      expect(await restarted.restore(), isTrue);
      expect(restarted.user!['id'], profile['id']);
      expect(
        calls,
        containsAllInOrder([
          '/api/v1/auth/login',
          '/api/v1/auth/refresh',
          '/api/v1/auth/me',
        ]),
      );
    },
  );

  test('rememberMe false does not survive restart', () async {
    final client = MockClient((_) async => jsonResponse(tokens('one')));
    final service = AuthService(client: client);
    await service.login('parent@example.com', 'password', remember: false);
    expect(service.signedIn, isTrue);
    expect(
      await const FlutterSecureStorage().read(key: 'auth.refresh'),
      isNull,
    );
    expect(await AuthService(client: client).restore(), isFalse);
  });

  test(
    'concurrent refresh uses one rotation and persists replacement',
    () async {
      var rotations = 0;
      final client = MockClient((r) async {
        if (r.url.path.endsWith('/refresh')) {
          rotations++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return jsonResponse(tokens('new', withUser: false));
        }
        return jsonResponse(tokens('old'));
      });
      final service = AuthService(client: client);
      await service.login('parent@example.com', 'password');
      await Future.wait(List.generate(5, (_) => service.refresh()));
      expect(rotations, 1);
      expect(
        await const FlutterSecureStorage().read(key: 'auth.refresh'),
        'refresh-new',
      );
    },
  );

  test('expired access retries me once with refreshed token', () async {
    var meCalls = 0;
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/me')) {
        meCalls++;
        if (meCalls == 1) {
          return jsonResponse({
            'error': {'code': 'ACCESS_TOKEN_EXPIRED'},
          }, 401);
        }
        expect(r.headers['Authorization'], 'Bearer access-new');
        return jsonResponse(profile);
      }
      return jsonResponse(
        tokens(r.url.path.endsWith('/refresh') ? 'new' : 'old'),
      );
    });
    final service = AuthService(client: client);
    await service.login('parent@example.com', 'password');
    expect((await service.currentUser())['id'], 'server-user');
    expect(meCalls, 2);
  });

  test(
    'logout offline clears secrets and reports server revocation failure',
    () async {
      final service = AuthService(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/logout')) {
            throw http.ClientException('offline');
          }
          return jsonResponse(tokens('old'));
        }),
      );
      await service.login('parent@example.com', 'password');
      expect(await service.logout(), isFalse);
      expect(service.signedIn, isFalse);
      expect(
        await const FlutterSecureStorage().read(key: 'auth.refresh'),
        isNull,
      );
    },
  );

  test('pending account preserves registration challenge for OTP UI', () async {
    final service = AuthService(
      client: MockClient(
        (_) async => jsonResponse({
          'error': {
            'code': 'VERIFICATION_REQUIRED',
            'details': {
              'registration': {
                'verificationId': 'otp',
                'registrationToken': 'secret',
              },
            },
          },
        }, 403),
      ),
    );
    try {
      await service.login('parent@example.com', 'password');
      fail('must require verification');
    } on AuthException catch (e) {
      expect(e.details['registration']['registrationToken'], 'secret');
    }
    expect(service.signedIn, isFalse);
  });

  test('rejected refresh clears session and requires login', () async {
    final service = AuthService(
      client: MockClient((r) async {
        if (r.url.path.endsWith('/refresh')) {
          return jsonResponse({
            'error': {'code': 'SESSION_REVOKED'},
          }, 401);
        }
        return jsonResponse(tokens('old'));
      }),
    );
    await service.login('parent@example.com', 'password');
    await expectLater(service.refresh(), throwsA(isA<AuthException>()));
    expect(service.signedIn, isFalse);
    expect(
      await const FlutterSecureStorage().read(key: 'auth.refresh'),
      isNull,
    );
  });

  test('server cache has no password and logout isolates child data by owner', () async {
    final store = DemoStore();
    await store.initialize();
    await store.bindAuthenticatedUser(profile);
    expect(store.parent.containsKey('password'), isFalse);
    await store.saveChild(null, {
      'full_name': 'Private Child',
      'date_of_birth': '2025-01-01',
      'gender': 'female',
    });
    expect(store.children, isNotEmpty);
    await store.clearAuthenticatedCache();
    await store.bindAuthenticatedUser({...profile, 'id': 'different-user'});
    expect(store.children, isEmpty);
    await store.bindAuthenticatedUser(profile);
    expect(store.children, hasLength(1));
  });
}
