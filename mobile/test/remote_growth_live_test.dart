import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:track_children/features/growth/remote_growth_repository.dart';

void main() {
  test('HTTP Flutter repository → FastAPI → PostgreSQL → R anthro', () async {
    final client = http.Client();
    addTearDown(client.close);
    final repository = RemoteGrowthRepository(
      '00000000-0000-4000-8000-000000009901',
      transport: (method, path, {body}) async {
        final request = http.Request(
          method,
          Uri.parse('http://127.0.0.1:8009/api/v1$path'),
        );
        request.headers['Content-Type'] = 'application/json';
        if (body != null) request.body = jsonEncode(body);
        final response = await http.Response.fromStream(
          await client.send(request),
        );
        expect(response.statusCode, lessThan(400), reason: response.body);
        return response.body.isEmpty
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      },
    );
    final saved = await repository.save('2026-01-01', {
      'weightKg': 9.5,
      'height': {'value': 75, 'measurePosition': 'lying'},
      'headCircumferenceCm': 46,
    });
    expect(
      saved
          .list('assessments')
          .firstWhere((a) => a['indicator'] == 'wfa')['zScore'],
      .49,
    );
    final detail = await repository.detail('bmi');
    expect(
      (detail.list('samples').single['value'] as num).toDouble(),
      closeTo(16.8888888889, .00001),
    );
    final height = saved
        .list('measurements')
        .singleWhere((m) => m['metric'] == 'height');
    await repository.delete(height['id'] as String);
    expect((await repository.day('2026-01-01')).data['bmi'], isNull);
  }, skip: !const bool.fromEnvironment('GROWTH_LIVE_TEST'));
}
