import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/services/demo_store.dart';
import 'package:track_children/services/growth_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
  });

  test('server profiles replace local selection without uploading demo measurements', () async {
    final writes = <String>[];
    var value = 8.4;
    final child = {
      'id': 'server-child',
      'fullName': 'Same name',
      'dateOfBirth': '2026-02-17',
      'gender': 'male',
      'growthAccess': 'edit',
    };
    GrowthApi.instance = GrowthApi(
      client: MockClient((r) async {
        if (r.method != 'GET') writes.add(r.url.path);
        if (r.url.path.endsWith('/login')) {
          return http.Response(
            jsonEncode({
              'accessToken': 'access',
              'refreshToken': 'raw',
              'user': {
                'id': 'server-owner',
                'fullName': 'Parent',
                'email': 'server@example.test',
              },
            }),
            200,
          );
        }
        if (r.url.path.endsWith('/logout')) return http.Response('', 204);
        if (r.url.path.endsWith('/children')) {
          return http.Response(
            jsonEncode({
              'children': [child],
            }),
            200,
          );
        }
        if (r.method == 'PUT') {
          final body = jsonDecode(r.body) as Map;
          expect(body, {'weightKg': 9});
          value = 9;
          return http.Response('{}', 200);
        }
        return http.Response(
          jsonEncode({
            'child': child,
            'days': [
              {
                'measuredAt': '2026-10-15',
                'measurements': [
                  {'metric': 'weight', 'value': value, 'id': 'weight-id'},
                ],
              },
            ],
          }),
          200,
        );
      }),
    );
    final store = DemoStore.instance;
    await store.login('server@example.test', 'secret', useServer: true);
    expect(store.children.map((c) => c['id']), ['server-child']);
    expect(store.parent['fullName'], 'Parent');
    expect(writes, ['/api/v1/auth/login']);
    await store.selectChild('server-child');
    expect(store.latest('server-child', 0), 8.4);
    await store.addRecord('server-child', {
      'date': '2026-10-15T00:00:00.000',
      'v0': 9,
    });
    expect(store.latest('server-child', 0), 9);
    expect(store.records('server-child').length, 1);
    await store.logout();
    expect(store.children, isEmpty);
    expect(GrowthApi.instance.signedIn, false);
    await store.login('demo@trackchildren.vn', DemoStore.password);
    expect(store.children.any((c) => c['id'] == 'server-child'), false);
  });

  test('failed remote save never appends to local records', () async {
    final store = DemoStore.instance;
    await store.login('demo@trackchildren.vn', DemoStore.password);
    await store.selectChild('child_an');
    final before = store.records('child_an');
    GrowthApi.instance = GrowthApi(
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) {
          return http.Response(
            jsonEncode({
              'accessToken': 'access',
              'refreshToken': 'raw',
              'user': {'id': 'owner'},
            }),
            200,
          );
        }
        return http.Response('{"error":{"code":"DATABASE_UNAVAILABLE"}}', 503);
      }),
    );
    await GrowthApi.instance.login('server@example.test', 'secret');
    await expectLater(
      store.addRecord('child_an', {'date': '2026-10-15', 'v0': 9}),
      throwsA(isA<GrowthApiException>()),
    );
    expect(store.records('child_an'), before);
    GrowthApi.instance.clear();
  });
}
