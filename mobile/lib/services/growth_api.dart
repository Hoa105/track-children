import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class GrowthApiException implements Exception {
  GrowthApiException(this.code);
  final String code;
  @override
  String toString() =>
      'Không thực hiện được yêu cầu ($code). Vui lòng thử lại.';
}

/// Tokens stay in memory. Never persist credentials in the demo preference store.
class GrowthApi {
  GrowthApi({http.Client? client}) : _client = client ?? http.Client();
  static GrowthApi instance = GrowthApi();
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );
  final http.Client _client;
  String? _access, _refresh;
  int _generation = 0;
  Future<void>? _refreshing;
  Map<String, dynamic>? user;
  bool get signedIn => user != null;

  Future<Map<String, dynamic>> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
    bool retry = true,
  ]) async {
    final generation = _generation;
    try {
      final req = http.Request(method, Uri.parse('$baseUrl$path'));
      req.headers.addAll({
        'Content-Type': 'application/json',
        if (_access != null) 'Authorization': 'Bearer $_access',
      });
      if (body != null) req.body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await _client.send(req).timeout(const Duration(seconds: 20)),
      ).timeout(const Duration(seconds: 20));
      if (generation != _generation) {
        throw GrowthApiException('SESSION_CHANGED');
      }
      final result = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        final code =
            (result['error'] as Map?)?['code'] as String? ??
            'HTTP_${response.statusCode}';
        if (code == 'ACCESS_TOKEN_EXPIRED' && retry && _refresh != null) {
          await (_refreshing ??= _renew().whenComplete(
            () => _refreshing = null,
          ));
          if (generation != _generation) {
            throw GrowthApiException('SESSION_CHANGED');
          }
          return await request(method, path, body, false);
        }
        throw GrowthApiException(code);
      }
      return result;
    } on GrowthApiException {
      rethrow;
    } catch (_) {
      throw GrowthApiException('NETWORK_ERROR');
    }
  }

  Future<void> _renew() async {
    final result = await request('POST', '/auth/refresh', {
      'refreshToken': _refresh,
    }, false);
    _access = result['accessToken'] as String;
    _refresh = result['refreshToken'] as String;
  }

  Future<void> login(String email, String password) async {
    clear();
    final result = await request('POST', '/auth/login', {
      'email': email.trim(),
      'password': password,
    }, false);
    _access = result['accessToken'] as String;
    _refresh = result['refreshToken'] as String;
    user = Map<String, dynamic>.from(result['user'] as Map);
  }

  void clear() {
    _generation++;
    user = null;
    _access = null;
    _refresh = null;
  }

  Future<void> logout() async {
    final raw = _refresh;
    // Clear immediately, so in-flight responses cannot cross account boundaries.
    clear();
    if (raw != null) {
      await request('POST', '/auth/logout', {'refreshToken': raw}, false);
    }
  }

  static Map<String, dynamic> childFromApi(
    Map<String, dynamic> c,
    String owner,
  ) => {
    'id': c['id'],
    'parentId': owner,
    'full_name': c['fullName'],
    'date_of_birth': c['dateOfBirth'],
    'gender': c['gender'],
    'growthAccess': c['growthAccess'],
    'records': <Map<String, dynamic>>[],
    'server': true,
    'members': [],
    'pending': [],
  };

  static List<Map<String, dynamic>> recordsFromApi(
    Map<String, dynamic> result,
  ) => [
    for (final day in result['days'] as List)
      {
        'date': '${day['measuredAt']}T00:00:00.000',
        'bmi': (day['bmi'] as Map?)?['value'],
        for (final m in day['measurements'] as List)
          'v${metricIndex(m['metric'] as String)}': m['value'],
        for (final m in day['measurements'] as List)
          'id${metricIndex(m['metric'] as String)}': m['id'],
        for (final m in day['measurements'] as List)
          if (m['metric'] == 'height') 'measurePosition': m['measurePosition'],
      },
  ];

  static int metricIndex(String metric) =>
      ['weight', 'height', 'head_circumference'].indexOf(metric);

  static Map<String, dynamic> dayPayload(Map<String, dynamic> record) => {
    if (record['v0'] != null) 'weightKg': record['v0'],
    if (record['v1'] != null)
      'height': {
        'value': record['v1'],
        'measurePosition': record['measurePosition'],
      },
    if (record['v2'] != null) 'headCircumferenceCm': record['v2'],
  };
}
