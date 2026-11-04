import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/services/auth_service.dart';
import 'package:track_children/services/teething_api.dart';
import 'package:track_children/services/vaccination_remote.dart';

class _FakeAuth extends AuthService {
  _FakeAuth() : super(demoMode: true);

  String? method;
  String? path;
  Map<String, dynamic>? requestBody;
  Map<String, dynamic> response = {};

  @override
  Future<Map<String, dynamic>> authorizedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    this.method = method;
    this.path = path;
    requestBody = body;
    return response;
  }
}

const _account = VaccinationAccount(
  userId: '00000000-0000-4000-8000-000000000001',
  childId: '00000000-0000-4000-8000-000000000101',
  parent: {},
  child: {},
);

void main() {
  test('teething API maps FDI records and authenticated operations', () async {
    final auth = _FakeAuth()
      ..response = {
        'records': [
          {'toothCode': '71', 'eruptedOn': '2026-08-12'},
        ],
      };
    final api = TeethingApi(auth: auth);

    final records = await api.fetch(_account);
    expect(records['lower-left-centralIncisor'], DateTime(2026, 8, 12));
    expect(auth.method, 'GET');
    expect(auth.path, '/children/${_account.childId}/teeth');

    await api.save(_account, 'upper-right-firstMolar', DateTime(2026, 10, 3));
    expect(auth.method, 'PUT');
    expect(auth.path, endsWith('/teeth/54'));
    expect(auth.requestBody?['eruptedOn'], '2026-10-03');
    expect(auth.requestBody?['timezoneOffsetMinutes'], isA<int>());

    await api.remove(_account, 'lower-left-centralIncisor');
    expect(auth.method, 'DELETE');
    expect(auth.path, endsWith('/teeth/71'));
  });
}
