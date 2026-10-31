import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'journal_media.dart';
import 'vaccination_remote.dart';

/// Backend storage for a child's diary (implemented by JournalApi).
///
/// Entries use the DemoStore journal map shape (`id`, `date`, `note`, `mood`,
/// `domains`, `media`, `activityId`, `activityName`, `insight`); media items
/// as described in [JournalMediaFiles].
abstract class JournalRemote {
  Future<List<Map<String, dynamic>>> fetch(VaccinationAccount account);

  /// Adds or replaces the entry. Throws [ApiException] 410 when the entry was
  /// deleted (e.g. on another device).
  Future<void> save(VaccinationAccount account, Map<String, dynamic> entry);
  Future<void> remove(VaccinationAccount account, String entryId);

  /// Uploads the local file of a media item (`path`) after the entry is saved.
  Future<void> uploadMedia(
    VaccinationAccount account,
    String entryId,
    Map<String, dynamic> media,
  );

  /// A fresh download link: `(url, expiresAt)`.
  Future<(String, DateTime)> mediaUrl(
    VaccinationAccount account,
    String entryId,
    String mediaId,
  );
}

/// Domain labels shown on mobile ↔ criteria.developmental_domains.code.
const journalDomainCodes = {
  'Vận động thô': 'gross_motor',
  'Vận động tinh': 'fine_motor',
  'Ngôn ngữ': 'language',
  'Nhận thức': 'cognitive',
  'Xã hội – Cảm xúc': 'social_emotional',
};

/// REST client for backend/app/features/diary/router.py. Uses the dev
/// X-User-Id header like [VaccinationApi].
class JournalApi implements JournalRemote {
  JournalApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;
  static const _timeout = Duration(seconds: 10);
  // Video tới 150 MB qua mạng di động
  static const _uploadTimeout = Duration(minutes: 10);

  Map<String, String> _headers(VaccinationAccount account) => {
    'Content-Type': 'application/json',
    'X-User-Id': account.userId,
  };

  Uri _uri(VaccinationAccount account, [String? entryId]) => Uri.parse(
    '$_baseUrl/children/${account.childId}/diary/entries'
    '${entryId == null ? '' : '/${Uri.encodeComponent(entryId)}'}',
  );

  Future<dynamic> _send(
    Future<http.Response> request, [
    Duration timeout = _timeout,
  ]) async {
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
  Future<List<Map<String, dynamic>>> fetch(VaccinationAccount account) async {
    final body = await _send(
      _client.get(_uri(account), headers: _headers(account)),
    );
    final labels = {for (final e in journalDomainCodes.entries) e.value: e.key};
    return [
      for (final e in (body as List).cast<Map<String, dynamic>>())
        {
          'id': e['id'],
          'date': e['date'],
          'note': e['note'],
          'mood': e['mood'],
          'domains': [
            for (final code in e['domains'] as List? ?? []) ?labels[code],
          ],
          'media': [
            for (final m in (e['media'] as List? ?? []).cast<Map>())
              {
                'id': m['id'],
                'type': m['type'],
                'uploaded': true,
                'url': m['url'],
                'expiresAt': m['expiresAt'],
              },
          ],
          'activityId': e['activityId'],
          'activityName': e['activityName'],
          'insight': e['insight'],
        }..removeWhere((_, value) => value == null),
    ];
  }

  @override
  Future<void> save(VaccinationAccount account, Map<String, dynamic> entry) =>
      _send(
        _client.put(
          _uri(account, entry['id'] as String),
          headers: _headers(account),
          body: jsonEncode({
            'date': entry['date'],
            'note': entry['note'] ?? '',
            'mood': entry['mood'],
            'domains': [
              for (final label in entry['domains'] as List? ?? [])
                ?journalDomainCodes[label],
            ],
            'media': [
              for (final m in (entry['media'] as List? ?? []).cast<Map>())
                if (m['rejected'] == null) {'id': m['id'], 'type': m['type']},
            ],
            'activityId': entry['activityId'],
            'activityName': entry['activityName'],
            'insight': entry['insight'],
          }),
        ),
      );

  @override
  Future<void> remove(VaccinationAccount account, String entryId) =>
      _send(_client.delete(_uri(account, entryId), headers: _headers(account)));

  @override
  Future<void> uploadMedia(
    VaccinationAccount account,
    String entryId,
    Map<String, dynamic> media,
  ) async {
    final request =
        http.MultipartRequest(
            'PUT',
            Uri.parse('${_uri(account, entryId)}/media/${media['id']}'),
          )
          ..headers['X-User-Id'] = account.userId
          ..files.add(
            await http.MultipartFile.fromPath('file', media['path'] as String),
          );
    await _send(
      _client.send(request).then(http.Response.fromStream),
      _uploadTimeout,
    );
  }

  @override
  Future<(String, DateTime)> mediaUrl(
    VaccinationAccount account,
    String entryId,
    String mediaId,
  ) async {
    final body = await _send(
      _client.get(
        Uri.parse('${_uri(account, entryId)}/media/$mediaId/url'),
        headers: _headers(account),
      ),
    );
    return (body['url'] as String, DateTime.parse(body['expiresAt'] as String));
  }
}
