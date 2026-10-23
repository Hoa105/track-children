import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/services/demo_store.dart';
import 'package:track_children/services/vaccination_api.dart';

const _anServerId = '00000000-0000-4000-8000-000000000101';

/// In-memory backend keyed by backend uuids.
class _FakeRemote implements VaccinationRemote {
  final server = <String, List<Map<String, dynamic>>>{};
  final serverPlans = <String, Map<String, bool>>{};
  final linked = <String, VaccinationAccount>{};
  bool offline = false;

  /// Record ids the backend refuses (422), e.g. a dose removed from the schedule.
  final rejectedIds = <String>{};

  void _check() {
    if (offline) throw ApiException(0, 'offline');
  }

  @override
  Future<void> link(VaccinationAccount account) async {
    _check();
    linked[account.childId] = account;
  }

  @override
  Future<List<Map<String, dynamic>>> fetch(VaccinationAccount account) async {
    _check();
    return [...?server[account.childId]];
  }

  @override
  Future<void> save(
    VaccinationAccount account,
    List<Map<String, dynamic>> records,
  ) async {
    _check();
    if (records.any((r) => rejectedIds.contains(r['id']))) {
      throw ApiException(422, 'Mũi không có trong lịch tiêm');
    }
    final list = server.putIfAbsent(account.childId, () => []);
    final ids = records.map((r) => r['id']).toSet();
    list
      ..removeWhere((r) => ids.contains(r['id']))
      ..addAll(records);
  }

  @override
  Future<void> remove(VaccinationAccount account, String doseId) async {
    _check();
    server[account.childId]?.removeWhere((r) => r['id'] == doseId);
  }

  @override
  Future<Map<String, bool>> fetchPlans(VaccinationAccount account) async {
    _check();
    return {...?serverPlans[account.childId]};
  }

  @override
  Future<void> savePlans(
    VaccinationAccount account,
    Map<String, bool?> plans,
  ) async {
    _check();
    final saved = serverPlans.putIfAbsent(account.childId, () => {});
    plans.forEach((k, v) => v == null ? saved.remove(k) : saved[k] = v);
  }
}

