import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/teething/teething_screen.dart';
import 'package:track_children/models/tooth.dart';
import 'package:track_children/services/auth_service.dart';
import 'package:track_children/services/demo_store.dart';
import 'package:track_children/services/teething_api.dart';

const ownerA = '00000000-0000-4000-8000-000000000001';
const ownerB = '00000000-0000-4000-8000-000000000002';
const childId = '00000000-0000-4000-8000-000000000101';
final birthday = DateTime(2025, 1, 1);
final toothId = PrimaryTooth.all.first.id;

class ControlledRemote implements TeethingRemote {
  final records = <String, TeethingEntry>{};
  int saves = 0, deletes = 0, fetches = 0;
  Object? saveFailure, deleteFailure, fetchFailure;
  Completer<void>? saveGate, fetchGate;
  final fetchStarted = Completer<void>();
  final saveStarted = Completer<void>();

  @override
  Future<Map<String, TeethingEntry>> fetch(VaccinationAccount account) async {
    fetches++;
    final snapshot = Map<String, TeethingEntry>.of(records);
    if (!fetchStarted.isCompleted) fetchStarted.complete();
    await fetchGate?.future;
    if (fetchFailure != null) throw fetchFailure!;
    return snapshot;
  }

  @override
  Future<void> save(
    VaccinationAccount account,
    String toothId,
    DateTime date, {
    String? note,
  }) async {
    saves++;
    if (!saveStarted.isCompleted) saveStarted.complete();
    await saveGate?.future;
    if (saveFailure != null) throw saveFailure!;
    records[toothId] = TeethingEntry(date: date, note: note ?? '');
  }

  @override
  Future<void> remove(VaccinationAccount account, String toothId) async {
    deletes++;
    if (deleteFailure != null) throw deleteFailure!;
    records.remove(toothId);
  }
}

Future<void> bindOwner(String owner, {String access = 'edit'}) async {
  final store = DemoStore.instance;
  await store.bindAuthenticatedUser({
    'id': owner,
    'displayName': 'Test parent',
  });
  await store.cacheAuthenticatedChildren(owner, [
    {
      'id': childId,
      'fullName': 'Test child',
      'dateOfBirth': '2025-01-01',
      'gender': 'female',
      'growthAccess': 'none',
      'teethingAccess': access,
    },
  ]);
}

