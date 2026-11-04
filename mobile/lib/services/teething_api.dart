import '../models/tooth.dart';
import 'auth_service.dart';
import 'vaccination_remote.dart';

class TeethingConflictException implements Exception {}

enum TeethingSyncStatus {
  idle,
  loading,
  ready,
  offlineCache,
  noAccess,
  failed,
}

class TeethingEntry {
  const TeethingEntry({required this.date, this.note = ''});
  final DateTime date;
  final String note;
}

abstract class TeethingRemote {
  Future<Map<String, TeethingEntry>> fetch(VaccinationAccount account);
  Future<void> save(
    VaccinationAccount account,
    String toothId,
    DateTime eruptedOn, {
    String? note,
  });
  Future<void> remove(VaccinationAccount account, String toothId);
}

/// Authenticated REST client for the teething tracker.
class TeethingApi implements TeethingRemote {
  TeethingApi({AuthService? auth}) : _auth = auth ?? AuthService.instance;

  final AuthService _auth;
  final Map<String, Map<String, String>> _versions = {};
  final Map<String, int> _revisions = {};
  String _key(VaccinationAccount account) =>
      '${account.userId}/${account.childId}';

  String _path(VaccinationAccount account, [String? toothCode]) =>
      '/children/${account.childId}/teeth'
      '${toothCode == null ? '' : '/$toothCode'}';

  PrimaryTooth _tooth(String id) =>
      PrimaryTooth.all.firstWhere((tooth) => tooth.id == id);

  @override
  Future<Map<String, TeethingEntry>> fetch(VaccinationAccount account) async {
    final key = _key(account);
    final revision = _revisions[key] ?? 0;
    final body = await _auth.authorizedRequest('GET', _path(account));
    final rows = (body['records'] as List).cast<Map>();
    if ((_revisions[key] ?? 0) == revision) {
      _versions[key] = {
        for (final record in rows)
          record['toothCode'] as String: record['version'] as String,
      };
    }
    return {
      for (final record in rows)
        PrimaryTooth.all
            .firstWhere(
              (tooth) => tooth.fdiCode == record['toothCode'] as String,
            )
            .id: TeethingEntry(
          date: DateTime.parse(record['eruptedOn'] as String),
          note: record['note'] as String? ?? '',
        ),
    };
  }

  @override
  Future<void> save(
    VaccinationAccount account,
    String toothId,
    DateTime eruptedOn, {
    String? note,
  }) async {
    final code = _tooth(toothId).fdiCode;
    await _ensureSnapshot(account, code);
    try {
      final saved = await _auth.authorizedRequest(
        'PUT',
        _path(account, code),
        body: {
          'eruptedOn': _day(eruptedOn),
          'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
          'expectedVersion': _versions[_key(account)]![code],
          if (note != null) 'note': note.trim(),
        },
      );
      _versions[_key(account)]![code] = saved['version'] as String;
      _revisions[_key(account)] = (_revisions[_key(account)] ?? 0) + 1;
    } on AuthException catch (error) {
      if (error.code == 'HTTP_409') throw TeethingConflictException();
      rethrow;
    }
  }

  @override
  Future<void> remove(VaccinationAccount account, String toothId) async {
    final code = _tooth(toothId).fdiCode;
    await _ensureSnapshot(account, code);
    final version = _versions[_key(account)]![code];
    try {
      await _auth.authorizedRequest(
        'DELETE',
        '${_path(account, code)}${version == null ? '' : '?expectedVersion=$version'}',
      );
      _versions[_key(account)]!.remove(code);
      _revisions[_key(account)] = (_revisions[_key(account)] ?? 0) + 1;
    } on AuthException catch (error) {
      if (error.code == 'HTTP_409') throw TeethingConflictException();
      rethrow;
    }
  }

  Future<void> _ensureSnapshot(VaccinationAccount account, String code) async {
    if (_versions.containsKey(_key(account))) return;
    await fetch(account);
    // Local cached data may predate this API instance. An existing record must
    // be shown to the user before its newly fetched version can authorize edits.
    if (_versions[_key(account)]!.containsKey(code)) {
      throw TeethingConflictException();
    }
  }

  static String _day(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
