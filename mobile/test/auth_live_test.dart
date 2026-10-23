import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:track_children/services/auth_service.dart';

// Inherit the real IO client instead of the widget binding's fake HTTP override.
class _RealHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('live PostgreSQL auth smoke over real HTTP', () async {
    FlutterSecureStorage.setMockInitialValues({});
    await HttpOverrides.runWithHttpOverrides(() async {
      final client = IOClient(HttpClient());
      final auth = AuthService(client: client);
      try {
        final nonce = DateTime.now().microsecondsSinceEpoch.toString();
        await auth.documents();
        final challenge = await auth.register({
          'displayName': 'Live Test Parent',
          'email': 'live_$nonce@example.com',
          'password': 'LivePassword123!',
          'defaultRelationship': 'mother',
          'acceptedTerms': true,
        });
        final sms = jsonDecode(
          await File('../.auth-test-logs/sms.json').readAsString(),
        ) as Map<String, dynamic>;
        expect(challenge['deliveryStatus'], 'sent');
        await auth.verify(challenge, sms['code'] as String);
        final user = await auth.currentUser();
        expect(user['email'], 'live_$nonce@example.com');
        expect(user['emailVerifiedAt'], isNotNull);
        expect(user['phoneVerifiedAt'], isNull);
        await Future.wait([auth.refresh(), auth.refresh()]);
        expect((await auth.currentUser())['id'], user['id']);
        expect(await auth.logout(), isTrue);
        expect(auth.signedIn, isFalse);
        await expectLater(auth.currentUser(), throwsA(isA<AuthException>()));
      } finally {
        client.close();
      }
    }, _RealHttp());
  }, skip: !const bool.fromEnvironment('AUTH_LIVE_TEST'));
}
