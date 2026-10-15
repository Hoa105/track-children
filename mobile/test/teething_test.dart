import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/models/tooth.dart';
import 'package:track_children/services/demo_store.dart';
import 'package:track_children/features/teething/teething_screen.dart';

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
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Mẹo nhỏ cho ba mẹ'), 200);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Tìm hiểu thêm →'), 150);
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
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();
      expect(find.text('Kiến thức mọc răng'), findsNothing);
    });
  }
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
    await DemoStore.instance.login('demo@trackchildren.vn', DemoStore.password);
  });

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
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Lưu'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Lưu'));
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
      await store.saveTooth('child_an', id, DateTime.now());
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
      await DemoStore.instance.removeTooth('child_an', id);
      expect(DemoStore.instance.teeth('child_an').containsKey(id), isFalse);
      await DemoStore.instance.login('bo@trackchildren.vn', DemoStore.password);
      expect(DemoStore.instance.teeth('child_an'), isEmpty);
      expect(
        () => DemoStore.instance.removeTooth('child_an', id),
        throwsStateError,
      );
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
    expect(find.text('Đã mọc 0/20 răng sữa'), findsOneWidget);
    final target = PrimaryTooth.all.first;
    final chart = find.byType(TeethingScreen);
    expect(chart, findsOneWidget);
    await tester.tap(find.byTooltip(target.label).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Đã mọc 1/20 răng sữa'), findsOneWidget);
    await tester.tap(find.byTooltip(target.label).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ đánh dấu'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Bỏ đánh dấu'));
    await tester.pumpAndSettle();
    expect(find.text('Đã mọc 0/20 răng sữa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
