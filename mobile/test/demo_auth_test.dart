import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/services/auth_service.dart';
import 'package:track_children/services/demo_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
    await DemoStore.instance.initialize();
  });

  AuthService service() => AuthService(
    demoMode: true,
    client: MockClient((_) => throw StateError('Demo must not call HTTP')),
  );

  test('demo login exposes seeded children and isolates families', () async {
    final auth = service();
    expect(await auth.restore(), isFalse);
    await auth.login('demo@trackchildren.vn', 'TreXanh123');
    await DemoStore.instance.bindAuthenticatedUser(auth.user!);
    expect(DemoStore.instance.children.length, 2);
    expect(auth.user!.containsKey('password'), isFalse);
    expect(auth.user!['relationship'], 'mother');
    expect(await auth.logout(), isTrue);
    expect(auth.signedIn, isFalse);
    await auth.login('bo@trackchildren.vn', 'TreXanh123');
    expect(DemoStore.instance.children.single['id'], 'child_minh');
    await expectLater(
      auth.login('bo@trackchildren.vn', 'wrong'),
      throwsA(isA<AuthException>()),
    );
  });

  test('demo signup verifies local OTP without contacting backend', () async {
    final auth = service();
    expect(await auth.documents(), isNotEmpty);
    final challenge = await auth.register({
      'fullName': 'Test Parent',
      'email': 'new@example.test',
      'password': 'TreXanh123',
      'relationship': 'father',
    });
    await expectLater(
      auth.verify(challenge, '000000'),
      throwsA(isA<AuthException>()),
    );
    await auth.verify(await auth.resend(challenge), '123456');
    expect(auth.user!['email'], 'new@example.test');
    expect(DemoStore.instance.children, isEmpty);
    await auth.logout();
    await auth.login('new@example.test', 'TreXanh123');
    expect(auth.signedIn, isTrue);
  });
}
