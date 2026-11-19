import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:track_children/services/auth_service.dart';
import 'package:track_children/features/auth/registration_gateway.dart';

http.Response jsonResponse(Map<String, dynamic> value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Map<String, dynamic> session() => {
  'accessToken': 'test-access',
  'refreshToken': 'test-refresh',
  'user': {'id': 'test-user'},
  'isNewUser': true,
};
Map<String, dynamic> ticket() => {
  'transactionId': 'test-transaction',
  'transactionToken': 'test-only-token',
  'documentsDigest': 'a' * 64,
  'expiresAt': DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
  'resendAvailableAt': DateTime.now().toIso8601String(),
  'targetMasked': '+84******123',
};

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('real gateway calls OTP-first contract and accepts session only on complete', () async {
    final calls = <String>[];
    AuthService.instance = AuthService(
      client: MockClient((request) async {
        calls.add(request.url.path);
        final body = jsonDecode(request.body) as Map;
        if (request.url.path.endsWith('/start')) {
          expect(body.containsKey('password'), false);
          expect(body.containsKey('acceptedTerms'), false);
        }
        if (request.url.path.endsWith('/complete')) {
          expect(body['password'], body['confirmPassword']);
          expect(body['displayName'], 'Nguyễn Thị Ánh');
          expect(body.containsKey('phone'), false);
          expect(body['documentsDigest'], 'a' * 64);
          return jsonResponse(session());
        }
        return jsonResponse(ticket());
      }),
    );
    final gateway = ApiRegistrationGateway();
    final challenge = await gateway.start('0912345678');
    expect(AuthService.instance.signedIn, false);
    final grant = await gateway.verify(challenge, '012345');
    expect(AuthService.instance.signedIn, false);
    await gateway.complete(grant, {
      'password': 'Q7!m2#Zx',
      'confirmPassword': 'Q7!m2#Zx',
      'displayName': 'Nguyễn Thị Ánh',
      'defaultRelationship': 'mother',
      'acceptedTerms': true,
    });
    expect(AuthService.instance.signedIn, true);
    expect(calls, [
      '/api/v1/auth/v2/signup/start',
      '/api/v1/auth/v2/signup/verify',
      '/api/v1/auth/v2/signup/complete',
    ]);
  });

  test('existing provider skips profile consent', () async {
    var asked = false;
    AuthService.instance = AuthService(
      socialIdentityProvider: (_, _) async => {'idToken': 'test-token'},
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/v2/social/start');
        return jsonResponse({...session(), 'isNewUser': false});
      }),
    );
    final created = await AuthService.instance.socialRegister(
      'google',
      acceptedTerms: false,
      requestConsent: (account) async {
        asked = true;
        return null;
      },
    );
    expect(created, false);
    expect(asked, false);
    expect(AuthService.instance.signedIn, true);
  });

  test(
    'Apple new profile uses completion grant without resending one-use code',
    () async {
      var exchanges = 0;
      AuthService.instance = AuthService(
        socialIdentityProvider: (_, nonce) async => {
          'idToken': 'test-token',
          'authorizationCode': 'one-use',
          'displayName': 'Original',
        },
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          if (request.url.path.endsWith('/challenge')) {
            return jsonResponse({'nonce': 'nonce', 'challenge': 'challenge'});
          }
          if (request.url.path.endsWith('/start')) {
            expect(body['authorizationCode'], 'one-use');
            exchanges++;
            return jsonResponse({
              ...ticket(),
              'requiresProfile': true,
              'displayName': 'Original',
            });
          }
          expect(request.url.path, '/api/v1/auth/v2/social/complete');
          expect(body.containsKey('idToken'), false);
          expect(body.containsKey('authorizationCode'), false);
          expect(body['displayName'], 'Đỗ Đức');
          return jsonResponse(session());
        }),
      );
      final created = await AuthService.instance.socialRegister(
        'apple',
        acceptedTerms: false,
        requestConsent: (_) async => const SocialRegistrationConsent(
          relationship: 'father',
          displayName: 'Đỗ Đức',
        ),
      );
      expect(created, true);
      expect(exchanges, 1);
    },
  );

  test('cancel social profile leaves account and session uncreated', () async {
    var posts = 0;
    AuthService.instance = AuthService(
      socialIdentityProvider: (_, _) async => {'idToken': 'test-token'},
      client: MockClient((request) async {
        posts++;
        return jsonResponse({...ticket(), 'requiresProfile': true});
      }),
    );
    await expectLater(
      AuthService.instance.socialRegister(
        'google',
        acceptedTerms: false,
        requestConsent: (_) async => null,
      ),
      throwsA(
        isA<AuthException>().having((e) => e.code, 'code', 'SOCIAL_CANCELLED'),
      ),
    );
    expect(posts, 1);
    expect(AuthService.instance.signedIn, false);
  });
}
