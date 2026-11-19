import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:track_children/services/auth_service.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final provider in ['google', 'apple']) {
    test(
      '$provider recovery proves linked identity without creating session',
      () async {
        final paths = <String>[];
        final service = AuthService(
          socialIdentityProvider: (name, nonce) async {
            expect(name, provider);
            expect(nonce, provider == 'apple' ? 'fresh-nonce' : null);
            return {
              'idToken': 'fresh-proof',
              if (provider == 'apple') 'authorizationCode': 'one-use',
            };
          },
          client: MockClient((request) async {
            paths.add(request.url.path);
            if (request.url.path.endsWith('/challenge')) {
              return http.Response(
                jsonEncode({
                  'nonce': 'fresh-nonce',
                  'challenge': 'fresh-challenge',
                }),
                200,
              );
            }
            final body = jsonDecode(request.body);
            expect(body['transactionId'], 'root');
            expect(body['provider'], provider);
            expect(body['idToken'], 'fresh-proof');
            if (provider == 'apple') {
              expect(body['authorizationCode'], 'one-use');
              expect(body['challenge'], 'fresh-challenge');
            }
            return http.Response('{"verified":true}', 200);
          }),
        );
        await service.verifyRecoveryProvider({
          'transactionId': 'root',
          'transactionToken': 'secret',
        }, provider);
        expect(service.signedIn, false);
        expect(paths, [
          if (provider == 'apple') '/api/v1/auth/social/apple/challenge',
          '/api/v1/auth/v2/recovery/provider',
        ]);
      },
    );
  }
}
