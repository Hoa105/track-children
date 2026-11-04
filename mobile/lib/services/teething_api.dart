import '../models/tooth.dart';
import 'auth_service.dart';
import 'vaccination_remote.dart';

abstract class TeethingRemote {
  Future<Map<String, DateTime>> fetch(VaccinationAccount account);
  Future<void> save(
    VaccinationAccount account,
    String toothId,
    DateTime eruptedOn,
  );
  Future<void> remove(VaccinationAccount account, String toothId);
}

/// Authenticated REST client for the teething tracker.
class TeethingApi implements TeethingRemote {
  TeethingApi({AuthService? auth}) : _auth = auth ?? AuthService.instance;

  final AuthService _auth;

  String _path(VaccinationAccount account, [String? toothCode]) =>
      '/children/${account.childId}/teeth'
      '${toothCode == null ? '' : '/$toothCode'}';

  PrimaryTooth _tooth(String id) =>
      PrimaryTooth.all.firstWhere((tooth) => tooth.id == id);

  @override
  Future<Map<String, DateTime>> fetch(VaccinationAccount account) async {
    final body = await _auth.authorizedRequest('GET', _path(account));
    return {
      for (final record in (body['records'] as List).cast<Map>())
        PrimaryTooth.all
            .firstWhere(
              (tooth) => tooth.fdiCode == record['toothCode'] as String,
            )
            .id: DateTime.parse(
          record['eruptedOn'] as String,
        ),
    };
  }

  @override
  Future<void> save(
    VaccinationAccount account,
    String toothId,
    DateTime eruptedOn,
  ) async {
    await _auth.authorizedRequest(
      'PUT',
      _path(account, _tooth(toothId).fdiCode),
      body: {
        'eruptedOn': _day(eruptedOn),
        'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      },
    );
  }

  @override
  Future<void> remove(VaccinationAccount account, String toothId) async {
    await _auth.authorizedRequest(
      'DELETE',
      _path(account, _tooth(toothId).fdiCode),
    );
  }

  static String _day(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
