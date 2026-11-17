import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/models/activity.dart';
import 'package:track_children/services/activity_api.dart';
import 'package:track_children/services/demo_store.dart';

const _massage = '7f0c7c1e-0000-5000-8000-000000000001';
const _kick = '7f0c7c1e-0000-5000-8000-000000000002';

/// Only registers profiles; vaccination calls are not used here.
class _Linker implements VaccinationRemote {
  @override
  Future<void> link(VaccinationAccount account) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// In-memory backend keyed by backend uuids.
class _FakeActivities implements ActivityRemote {
  final done = <String, Set<String>>{};
  final favorites = <String, Set<String>>{};
  bool offline = false;

  void _check() {
    if (offline) throw ApiException(0, 'offline');
  }

  @override
  Future<Set<String>> fetchDone(VaccinationAccount account) async {
    _check();
    return {...?done[account.childId]};
  }

  @override
  Future<void> setDone(
    VaccinationAccount account,
    String activityId,
    bool value,
  ) async {
    _check();
    final ids = done.putIfAbsent(account.childId, () => {});
    value ? ids.add(activityId) : ids.remove(activityId);
  }

  @override
  Future<Set<String>> fetchFavorites(VaccinationAccount account) async {
    _check();
    return {...?favorites[account.userId]};
  }

  @override
  Future<void> setFavorite(
    VaccinationAccount account,
    String activityId,
    bool value,
  ) async {
    _check();
    final ids = favorites.putIfAbsent(account.userId, () => {});
    value ? ids.add(activityId) : ids.remove(activityId);
  }
}

void main() {
  late _FakeActivities server;
  late String an, linh;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
    server = _FakeActivities();
    DemoStore.vaccinationRemote = _Linker();
    DemoStore.activityRemote = server;
    applyActivityCatalog([
      for (final id in [_massage, _kick])
        ChildActivity(id, 'g0', 'Trò $id', 0, 3, 0, remote: true),
    ]);
    await DemoStore.instance.login('demo@trackchildren.vn', DemoStore.password);
    an = DemoStore.instance.children.first['id'] as String;
    linh = DemoStore.instance.children.last['id'] as String;
  });

  tearDown(() {
    DemoStore.vaccinationRemote = null;
    DemoStore.activityRemote = null;
    activityCatalogState.value = bundledActivityCatalog;
  });

  test('library progress is saved per child on the backend', () async {
    final store = DemoStore.instance;
    await store.setActivityDone(an, _massage, true);

    expect(server.done.values.single, {_massage});
    expect(store.completedActivities(an), {_massage});
    expect(store.completedActivities(linh), isEmpty);
    // Lưu theo uuid của bé trên backend, không phải id trên máy.
    expect(server.done.keys.single, isNot(an));

    await store.setActivityDone(an, _massage, false);
    expect(server.done.values.single, isEmpty);
  });

  test('a failed save leaves the local state unchanged', () async {
    server.offline = true;
    await expectLater(
      DemoStore.instance.setActivityDone(an, _massage, true),
      throwsA(isA<ApiException>()),
    );
    expect(DemoStore.instance.completedActivities(an), isEmpty);
  });

  test('bundled ideas stay local', () async {
    final bundled = bundledActivityCatalog
        .firstWhere((a) => a.groupId == 'g4')
        .id;
    await DemoStore.instance.setActivityDone(an, bundled, true);
    await DemoStore.instance.setActivityFavorite(bundled, true);
    expect(server.done, isEmpty);
    expect(server.favorites, isEmpty);
    expect(DemoStore.instance.completedActivities(an), {bundled});
  });

  test('sync uploads local marks once, then follows the backend', () async {
    final store = DemoStore.instance;
    // Đánh dấu khi chưa bật đồng bộ: chỉ có trên máy.
    DemoStore.activityRemote = null;
    await store.setActivityDone(an, _massage, true);
    await store.setActivityFavorite(_kick, true);
    DemoStore.activityRemote = server;

    expect(await store.syncActivities(an), isTrue);
    expect(server.done.values.single, {_massage});
    expect(server.favorites.values.single, {_kick});

    // Bố bỏ đánh dấu trên máy khác: lần đồng bộ sau theo backend.
    server.done.values.single.clear();
    server.favorites.values.single.add(_massage);
    expect(await store.syncActivities(an), isTrue);
    expect(store.completedActivities(an), isEmpty);
    expect(store.favoriteActivities, {_kick, _massage});
  });

  test('offline sync keeps the cache', () async {
    await DemoStore.instance.setActivityDone(an, _massage, true);
    server.offline = true;
    expect(await DemoStore.instance.syncActivities(an), isFalse);
    expect(DemoStore.instance.completedActivities(an), {_massage});
  });
}
