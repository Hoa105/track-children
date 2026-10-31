import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/activity.dart';
import '../models/video_insight.dart';
import 'api_config.dart';
import 'vaccination_remote.dart';

/// AI group codes used by the backend (backend/app/features/diary_ai/criteria.py).
const activityAiGroups = <String, String>{
  'g0': 'gross_motor',
  'g1': 'fine_motor',
  'g2': 'language',
  'g3': 'cognitive_social',
  'g4': 'music',
  'g5': 'storytelling',
};

/// Abstraction over [VideoInsightApi] so screens can be tested without HTTP.
abstract class VideoInsightRemote {
  Future<VideoInsight> submit(
    VaccinationAccount account, {
    required List<int> video,
    required String filename,
    required ChildActivity activity,
    required List<(String, String)> guide,
    required String note,
  });

  Future<VideoInsight> fetch(VaccinationAccount account, String insightId);
}

/// REST client for backend/app/features/diary_ai/router.py.
class VideoInsightApi implements VideoInsightRemote {
  VideoInsightApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  Uri _uri(VaccinationAccount account, [String suffix = '']) => Uri.parse(
    '$_baseUrl/children/${account.childId}/diary/video-insights$suffix',
  );

  Future<VideoInsight> _decode(
    Future<http.Response> request,
    Duration timeout,
  ) async {
    final http.Response response;
    try {
      response = await request.timeout(timeout);
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
    return VideoInsight.fromJson(body as Map<String, dynamic>);
  }

  @override
  Future<VideoInsight> submit(
    VaccinationAccount account, {
    required List<int> video,
    required String filename,
    required ChildActivity activity,
    required List<(String, String)> guide,
    required String note,
  }) {
    final request = http.MultipartRequest('POST', _uri(account))
      // Dev-only identity until the backend has real login (DEV_AUTH=true).
      ..headers['X-User-Id'] = account.userId
      ..fields['consent'] = 'true'
      ..fields['note'] = note
      ..fields['activity'] = jsonEncode({
        'id': activity.id,
        'title': activity.name,
        'group': activityAiGroups[activity.groupId],
        'ageFromMonths': activity.minMonths,
        'ageToMonths': activity.maxMonths,
        'guide': [
          for (final (title, text) in guide) {'title': title, 'text': text},
        ],
      })
      ..files.add(
        http.MultipartFile.fromBytes('video', video, filename: filename),
      );
    return _decode(
      _client.send(request).then(http.Response.fromStream),
      const Duration(minutes: 3),
    );
  }

  @override
  Future<VideoInsight> fetch(VaccinationAccount account, String insightId) =>
      _decode(
        _client.get(
          _uri(account, '/$insightId'),
          headers: {'X-User-Id': account.userId},
        ),
        const Duration(seconds: 8),
      );
}