Future<void> openEditor(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ToothEditorScreen(
                  childId: childId,
                  tooth: PrimaryTooth.all.first,
                ),
              ),
            ),
            child: const Text('Open editor'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DemoStore.teethingRemote = null;
    DemoStore.resetInstanceForTesting();
    await bindOwner(ownerA);
  });
  tearDown(() => DemoStore.teethingRemote = null);

  test(
    '[TC-TEETH-01] twenty FDI records stay independent and persist after CRUD',
    () async {
      final store = DemoStore.instance;
      for (final tooth in PrimaryTooth.all) {
        await store.saveTooth(childId, tooth.id, birthday, note: tooth.fdiCode);
      }
      expect(store.teeth(childId), hasLength(20));
      final otherTooth = PrimaryTooth.all[1];
      await store.saveTooth(
        childId,
        toothId,
        birthday.add(const Duration(days: 1)),
        note: 'Updated',
      );
      expect(store.teeth(childId), hasLength(20));
      expect(store.toothNote(childId, otherTooth.id), otherTooth.fdiCode);
      await store.removeTooth(childId, toothId);
      DemoStore.resetInstanceForTesting();
      await DemoStore.instance.initialize();
      expect(DemoStore.instance.teeth(childId), hasLength(19));
      expect(DemoStore.instance.teeth(childId), isNot(contains(toothId)));
      expect(
        DemoStore.instance.toothNote(childId, otherTooth.id),
        otherTooth.fdiCode,
      );
    },
  );

  test(
    '[TC-TEETH-02] invalid date and tooth never reach remote or change cache',
    () async {
      final remote = ControlledRemote();
      DemoStore.teethingRemote = remote;
      final store = DemoStore.instance;
      await expectLater(
        store.saveTooth(
          childId,
          toothId,
          birthday.subtract(const Duration(days: 1)),
        ),
        throwsArgumentError,
      );
      await expectLater(
        store.saveTooth(
          childId,
          toothId,
          DateTime.now().add(const Duration(days: 2)),
        ),
        throwsArgumentError,
      );
      await expectLater(
        store.saveTooth(childId, 'invalid-tooth', birthday),
        throwsArgumentError,
      );
      expect(remote.saves, 0);
      expect(store.teeth(childId), isEmpty);
      DemoStore.teethingRemote = null;
      await store.saveTooth(childId, toothId, birthday);
      await store.saveTooth(childId, toothId, DateTime.now());
      expect(store.teeth(childId), hasLength(1));
    },
  );

  test('[TC-TEETH-03] Unicode note boundary is 1000 characters and rejects atomically', () async {
    final store = DemoStore.instance;
    final accepted = List.filled(1000, '😀').join();
    await store.saveTooth(childId, toothId, birthday, note: '  $accepted  ');
    expect(store.toothNote(childId, toothId), accepted);
    await expectLater(
      store.saveTooth(childId, toothId, birthday, note: '${accepted}x'),
      throwsArgumentError,
    );
    expect(store.toothNote(childId, toothId), accepted);
    await store.saveTooth(childId, toothId, birthday, note: '');
    expect(store.toothNote(childId, toothId), '');
  });

  test(
    '[TC-TEETH-04] view and none permissions deny writes before API calls',
    () async {
      final remote = ControlledRemote();
      DemoStore.teethingRemote = remote;
      for (final access in ['view', 'none']) {
        await bindOwner(ownerA, access: access);
        await expectLater(
          DemoStore.instance.saveTooth(childId, toothId, birthday),
          throwsStateError,
        );
        await expectLater(
          DemoStore.instance.removeTooth(childId, toothId),
          throwsStateError,
        );
      }
      expect(remote.saves, 0);
      expect(remote.deletes, 0);
    },
  );

  test(
    '[TC-TEETH-05] failed remote save preserves the previous record',
    () async {
      final store = DemoStore.instance;
      await store.saveTooth(childId, toothId, birthday, note: 'Original');
      DemoStore.teethingRemote = ControlledRemote()
        ..saveFailure = AuthException('NETWORK_ERROR', {});
      await expectLater(
        store.saveTooth(
          childId,
          toothId,
          birthday.add(const Duration(days: 1)),
          note: 'New',
        ),
        throwsA(isA<AuthException>()),
      );
      expect(store.teeth(childId)[toothId], birthday);
      expect(store.toothNote(childId, toothId), 'Original');
    },
  );

  test(
    '[TC-TEETH-06] failed remote delete preserves the record and note',
    () async {
      final store = DemoStore.instance;
      await store.saveTooth(childId, toothId, birthday, note: 'Original');
      DemoStore.teethingRemote = ControlledRemote()
        ..deleteFailure = AuthException('HTTP_503', {});
      await expectLater(
        store.removeTooth(childId, toothId),
        throwsA(isA<AuthException>()),
      );
      expect(store.teeth(childId)[toothId], birthday);
      expect(store.toothNote(childId, toothId), 'Original');
    },
  );

  test('[TC-TEETH-07] offline sync retains readable cache and reports offline state', () async {
    final store = DemoStore.instance;
    await store.saveTooth(childId, toothId, birthday, note: 'Cached');
    for (final code in ['NETWORK_ERROR', 'HTTP_503']) {
      DemoStore.teethingRemote = ControlledRemote()
        ..fetchFailure = AuthException(code, {});
      expect(await store.syncTeeth(childId), isFalse);
      expect(
        store.teethingSyncStatus(childId),
        TeethingSyncStatus.offlineCache,
      );
      expect(store.toothNote(childId, toothId), 'Cached');
    }
  });

  test(
    '[TC-TEETH-08] revoked access from server clears cache and disables access',
    () async {
      final store = DemoStore.instance;
      await store.saveTooth(childId, toothId, birthday);
      DemoStore.teethingRemote = ControlledRemote()
        ..fetchFailure = AuthException('HTTP_404', {});
      expect(await store.syncTeeth(childId), isFalse);
      expect(store.teethingSyncStatus(childId), TeethingSyncStatus.noAccess);
      expect(store.canViewTeething(childId), isFalse);
      expect(store.teeth(childId), isEmpty);
    },
  );

  test(
    '[TC-TEETH-09] a fetch completing after permission revocation cannot apply',
    () async {
      final remote = ControlledRemote()..fetchGate = Completer<void>();
      remote.records[toothId] = TeethingEntry(date: birthday, note: 'Stale');
      DemoStore.teethingRemote = remote;
      final store = DemoStore.instance;
      final syncing = store.syncTeeth(childId);
      await remote.fetchStarted.future;
      await bindOwner(ownerA, access: 'none');
      remote.fetchGate!.complete();
      expect(await syncing, isFalse);
      expect(store.teeth(childId), isEmpty);
      expect(store.teethingSyncStatus(childId), TeethingSyncStatus.noAccess);
    },
  );

  test(
    '[TC-TEETH-10] stale fetch cannot cross accounts sharing the same child ID',
    () async {
      final remote = ControlledRemote()..fetchGate = Completer<void>();
      remote.records[toothId] = TeethingEntry(
        date: birthday,
        note: 'Account A',
      );
      DemoStore.teethingRemote = remote;
      final store = DemoStore.instance;
      final syncing = store.syncTeeth(childId);
      await remote.fetchStarted.future;
      await bindOwner(ownerB);
      remote.fetchGate!.complete();
      expect(await syncing, isFalse);
      expect(store.teeth(childId), isEmpty);
      expect(store.parent['id'], ownerB);
    },
  );

  test('[TC-TEETH-11] shared child ID writes and deletes only the active owner cache', () async {
    final store = DemoStore.instance;
    await store.saveTooth(childId, toothId, birthday, note: 'Account A');
    await bindOwner(ownerB);
    await store.saveTooth(
      childId,
      toothId,
      birthday.add(const Duration(days: 1)),
      note: 'Account B',
    );
    expect(store.toothNote(childId, toothId), 'Account B');
    await store.removeTooth(childId, toothId);
    expect(store.teeth(childId), isEmpty);
    await store.bindAuthenticatedUser({
      'id': ownerA,
      'displayName': 'Test parent A',
    });
    expect(store.toothNote(childId, toothId), 'Account A');
  });

  test(
    '[TC-TEETH-12] permission revoked during save prevents a local commit',
    () async {
      final remote = ControlledRemote()..saveGate = Completer<void>();
      DemoStore.teethingRemote = remote;
      final store = DemoStore.instance;
      final saving = store.saveTooth(childId, toothId, birthday);
      // _account resolves through the serialized preferences queue.
      await remote.saveStarted.future.timeout(const Duration(seconds: 5));
      await bindOwner(ownerA, access: 'view');
      final rejected = expectLater(saving, throwsStateError);
      remote.saveGate!.complete();
      await rejected;
      expect(store.teeth(childId), isEmpty);
    },
  );

  testWidgets('[TC-TEETH-13] rapid double save sends only one write', (
    tester,
  ) async {
    await DemoStore.instance.saveTooth(childId, toothId, birthday);
    final remote = ControlledRemote()..saveGate = Completer<void>();
    DemoStore.teethingRemote = remote;
    await openEditor(tester);
    final save = find.byKey(const Key('save-tooth-button'));
    await tester.tap(save);
    await tester.tap(save);
    await tester.pump();
    final calls = remote.saves;
    remote.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(ToothEditorScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '[TC-TEETH-14] rapid delete confirmation stays single and cancel preserves data',
    (tester) async {
      await DemoStore.instance.saveTooth(
        childId,
        toothId,
        birthday,
        note: 'Keep',
      );
      final remote = ControlledRemote();
      DemoStore.teethingRemote = remote;
      await openEditor(tester);
      await tester.ensureVisible(find.byKey(const Key('tooth-status-false')));
      await tester.tap(find.byKey(const Key('tooth-status-false')));
      await tester.pumpAndSettle();
      final save = find.byKey(const Key('save-tooth-button'));
      // Simulate callbacks already queued before the dialog blocks hit testing.
      final activate = tester.widget<FilledButton>(save).onPressed!;
      activate();
      activate();
      await tester.pumpAndSettle();
      final dialogs = find.byType(AlertDialog).evaluate().length;
      for (var i = 0; i < dialogs; i++) {
        await tester.tap(find.text('Hủy').last);
        await tester.pumpAndSettle();
      }
      expect(dialogs, 1);
      expect(remote.deletes, 0);
      expect(DemoStore.instance.toothNote(childId, toothId), 'Keep');
      expect(find.byType(ToothEditorScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
