import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/services/api_config.dart';

void main() {
  test('host-only launch URLs receive exactly one versioned API prefix', () {
    expect(
      normalizeApiBaseUrl('http://127.0.0.1:8010'),
      'http://127.0.0.1:8010/api/v1',
    );
    expect(
      normalizeApiBaseUrl('http://127.0.0.1:8010/'),
      'http://127.0.0.1:8010/api/v1',
    );
    expect(
      normalizeApiBaseUrl('http://127.0.0.1:8010/api/v1/'),
      'http://127.0.0.1:8010/api/v1',
    );
    expect(
      normalizeApiBaseUrl('https://api.example.com/service/api/v1'),
      'https://api.example.com/service/api/v1',
    );
  });
}
