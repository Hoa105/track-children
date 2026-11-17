import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/progress_review.dart';
import 'api_config.dart';
import 'authorized_client.dart';
import 'vaccination_remote.dart';

/// Abstraction over [ProgressReviewApi] so screens can be tested without HTTP.
abstract class ProgressReviewRemote {
  /// Summarises the analysed videos [insightIds] (≥ 2, same activity group).
  /// The backend returns the previous review when the set is unchanged.
  Future<ProgressReview> create(
    VaccinationAccount account,
    List<String> insightIds,
  );

  /// Newest first; [activityRef] limits to one activity.
  Future<List<ProgressReview>> list(
    VaccinationAccount account, {
    String? activityRef,
  });
}

/// REST client for backend/app/features/diary_ai/router.py (progress reviews).
class ProgressReviewApi implements ProgressReviewRemote {
  ProgressReviewApi({http.Client? client, String? baseUrl})
    : _client = client ?? AuthorizedClient(),
      _baseUrl = baseUrl ?? rootApiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  Uri _uri(VaccinationAccount account, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl/children/${account.childId}/diary/progress-reviews')
          .replace(queryParameters: query);

  Future<Object?> _decode(
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
    return body;
  }

  @override
  Future<ProgressReview> create(
    VaccinationAccount account,
    List<String> insightIds,
  ) async {
    final body = await _decode(
      _client.post(
        _uri(account),
        headers: {
          'Content-Type': 'application/json',
          'X-User-Id': account.userId,
        },
        body: jsonEncode({'insightIds': insightIds}),
      ),
      // AI đọc lại các nhận xét (chỉ văn bản) trong lúc chờ
      const Duration(minutes: 2),
    );
    return ProgressReview.fromJson(body as Map<String, dynamic>);
  }

  @override
  Future<List<ProgressReview>> list(
    VaccinationAccount account, {
    String? activityRef,
  }) async {
    final body = await _decode(
      _client.get(
        _uri(
          account,
          activityRef == null ? null : {'activityRef': activityRef},
        ),
        headers: {'X-User-Id': account.userId},
      ),
      const Duration(seconds: 8),
    );
    return [
      for (final r in body as List? ?? const [])
        ProgressReview.fromJson(r as Map<String, dynamic>),
    ];
  }
}
