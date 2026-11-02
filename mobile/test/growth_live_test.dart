import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/services/growth_api.dart';

void main() {
  test('live mobile HTTP session, child, growth update and deletion', () async {
    final api = GrowthApi();
    await api.login('growth-live@example.test', 'Growth-live-test-123');
    try {
      final child = await api.request('POST', '/children', {
        'fullName': 'Flutter live fixture',
        'dateOfBirth': '2026-02-17',
        'gender': 'female',
      });
      final path = '/children/${child['id']}/growth';
      final result = await api.request('PUT', '$path/days/2026-10-15', {
        'weightKg': 8.4,
        'height': {'value': 69.5, 'measurePosition': 'lying'},
      });
      expect(result['bmi']['value'], 17.39);
      await api.request('PUT', '$path/days/2026-10-15', {'weightKg': 9});
      final read = await api.request('GET', path);
      final rows = GrowthApi.recordsFromApi(read);
      expect(rows.single['v0'], 9);
      expect(rows.single['v1'], 69.5);
      await api.request('DELETE', '$path/measurements/${rows.single['id0']}');
      final after = await api.request('GET', path);
      expect(after['summary']['bmi'], isNull);
      await api.request('DELETE', '$path/measurements/${rows.single['id1']}');
    } finally {
      await api.logout();
    }
  }, skip: !const bool.fromEnvironment('GROWTH_LIVE_TEST'));
}
