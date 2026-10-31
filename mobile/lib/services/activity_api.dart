import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/activity.dart';
import 'api_config.dart';
import 'vaccination_remote.dart';

/// Backend storage for "Đã làm" (per child) and "Yêu thích" (per parent).
/// Only library activities (uuid ids) live there; bundled ideas stay local.
abstract class ActivityRemote {
  Future<Set<String>> fetchDone(VaccinationAccount account);
  Future<void> setDone(VaccinationAccount account, String activityId, bool done);
  Future<Set<String>> fetchFavorites(VaccinationAccount account);
  Future<void> setFavorite(
    VaccinationAccount account,
    String activityId,
    bool favorite,
  );
}

/// REST client for backend/app/features/activities/router.py. The library
/// itself needs no login; progress and favorites use the dev X-User-Id header
/// like [VaccinationApi].
class ActivityApi implements ActivityRemote {
  ActivityApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? apiBaseUrl;

  static ActivityApi instance = ActivityApi();

  final http.Client _client;
  final String _baseUrl;
  static const _timeout = Duration(seconds: 8);
  final _details = <String, ActivityDetail>{};

  /// Absolute url for a backend path such as `/static/activities/g001/main.jpg`.
  String imageUrl(String path) =>
      path.startsWith('http') ? path : '$_baseUrl$path';

  Future<dynamic> _get(String path) =>
      _send(_client.get(Uri.parse('$_baseUrl$path')));

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

  Map<String, String> _headers(VaccinationAccount account) => {
    'Content-Type': 'application/json',
    'X-User-Id': account.userId,
  };

  Uri _progress(VaccinationAccount account, [String? activityId]) => Uri.parse(
    '$_baseUrl/children/${account.childId}/activity-progress'
    '${activityId == null ? '' : '/${Uri.encodeComponent(activityId)}'}',
  );

  Uri _favorite([String? activityId]) => Uri.parse(
    '$_baseUrl/me/activity-favorites'
    '${activityId == null ? '' : '/${Uri.encodeComponent(activityId)}'}',
  );

  @override
  Future<Set<String>> fetchDone(VaccinationAccount account) async {
    final body = await _send(
      _client.get(_progress(account), headers: _headers(account)),
    );
    return {
      for (final p in (body as List).cast<Map<String, dynamic>>())
        if (p['status'] == 'done') p['activityId'] as String,
    };
  }

  @override
  Future<void> setDone(
    VaccinationAccount account,
    String activityId,
    bool done,
  ) => _send(
    _client.put(
      _progress(account, activityId),
      headers: _headers(account),
      body: jsonEncode({'done': done}),
    ),
  );

  @override
  Future<Set<String>> fetchFavorites(VaccinationAccount account) async {
    final body = await _send(
      _client.get(_favorite(), headers: _headers(account)),
    );
    return (body as List).cast<String>().toSet();
  }

  @override
  Future<void> setFavorite(
    VaccinationAccount account,
    String activityId,
    bool favorite,
  ) => _send(
    favorite
        ? _client.put(_favorite(activityId), headers: _headers(account))
        : _client.delete(_favorite(activityId), headers: _headers(account)),
  );

  /// Published activities, youngest first.
  Future<List<ChildActivity>> fetchCatalog() async {
    final body = await _get('/activities') as List;
    return [
      for (final a in body.cast<Map<String, dynamic>>())
        ChildActivity.fromJson(a),
    ];
  }

  /// Steps, photos and guide of one activity; cached for the session.
  Future<ActivityDetail> fetchDetail(String id) async =>
      _details[id] ??= ActivityDetail.fromJson(
        await _get('/activities/${Uri.encodeComponent(id)}')
            as Map<String, dynamic>,
      );
}
