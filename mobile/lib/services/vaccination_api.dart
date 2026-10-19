import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/vaccination.dart';
import 'api_config.dart';
import 'vaccination_remote.dart';

export 'vaccination_remote.dart';

/// REST client for backend/app/features/vaccination/router.py.
///
/// Records use the same map shape as [DemoStore.vaccinations]; the only
/// difference on the wire is `date`, sent as `yyyy-mm-dd`.
class VaccinationApi implements VaccinationRemote {
  VaccinationApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;
  static const _timeout = Duration(seconds: 8);

  /// Profiles already registered this session (child uuid → profile snapshot).
  final _linked = <String, String>{};

  Map<String, String> _headers(VaccinationAccount account) => {
    'Content-Type': 'application/json',
    // Dev-only identity until the backend has real login (DEV_AUTH=true).
    'X-User-Id': account.userId,
  };

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<dynamic> _send(Future<http.Response> request) async {
    final http.Response response;
    try {
      response = await request.timeout(_timeout);
    } on Exception catch (e) {
      throw ApiException(0, 'Không kết nối được máy chủ ($e)');
    }
    final body = response.body.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 400) {
      final detail = body is Map ? body['detail'] : null;
      throw ApiException(
        response.statusCode,
        detail is String ? detail : 'HTTP ${response.statusCode}',
      );
    }
    return body;
  }

  /// Danh mục + lịch tiêm đang áp dụng (admin quản lý trên web).
  Future<VaccineCatalog> fetchSchedule() async {
    final body = await _send(_client.get(_uri('/vaccines/schedule')));
    return VaccineCatalog.fromJson(body as Map<String, dynamic>);
  }

  /// Registers the parent + child (dev: PUT /dev/profiles) so tài khoản / bé
  /// tạo trên máy cũng có trên backend. Sent again when name / dob changes.
  @override
  Future<void> link(VaccinationAccount account) async {
    final dob = DateTime.parse(account.child['date_of_birth'] as String);
    final profile = {
      'parent': {
        'id': account.userId,
        'email': account.parent['email'],
        'fullName': account.parent['fullName'] ?? account.parent['email'],
      },
      'child': {
        'id': account.childId,
        'fullName': account.child['full_name'],
        'dateOfBirth': _day(dob),
        'gender': account.child['gender'],
      },
    };
    final snapshot = jsonEncode(profile);
    if (_linked[account.childId] == snapshot) return;
    await _send(
      _client.put(
        _uri('/dev/profiles'),
        headers: _headers(account),
        body: snapshot,
      ),
    );
    _linked[account.childId] = snapshot;
  }

  String _child(VaccinationAccount account, String path) =>
      '/children/${account.childId}$path';

  @override
  Future<List<Map<String, dynamic>>> fetch(VaccinationAccount account) async {
    final body = await _send(
      _client.get(
        _uri(_child(account, '/vaccinations')),
        headers: _headers(account),
      ),
    );
    return [
      for (final r in (body as List).cast<Map<String, dynamic>>())
        {
          ...r,
          'date': DateTime.parse(r['date'] as String).toIso8601String(),
          if (r['scheduledDate'] != null)
            'scheduledDate': DateTime.parse(r['scheduledDate'] as String)
                .toIso8601String(),
        }..removeWhere((key, value) => value == null),
    ];
  }

  @override
  Future<void> save(
    VaccinationAccount account,
    List<Map<String, dynamic>> records,
  ) async {
    await _send(
      _client.put(
        _uri(_child(account, '/vaccinations')),
        headers: _headers(account),
        body: jsonEncode({'records': records.map(toWire).toList()}),
      ),
    );
  }

  @override
  Future<void> remove(VaccinationAccount account, String doseId) async {
    await _send(
      _client.delete(
        _uri(_child(account, '/vaccinations/${Uri.encodeComponent(doseId)}')),
        headers: _headers(account),
      ),
    );
  }

  @override
  Future<Map<String, bool>> fetchPlans(VaccinationAccount account) async {
    final body = await _send(
      _client.get(
        _uri(_child(account, '/vaccine-plans')),
        headers: _headers(account),
      ),
    );
    return (body as Map).cast<String, bool>();
  }

  @override
  Future<void> savePlans(
    VaccinationAccount account,
    Map<String, bool?> plans,
  ) async {
    await _send(
      _client.put(
        _uri(_child(account, '/vaccine-plans')),
        headers: _headers(account),
        body: jsonEncode({'plans': plans}),
      ),
    );
  }

  static String _day(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static Map<String, dynamic> toWire(Map<String, dynamic> record) => {
    'id': record['id'],
    'custom': record['custom'] == true,
    if (record['groupId'] != null) 'groupId': record['groupId'],
    if (record['name'] != null) 'name': record['name'],
    if (record['prevents'] != null) 'prevents': record['prevents'],
    if (record['doseLabel'] != null) 'doseLabel': record['doseLabel'],
    if (record['product'] != null) 'product': record['product'],
    'given': record['given'] == true,
    'date': _day(DateTime.parse(record['date'] as String)),
    if (record['scheduledDate'] != null)
      'scheduledDate': _day(DateTime.parse(record['scheduledDate'] as String)),
    if (record['appointmentPlace'] != null)
      'appointmentPlace': record['appointmentPlace'],
    'place': record['place'] ?? '',
    'reaction': record['reaction'] ?? '',
    'note': record['note'] ?? '',
  };
}
