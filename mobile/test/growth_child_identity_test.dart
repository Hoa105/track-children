import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/growth/api_growth_repository.dart';
import 'package:track_children/features/growth/growth_overview.dart';
import 'package:track_children/services/auth_service.dart';
import 'package:track_children/services/demo_store.dart';

const serverId = '00000000-0000-4000-8000-000000009901';

void main() {
  late String localId;
  late AuthService previousAuth;
  late MockClient client;
  final requests = <String>[];

  setUp(() async {
    requests.clear();
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
    final store = DemoStore.instance;
    await store.login(DemoStore.demoEmail, DemoStore.password);
    localId = await store.saveChild(null, {
      'full_name': 'Identity test',
      'date_of_birth': '2025-01-01',
      'gender': 'female',
    });
    final prefs = await SharedPreferences.getInstance();
    final data = jsonDecode(
      prefs.getString(DemoStore.storageKey)!,
    ) as Map<String, dynamic>;
    data['serverIds'] = {localId: serverId};
    await prefs.setString(DemoStore.storageKey, jsonEncode(data));
    DemoStore.resetInstanceForTesting();
    await DemoStore.instance.initialize();
    previousAuth = AuthService.instance;
    client = MockClient((request) async {
      requests.add(request.url.path);
      expect(
        request.url.path,
        startsWith('/api/v1/children/$serverId/growth/'),
      );
      return http.Response(
        jsonEncode({
          'meta': {'schemaVersion': '1'},
          'child': {
            'id': serverId,
            'dateOfBirth': '2025-01-01',
            'fullName': 'Identity test',
            'growthAccess': 'edit',
          },
          'measurements': [],
          'pairing': {'ready': false},
        }),
        200,
      );
    });
    AuthService.instance = AuthService(client: client);
    AuthService.instance.user = {'id': DemoStore.instance.parent['id']};
  });

  tearDown(() {
    AuthService.instance = previousAuth;
    client.close();
  });

  testWidgets(
    'mapped local profile loads an empty overview through server UUID',
    (tester) async {
      final repository = ApiGrowthRepository();
      expect(repository.remote.childId, serverId);
      expect(repository.remote.isCurrentContext, isTrue);
      await tester.pumpWidget(
        MaterialApp(home: GrowthOverview(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(
        requests.where((path) => path.endsWith('/tracking')),
        hasLength(1),
      );
      expect(
        requests.where((path) => path.contains('/assessment/')),
        hasLength(2),
      );
      expect(find.text('Chưa có số đo'), findsNWidgets(3));
      expect(find.text('Chưa tải được số đo.'), findsNothing);
      expect(repository.canEdit, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  test('changing selected child invalidates the old repository', () async {
    final repository = ApiGrowthRepository();
    await DemoStore.instance.selectChild('child_an');
    expect(repository.remote.isCurrentContext, isFalse);
    await expectLater(
      repository.refreshMeasurements(),
      throwsA(isA<AuthException>()),
    );
    expect(requests, isEmpty);
  });

  test('changing owner cannot resolve another account local profile', () async {
    final repository = ApiGrowthRepository();
    await DemoStore.instance.bindAuthenticatedUser({'id': 'another-owner'});
    expect(DemoStore.instance.serverChildId(localId), isNull);
    expect(repository.remote.isCurrentContext, isFalse);
    await expectLater(
      repository.refreshMeasurements(),
      throwsA(isA<AuthException>()),
    );
    expect(requests, isEmpty);
  });

  test('UUID server profiles retain their identity', () async {
    final store = DemoStore.instance;
    await store.bindAuthenticatedUser({'id': 'server-owner'});
    await store.cacheAuthenticatedChildren('server-owner', [
      {
        'id': serverId,
        'fullName': 'Server child',
        'dateOfBirth': '2025-01-01',
        'gender': 'female',
        'growthAccess': 'edit',
      },
    ]);
    expect(store.serverChildId(serverId), serverId);
    expect(ApiGrowthRepository().remote.childId, serverId);
  });
}
