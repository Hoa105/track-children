import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:track_children/features/growth/api_growth_repository.dart';
import 'package:track_children/features/growth/growth_repository.dart';
import 'package:track_children/features/growth/remote_growth_repository.dart';

void main() {
  test('original widgets repository reads seeded profiles and WHO references over HTTP', () async {
    final client = http.Client();
    addTearDown(client.close);
    const base = 'http://127.0.0.1:8000/api/v1';
    final login = await client.post(
      Uri.parse('$base/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': 'growth.parent@example.com',
        'password': 'BeLonKhon2026!',
        'rememberMe': false,
        'device': {'platform': 'web', 'deviceId': 'original-growth-ui-test'},
      }),
    );
    expect(login.statusCode, 200);
    final token = (jsonDecode(login.body) as Map)['accessToken'];
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final children = await client.get(
      Uri.parse('$base/children'),
      headers: headers,
    );
    expect(children.statusCode, 200);
    for (final child
        in (jsonDecode(children.body) as Map)['children'] as List) {
      final remote = RemoteGrowthRepository(
        child['id'] as String,
        transport: (method, path, {body}) async {
          final response = await client.get(
            Uri.parse('$base$path'),
            headers: headers,
          );
          expect(response.statusCode, 200);
          return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
        },
      );
      final repo = ApiGrowthRepository(remote: remote);
      expect(await repo.loadOverview(), hasLength(4));
      final weights = await repo.weightMeasurements();
      expect(weights, isNotEmpty);
      final reference = await repo.weightReference();
      expect(reference, isNotNull);
      expect(
        reference!.sex,
        child['gender'] == 'female'
            ? GrowthReferenceSex.girls
            : GrowthReferenceSex.boys,
      );
      expect(await repo.bmiMeasurements(), isNotEmpty);
      expect(
        repo.weightAssessmentFor(weights.last, null)?.wfa?.zScore,
        isNotNull,
      );
      expect(
        await repo.statureReference(
          weights.last.measuredAt.difference(repo.dateOfBirth!).inDays < 731,
        ),
        isNotNull,
      );
    }
  }, skip: !const bool.fromEnvironment('GROWTH_DEMO_LIVE_TEST'));
}
