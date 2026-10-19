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
        final docs = await auth.documents();
        final challenge = await auth.register({
          'fullName': 'Live Test Parent',
          'username': 'live_$nonce',
          'email': 'live_$nonce@example.com',
          'phone': '09${nonce.substring(nonce.length - 8)}',
          'password': 'LivePassword123!',
          'relationship': 'mother',
          'consents': [
            for (final d in docs.where((d) => d['isRequired'] == true))
              {'documentId': d['id'], 'isAccepted': true},
          ],
        });
        final sms = jsonDecode(
          await File('../.auth-test-logs/sms.json').readAsString(),
        ) as Map<String, dynamic>;
        expect(challenge['deliveryStatus'], 'sent');
        await auth.verify(challenge, sms['code'] as String);
        final user = await auth.currentUser();
        expect(user['email'], 'live_$nonce@example.com');
        expect(user['phoneVerifiedAt'], isNotNull);
        expect(user['emailVerifiedAt'], isNull);
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