void main() {
  late _FakeRemote remote;
  final yesterday = DateTime.now().subtract(const Duration(days: 1));
  final day = DateTime(yesterday.year, yesterday.month, yesterday.day);
  Map<String, dynamic> custom(String id, {bool given = false}) => {
    'id': id,
    'custom': true,
    'name': 'viemb',
    'given': given,
    'date': day.toIso8601String(),
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
    remote = _FakeRemote();
    DemoStore.vaccinationRemote = remote;
    await DemoStore.instance.login('demo@trackchildren.vn', DemoStore.password);
  });

  tearDown(() => DemoStore.vaccinationRemote = null);

  test('saves and removes on the backend before the local cache', () async {
    final store = DemoStore.instance;
    await store.saveVaccination('child_an', {
      'id': 'bcg',
      'given': true,
      'date': day.toIso8601String(),
    });
    expect(remote.server[_anServerId]!.single['id'], 'bcg');
    expect(store.vaccinations('child_an').single['id'], 'bcg');

    remote.offline = true;
    await expectLater(
      store.removeVaccination('child_an', 'bcg'),
      throwsA(isA<ApiException>()),
    );
    expect(store.vaccinations('child_an'), hasLength(1));

    remote.offline = false;
    await store.saveVaccinePlans('child_an', {'dengue': false});
    expect(remote.serverPlans[_anServerId], {'dengue': false});
    await store.saveVaccinePlans('child_an', {'dengue': null});
    expect(store.vaccinePlans('child_an'), isEmpty);
    await store.removeVaccination('child_an', 'bcg');
    expect(remote.server[_anServerId], isEmpty);
    expect(store.vaccinations('child_an'), isEmpty);
  });

  test('sync replaces the cache, keeps it when offline', () async {
    final store = DemoStore.instance;
    expect(await store.syncVaccinations('child_an'), isTrue); // lần đầu
    remote.server[_anServerId] = [
      {'id': 'hepb-0', 'given': true, 'date': day.toIso8601String()},
    ];
    remote.serverPlans[_anServerId] = {'6in1': true, '5in1': false};
    expect(await store.syncVaccinations('child_an'), isTrue);
    expect(store.vaccinations('child_an').single['id'], 'hepb-0');
    expect(store.vaccinePlans('child_an'), {'6in1': true, '5in1': false});

    remote.offline = true;
    expect(await store.syncVaccinations('child_an'), isFalse);
    expect(store.vaccinations('child_an').single['id'], 'hepb-0');
  });

  test('a child created on the device is registered and its local doses '
      'uploaded on the first sync', () async {
    final store = DemoStore.instance;
    final childId = await store.saveChild(null, {
      'full_name': 'Bé mới',
      'gender': 'female',
      'date_of_birth': DateTime(2026, 1, 5).toIso8601String(),
    });
    // Saved while the backend was not configured: only on the device
    DemoStore.vaccinationRemote = null;
    await store.saveVaccinations(childId, [
      custom('custom-1-0'),
      custom('custom-old-0', given: true),
    ]);
    DemoStore.vaccinationRemote = remote;
    remote.rejectedIds.add('custom-old-0');

    expect(await store.syncVaccinations(childId), isTrue);
    final account = remote.linked.values.single;
    expect(account.child['full_name'], 'Bé mới');
    expect(account.parent['email'], 'demo@trackchildren.vn');
    expect(account.userId, '00000000-0000-4000-8000-000000000001');
    expect(account.childId, isNot(childId)); // uuid riêng cho backend
    expect(remote.server[account.childId]!.single['id'], 'custom-1-0');
    // Bị backend từ chối: vẫn giữ trên máy
    expect(
      store.vaccinations(childId).map((r) => r['id']),
      containsAll(['custom-1-0', 'custom-old-0']),
    );

    // Uuid ổn định; lần sau đồng bộ thì backend là bản chuẩn
    remote.server[account.childId]!.clear();
    expect(await store.syncVaccinations(childId), isTrue);
    expect(remote.linked.keys.single, account.childId);
    expect(store.vaccinations(childId).map((r) => r['id']), ['custom-old-0']);
  });

  test('VaccinationApi registers the profile once, then sends dates as '
      'yyyy-mm-dd with the user id', () async {
    final sent = <http.Request>[];
    final api = VaccinationApi(
      baseUrl: 'http://api.test',
      client: MockClient((request) async {
        sent.add(request);
        return http.Response(request.method == 'PUT' ? '' : '[]', 200);
      }),
    );
    final account = VaccinationAccount(
      userId: 'u-1',
      childId: 'c-1',
      parent: {'email': 'me@example.test', 'fullName': 'Mẹ'},
      child: {
        'full_name': 'Bé',
        'gender': 'male',
        'date_of_birth': DateTime(2026, 2, 3).toIso8601String(),
      },
    );
    await api.link(account);
    await api.link(account); // không gửi lại khi hồ sơ không đổi
    await api.save(account, [
      {
        'id': 'bcg',
        'given': true,
        'date': DateTime(2026, 3, 1).toIso8601String(),
      },
    ]);
    expect(sent.map((r) => '${r.method} ${r.url.path}'), [
      'PUT /dev/profiles',
      'PUT /children/c-1/vaccinations',
    ]);
    final profile = jsonDecode(sent.first.body) as Map;
    expect(profile['child'], {
      'id': 'c-1',
      'fullName': 'Bé',
      'dateOfBirth': '2026-02-03',
      'gender': 'male',
    });
    expect(sent.last.headers['X-User-Id'], 'u-1');
    final record = (jsonDecode(sent.last.body)['records'] as List).single;
    expect(record['date'], '2026-03-01');
    expect(record['custom'], isFalse);
  });

  test('VaccinationApi surfaces the backend error message', () async {
    final api = VaccinationApi(
      baseUrl: 'http://api.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'detail': 'Ngày tiêm không hợp lệ: bcg'}),
          422,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    const account = VaccinationAccount(
      userId: 'u',
      childId: 'c',
      parent: {},
      child: {},
    );
    await expectLater(
      api.remove(account, 'bcg'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', 'Ngày tiêm không hợp lệ: bcg')
            .having((e) => e.rejected, 'rejected', isTrue),
      ),
    );
  });
}
