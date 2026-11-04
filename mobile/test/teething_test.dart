import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/models/tooth.dart';
import 'package:track_children/services/demo_store.dart';
import 'package:track_children/services/teething_api.dart';
import 'package:track_children/features/teething/teething_screen.dart';
import 'package:track_children/features/teething/teething_age_selector.dart';
import 'package:track_children/features/teething/tooth_chart.dart';
import 'package:track_children/features/teething/teething_date_picker.dart';

class _DelayedTeethingRemote implements TeethingRemote {
  final records = <String, TeethingEntry>{};
  Completer<Map<String, TeethingEntry>>? pending;
  final started = Completer<void>();

  @override
  Future<Map<String, TeethingEntry>> fetch(VaccinationAccount account) {
    if (pending != null) {
      if (!started.isCompleted) started.complete();
      return pending!.future;
    }
    return Future.value(Map.of(records));
  }

  @override
  Future<void> save(
    VaccinationAccount account,
    String toothId,
    DateTime date, {
    String? note,
  }) async {
    records[toothId] = TeethingEntry(date: date, note: note ?? '');
  }

  @override
  Future<void> remove(VaccinationAccount account, String toothId) async {
    records.remove(toothId);
  }
}

void main() {
  for (final width in [320.0, 768.0]) {
    testWidgets('teething layout at $width with large text', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1000);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const TeethingScreen(childId: 'child_an'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Răng của bé'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final childTabScroll = find.descendant(
        of: find.byKey(const PageStorageKey('child-teething-tab')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('erupted-teeth-list-button')),
        200,
        scrollable: childTabScroll,
      );
      await tester.pumpAndSettle();
      expect(find.byType(ToothChartLegend), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Tìm hiểu thêm →'),
        200,
        scrollable: childTabScroll,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tìm hiểu thêm →'));
      await tester.pumpAndSettle();
      expect(find.text('Mẹo nhỏ cho ba mẹ'), findsOneWidget);
      await tester.tap(find.text('Tìm hiểu thêm →'));
      await tester.pumpAndSettle();
      expect(find.text('Kiến thức mọc răng'), findsOneWidget);
      await tester.tap(find.text('Dấu hiệu mọc răng là gì?'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Bé có thể chảy nhiều nước dãi, quấy hoặc khó ngủ khi mọc răng.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('erupted-teeth-list-button')),
        -200,
        scrollable: childTabScroll,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('erupted-teeth-list-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('erupted-teeth-list-button')));
      await tester.pumpAndSettle();
      expect(find.byType(ToothListScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
    await DemoStore.instance.login('demo@trackchildren.vn', DemoStore.password);
  });

  for (final remove in [false, true]) {
    test(
      'a delayed sync cannot overwrite a completed ${remove ? 'delete' : 'save'}',
      () async {
        final store = DemoStore.instance;
        final id = await store.saveChild(null, {
          'full_name': 'Sync race',
          'date_of_birth': '2025-01-01',
          'gender': 'male',
        });
        final remote = _DelayedTeethingRemote();
        DemoStore.teethingRemote = remote;
        addTearDown(() => DemoStore.teethingRemote = null);
        await store.syncTeeth(id);
        final tooth = PrimaryTooth.all.first.id;
        if (remove) {
          await store.saveTooth(id, tooth, DateTime.now(), note: 'Saved');
        }
        final oldRecords = Map<String, TeethingEntry>.of(remote.records);
        remote.pending = Completer<Map<String, TeethingEntry>>();
        final syncing = store.syncTeeth(id);
        await remote.started.future;
        if (remove) {
          await store.removeTooth(id, tooth);
        } else {
          await store.saveTooth(id, tooth, DateTime.now(), note: 'Saved');
        }
        remote.pending!.complete(oldRecords);
        expect(await syncing, isFalse);
        expect(store.teeth(id).containsKey(tooth), !remove);
        expect(store.toothNote(id, tooth), remove ? '' : 'Saved');
      },
    );
  }

  testWidgets('large text list opens editor and saves on narrow screen', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const ToothListScreen(childId: 'child_an'),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.byType(ListTile).first, 200);
    await tester.ensureVisible(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    expect(find.text('Sửa răng đã mọc'), findsOneWidget);
    expect(find.byType(ToothEditorScreen), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(
      find.byKey(const Key('save-tooth-button')).hitTestable(),
      findsOneWidget,
    );
    final savePosition = tester.getCenter(
      find.byKey(const Key('save-tooth-button')),
    );
    await tester.drag(
      find.descendant(
        of: find.byType(ToothEditorScreen),
        matching: find.byType(SingleChildScrollView),
      ),
      const Offset(0, -150),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(find.byKey(const Key('save-tooth-button'))),
      savePosition,
    );
    await tester.tap(find.byKey(const Key('save-tooth-button')));
    await tester.pumpAndSettle();
    expect(find.text('Sửa răng đã mọc'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'tooth updates persist, deduplicate and stay within family and child',
    () async {
      final store = DemoStore.instance;
      final id = PrimaryTooth.all.first.id;
      final other = store.teeth('child_linh');
      await store.saveTooth(
        'child_an',
        id,
        DateTime.now(),
        note: '  Chiếc răng đầu tiên  ',
      );
      expect(store.toothNote('child_an', id), 'Chiếc răng đầu tiên');
      final count = store.teeth('child_an').length;
      await store.saveTooth(
        'child_an',
        id,
        DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(store.teeth('child_an').length, count);
      expect(store.teeth('child_linh'), other);
      expect(
        () => store.saveTooth(
          'child_an',
          id,
          DateTime.now().add(const Duration(days: 1)),
        ),
        throwsArgumentError,
      );
      DemoStore.resetInstanceForTesting();
      await DemoStore.instance.initialize();
      expect(DemoStore.instance.teeth('child_an').length, count);
      expect(
        DemoStore.instance.toothNote('child_an', id),
        'Chiếc răng đầu tiên',
      );
      await DemoStore.instance.removeTooth('child_an', id);
      expect(DemoStore.instance.teeth('child_an').containsKey(id), isFalse);
      expect(DemoStore.instance.toothNote('child_an', id), isEmpty);
      await DemoStore.instance.login('bo@trackchildren.vn', DemoStore.password);
      expect(DemoStore.instance.teeth('child_an'), isEmpty);
      expect(
        () => DemoStore.instance.removeTooth('child_an', id),
        throwsStateError,
      );
    },
  );

  testWidgets(
    'reference tooth selection preserves the child tab and its age filter',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 1200);
      addTearDown(tester.view.reset);
      final store = DemoStore.instance;
      final id = await store.saveChild(null, {
        'full_name': 'Age filter',
        'date_of_birth': '2025-01-01',
        'gender': 'male',
      });
      await store.saveTooth(id, PrimaryTooth.all[0].id, DateTime(2025, 7, 1));
      await store.saveTooth(id, PrimaryTooth.all[1].id, DateTime(2026, 1, 1));
      await tester.pumpWidget(MaterialApp(home: TeethingScreen(childId: id)));
      await tester.pumpAndSettle();
      final ages = find.descendant(
        of: find.byKey(const Key('teething-age-selector')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('reference-age-6')),
        -150,
        scrollable: ages,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reference-age-6')));
      await tester.pumpAndSettle();
      final referenceTooth = PrimaryTooth.all.firstWhere(
        (tooth) => tooth.eruptionMonths.$1 == 6,
      );
      await tester.ensureVisible(
        find.byKey(Key('tooth-target-${referenceTooth.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('tooth-target-${referenceTooth.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Răng của bé'));
      await tester.pumpAndSettle();
      final currentSelector = tester.widget<TeethingAgeSelector>(
        find.byType(TeethingAgeSelector),
      );
      expect(currentSelector.month, currentSelector.currentMonth);
      expect(
        tester.widget<ToothChart>(find.byType(ToothChart)).eruptedIds,
        hasLength(2),
      );
      expect(find.text('Đã mọc 2/20 răng sữa'), findsOneWidget);

      // A month explicitly selected in the child tab still filters its history.
      await tester.scrollUntilVisible(
        find.byKey(const Key('reference-age-6')),
        -150,
        scrollable: ages,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reference-age-6')));
      await tester.pumpAndSettle();
      expect(tester.widget<ToothChart>(find.byType(ToothChart)).eruptedIds, {
        PrimaryTooth.all[0].id,
      });
      await tester.tap(find.text('Tham khảo'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TeethingAgeSelector>(find.byType(TeethingAgeSelector))
            .month,
        6,
      );
      final laterTooth = PrimaryTooth.all.firstWhere(
        (tooth) => tooth.eruptionMonths.$1 == 16,
      );
      await tester.ensureVisible(
        find.byKey(Key('tooth-target-${laterTooth.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('tooth-target-${laterTooth.id}')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TeethingAgeSelector>(find.byType(TeethingAgeSelector))
            .month,
        16,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('reference-age-60')),
        250,
        scrollable: ages,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reference-age-60')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Răng của bé'));
      await tester.pumpAndSettle();
      final selector = tester.widget<TeethingAgeSelector>(
        find.byType(TeethingAgeSelector),
      );
      expect(selector.month, 6);
      expect(selector.maxMonth, selector.currentMonth);
      expect(tester.widget<ToothChart>(find.byType(ToothChart)).eruptedIds, {
        PrimaryTooth.all[0].id,
      });
      expect(store.teeth(id), hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('record and remove tooth on a new child', (tester) async {
    final id = await DemoStore.instance.saveChild(null, {
      'full_name': 'Bé mới',
      'date_of_birth': '2025-01-01',
      'gender': 'male',
    });
    await tester.pumpWidget(MaterialApp(home: TeethingScreen(childId: id)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Răng của bé'));
    await tester.pumpAndSettle();
    expect(find.text('Đã mọc 0/20 răng sữa'), findsOneWidget);
    final ages = find.descendant(
      of: find.byKey(const Key('teething-age-selector')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('reference-age-0')),
      -150,
      scrollable: ages,
    );
    await tester.tap(find.byKey(const Key('reference-age-0')));
    await tester.pumpAndSettle();
    final target = PrimaryTooth.all.first;
    final chart = find.byType(TeethingScreen);
    expect(chart, findsOneWidget);
    await tester.tap(find.byTooltip(target.label).first);
    await tester.pumpAndSettle();
    expect(find.byType(TeethingDatePicker), findsNothing);
    await tester.tap(find.text('Đã mọc'));
    await tester.pumpAndSettle();
    expect(find.byType(TeethingDatePicker), findsOneWidget);
    expect(find.text('Đã ghi nhận mọc răng'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('tooth-note-field')));
    await tester.enterText(
      find.byKey(const Key('tooth-note-field')),
      'Bé đã mọc răng đầu tiên',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lưu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Đã mọc 1/20 răng sữa'), findsOneWidget);
    final selector = tester.widget<TeethingAgeSelector>(
      find.byType(TeethingAgeSelector),
    );
    expect(selector.month, selector.currentMonth);
    expect(
      DemoStore.instance.toothNote(id, target.id),
      'Bé đã mọc răng đầu tiên',
    );
    await tester.tap(find.byTooltip(target.label).first);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('tooth-note-field')))
          .controller!
          .text,
      'Bé đã mọc răng đầu tiên',
    );
    await tester.tap(find.text('Chưa mọc'));
    await tester.pumpAndSettle();
    expect(find.byType(TeethingDatePicker), findsNothing);
    await tester.ensureVisible(find.text('Lưu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Bỏ đánh dấu'));
    await tester.pumpAndSettle();
    expect(find.text('Đã mọc 0/20 răng sữa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('view-only caregiver can read but cannot open the tooth editor', (
    tester,
  ) async {
    final store = DemoStore.instance;
    final id = await store.saveChild(null, {
      'full_name': 'Bé được chia sẻ',
      'date_of_birth': '2025-01-01',
      'gender': 'female',
    });
    final tooth = PrimaryTooth.all.first;
    await store.saveTooth(id, tooth.id, DateTime.now());
    await store.saveChild(id, {
      'server': true,
      'growthAccess': 'none',
      'teethingAccess': 'view',
    });

    await tester.pumpWidget(MaterialApp(home: TeethingScreen(childId: id)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Răng của bé'));
    await tester.pumpAndSettle();

    expect(find.text('Đã mọc 1/20 răng sữa'), findsOneWidget);
    expect(
      tester.widget<ToothChart>(find.byType(ToothChart)).onToothTap,
      isNull,
    );
    await tester.tap(find.byKey(const Key('erupted-teeth-list-button')));
    await tester.pumpAndSettle();
    expect(find.byType(ToothEditorScreen), findsNothing);
    expect(
      tester.widget<ListTile>(find.byType(ListTile).last).onTap,
      isNull,
    );
  });

  test('view-only caregiver cannot bypass the UI to save a tooth', () async {
    final store = DemoStore.instance;
    final id = await store.saveChild(null, {
      'full_name': 'Bé chỉ được xem',
      'date_of_birth': '2025-01-01',
      'gender': 'female',
    });
    await store.saveChild(id, {
      'server': true,
      'growthAccess': 'none',
      'teethingAccess': 'view',
    });

    await expectLater(
      store.saveTooth(id, PrimaryTooth.all.first.id, DateTime.now()),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Bạn chỉ có quyền xem mục này',
        ),
      ),
    );
    expect(store.teeth(id), isEmpty);
  });

  testWidgets('caregiver without teething access cannot see child records', (
    tester,
  ) async {
    final store = DemoStore.instance;
    final id = await store.saveChild(null, {
      'full_name': 'Bé riêng tư',
      'date_of_birth': '2025-01-01',
      'gender': 'male',
    });
    await store.saveTooth(id, PrimaryTooth.all.first.id, DateTime.now());
    await store.saveChild(id, {
      'server': true,
      'growthAccess': 'none',
      'teethingAccess': 'none',
    });

    await tester.pumpWidget(MaterialApp(home: TeethingScreen(childId: id)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Răng của bé'));
    await tester.pumpAndSettle();

    expect(
      find.text('Bạn không có quyền xem dữ liệu mọc răng của bé.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('child-teething-summary')), findsNothing);
    expect(find.text('Đã mọc 1/20 răng sữa'), findsNothing);
  });
}
