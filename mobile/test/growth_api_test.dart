import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:track_children/services/growth_api.dart';

void main() {
  test('maps day records without pairing measurements on different dates', () {
    final rows = GrowthApi.recordsFromApi({
      'days': [
        {
          'measuredAt': '2026-10-15',
          'measurements': [
            {'metric': 'weight', 'value': 8.4, 'id': 'weight-id'},
          ],
        },
        {
          'measuredAt': '2026-10-16',
          'measurements': [
            {
              'metric': 'height',
              'value': 69.5,
              'id': 'height-id',
              'measurePosition': 'lying',
            },
          ],
        },
      ],
    });
    expect(rows[0]['v1'], isNull);
    expect(rows[1]['v0'], isNull);
    expect(rows[0]['id0'], 'weight-id');
    expect(rows[1]['measurePosition'], 'lying');
    expect(GrowthApi.dayPayload(rows[1]), {
      'height': {'value': 69.5, 'measurePosition': 'lying'},
    });
  });

  test(
    'PUT and DELETE use bearer auth; partial payload preserves omitted metrics',
    () async {
      final requests = <http.Request>[];
      final api = GrowthApi(
        client: MockClient((r) async {
          requests.add(r);
          if (r.url.path.endsWith('/login')) {
            return http.Response(
              jsonEncode({
                'accessToken': 'access',
                'refreshToken': 'refresh',
                'user': {'id': 'owner'},
              }),
              200,
            );
          }
          return http.Response('{}', r.method == 'DELETE' ? 204 : 200);
        }),
      );
      await api.login('owner@example.test', 'secret');
      await api.request(
        'PUT',
        '/children/c/growth/days/2026-10-15',
        GrowthApi.dayPayload({'v0': 8.4}),
      );
      await api.request('DELETE', '/children/c/growth/measurements/m');
      expect(requests[1].headers['Authorization'], 'Bearer access');
      expect(jsonDecode(requests[1].body), {'weightKg': 8.4});
      expect(requests[2].method, 'DELETE');
    },
  );

  test('expired access refreshes only once for parallel requests', () async {
    var refreshes = 0;
    final api = GrowthApi(
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) {
          return http.Response(
            jsonEncode({
              'accessToken': 'old',
              'refreshToken': 'raw',
              'user': {'id': 'owner'},
            }),
            200,
          );
        }
        if (r.url.path.endsWith('/refresh')) {
          refreshes++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return http.Response(
            '{"accessToken":"new","refreshToken":"rotated"}',
            200,
          );
        }
        return r.headers['Authorization'] == 'Bearer old'
            ? http.Response('{"error":{"code":"ACCESS_TOKEN_EXPIRED"}}', 401)
            : http.Response('{"days":[]}', 200);
      }),
    );
    await api.login('owner@example.test', 'secret');
    await Future.wait([
      api.request('GET', '/children'),
      api.request('GET', '/children'),
    ]);
    expect(refreshes, 1);
  });

  test('logout discards responses from previous account', () async {
    final pending = Completer<http.Response>();
    final api = GrowthApi(client: MockClient((_) => pending.future));
    final request = api.request('GET', '/children');
    final check = expectLater(request, throwsA(isA<GrowthApiException>()));
    api.clear();
    pending.complete(http.Response('{"children":[]}', 200));
    await check;
  });

  test('API errors remain actionable and do not turn into success', () async {
    final api = GrowthApi(
      client: MockClient(
        (_) async =>
            http.Response('{"error":{"code":"GROWTH_WRITE_FORBIDDEN"}}', 403),
      ),
    );
    await expectLater(
      api.request('PUT', '/children/c/growth/days/d', {'weightKg': 8}),
      throwsA(
        isA<GrowthApiException>().having(
          (e) => e.code,
          'code',
          'GROWTH_WRITE_FORBIDDEN',
        ),
      ),
    );
  });
}
