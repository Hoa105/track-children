import 'dart:async';

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
  AuthException? failure;
  Completer<Map<String, dynamic>>? pendingFetch;

  @override
  Future<Map<String, dynamic>> authorizedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    this.method = method;
    this.path = path;
    requestBody = body;
    if (failure != null) throw failure!;
    if (method == 'GET' && pendingFetch != null) return pendingFetch!.future;
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
  test(
    'a late fetch cannot reset the version returned by a successful save',
    () async {
      final auth = _FakeAuth()..response = {'records': []};
      final api = TeethingApi(auth: auth);
      await api.fetch(_account);
      auth.pendingFetch = Completer<Map<String, dynamic>>();
      final fetching = api.fetch(_account);
      auth.response = {'version': 'saved-version'};
      await api.save(
        _account,
        'lower-left-centralIncisor',
        DateTime(2026, 10, 3),
      );
      auth.pendingFetch!.complete({'records': []});
      await fetching;
      await api.save(
        _account,
        'lower-left-centralIncisor',
        DateTime(2026, 10, 4),
      );
      expect(auth.requestBody!['expectedVersion'], 'saved-version');
    },
  );

  test(
    'an unreviewed existing record cannot be overwritten on first save',
    () async {
      final auth = _FakeAuth()
        ..response = {
          'records': [
            {'toothCode': '71', 'eruptedOn': '2026-08-12', 'version': 'latest'},
          ],
        };
      final api = TeethingApi(auth: auth);
      await expectLater(
        api.save(_account, 'lower-left-centralIncisor', DateTime(2026, 10, 3)),
        throwsA(isA<TeethingConflictException>()),
      );
      expect(auth.method, 'GET');
    },
  );

  test(
    'conflicts are surfaced without retrying or advancing the version',
    () async {
      final auth = _FakeAuth()
        ..response = {
          'records': [
            {
              'toothCode': '71',
              'eruptedOn': '2026-08-12',
              'version': 'original',
            },
          ],
        };
      final api = TeethingApi(auth: auth);
      await api.fetch(_account);
      auth.failure = AuthException('HTTP_409', {});
      await expectLater(
        api.save(_account, 'lower-left-centralIncisor', DateTime(2026, 10, 3)),
        throwsA(isA<TeethingConflictException>()),
      );
      expect(auth.method, 'PUT');
      expect(auth.requestBody!['expectedVersion'], 'original');
      await expectLater(
        api.remove(_account, 'lower-left-centralIncisor'),
        throwsA(isA<TeethingConflictException>()),
      );
      expect(auth.path, endsWith('?expectedVersion=original'));
      auth.failure = AuthException('HTTP_500', {});
      await expectLater(
        api.remove(_account, 'lower-left-centralIncisor'),
        throwsA(isA<AuthException>()),
      );
    },
  );

  test('teething API maps FDI records and authenticated operations', () async {
    final auth = _FakeAuth()
      ..response = {
        'records': [
          {
            'toothCode': '71',
            'eruptedOn': '2026-08-12',
            'version': 'version-71',
            'note': 'Bé mọc chiếc răng đầu tiên',
          },
        ],
      };
    final api = TeethingApi(auth: auth);

    final records = await api.fetch(_account);
    expect(records['lower-left-centralIncisor']!.date, DateTime(2026, 8, 12));
    expect(
      records['lower-left-centralIncisor']!.note,
      'Bé mọc chiếc răng đầu tiên',
    );
    expect(auth.method, 'GET');
    expect(auth.path, '/children/${_account.childId}/teeth');

    auth.response = {'version': 'version-54'};
    await api.save(
      _account,
      'upper-right-firstMolar',
      DateTime(2026, 10, 3),
      note: '  Ghi chú mới  ',
    );
    expect(auth.method, 'PUT');
    expect(auth.path, endsWith('/teeth/54'));
    expect(auth.requestBody?['eruptedOn'], '2026-10-03');
    expect(auth.requestBody?['note'], 'Ghi chú mới');
    expect(auth.requestBody?['timezoneOffsetMinutes'], isA<int>());
    expect(auth.requestBody!.containsKey('expectedVersion'), isTrue);
    expect(auth.requestBody!['expectedVersion'], isNull);

    await api.save(_account, 'upper-right-firstMolar', DateTime(2026, 10, 4));
    expect(auth.requestBody!['expectedVersion'], 'version-54');

    await api.remove(_account, 'lower-left-centralIncisor');
    expect(auth.method, 'DELETE');
    expect(auth.path, endsWith('/teeth/71?expectedVersion=version-71'));
  });
}
