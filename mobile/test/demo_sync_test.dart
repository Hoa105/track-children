import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/services/demo_store.dart';
import 'package:track_children/features/home/home_screen.dart';
import 'package:track_children/features/growth/growth_screen.dart';
import 'package:track_children/features/settings/settings_screen.dart';
import 'package:track_children/features/child/child_profile_selection_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
  });

  test(
    'login, child selection, rename, measurements and restart use stable IDs',
    () async {
      final store = DemoStore(today: DateTime(2026, 10, 15));
      expect(await store.login('demo@trackchildren.vn', 'wrong'), false);
      expect(
        await store.login('demo@trackchildren.vn', DemoStore.password),
        true,
      );
      expect(store.parent['email'], 'demo@trackchildren.vn');
      expect(store.children.map((c) => c['id']), ['child_an', 'child_linh']);
      await store.selectChild('child_an');
      final count = store.records('child_an').length;
      await store.saveChild('child_an', {
        'full_name': 'Bảo An đã sửa',
        'gender': 'female',
        'date_of_birth': '2026-02-15',
      });
      await store.addRecord('child_an', {
        'date': '2026-10-16T00:00:00.000',
        'v0': 8.8,
        'v1': 70.0,
        'v2': 44.0,
      });
      expect(store.child!['full_name'], 'Bảo An đã sửa');
      expect(store.records('child_an').length, count + 1);
      expect(store.latest('child_an', 0), 8.8);
      expect(store.latest('child_linh', 0), 12.5);
      final restored = DemoStore();
      await restored.initialize();
      expect(restored.parent['email'], store.parent['email']);
      expect(restored.child, store.child);
      expect(restored.records('child_an'), store.records('child_an'));
      await restored.logout();
      expect(
        await restored.login('bo@trackchildren.vn', DemoStore.password),
        true,
      );
      expect(restored.children.map((c) => c['id']), ['child_minh']);
      expect(() => restored.selectChild('child_an'), throwsStateError);
      expect(restored.records('child_an'), isEmpty);
      expect(
        () => restored.addRecord('child_an', {'v0': 99}),
        throwsStateError,
      );
    },
  );

  test('account edits, password, settings and sharing persist without crossing children', () async {
    final store = DemoStore();
    await store.login('demo@trackchildren.vn', DemoStore.password);
    await store.selectChild('child_an');
    await store.saveParent({
      'fullName': 'Mẹ Hoa đã sửa',
      'email': 'hoa.changed@example.test',
      'password': 'Changed123',
      'notifications': false,
    });
    final other = store.childById('child_linh');
    await store.saveSharing('child_an', [], ['Lời mời · test@example.test']);
    expect(store.childById('child_linh'), other);
    final restored = DemoStore();
    await restored.initialize();
    expect(restored.parent['fullName'], 'Mẹ Hoa đã sửa');
    expect(restored.parent['notifications'], false);
    expect(restored.childById('child_an')!['pending'], [
      'Lời mời · test@example.test',
    ]);
    await restored.logout();
    expect(
      await restored.login('demo@trackchildren.vn', DemoStore.password),
      false,
    );
    expect(
      await restored.login('hoa.changed@example.test', 'Changed123'),
      true,
    );
    final snapshot = restored.parent;
    await expectLater(
      restored.saveParent({'email': 'bo@trackchildren.vn'}),
      throwsStateError,
    );
    expect(restored.parent, snapshot);
  });

  test(
    'registration, new empty child, concurrent writes and fixture reset',
    () async {
      final store = DemoStore();
      await store.initialize();
      await store.register({
        'fullName': 'Test Parent',
        'username': 'test',
        'email': 'new@example.test',
        'phone': '0900000003',
        'role': 'guardian',
        'password': 'Test1234',
      });
      expect(store.children, isEmpty);
      final id = await store.saveChild(null, {
        'full_name': 'Bé mới',
        'gender': 'female',
        'date_of_birth': '2026-09-15',
      });
      expect(store.records(id), isEmpty);
      await Future.wait([
        store.addRecord(id, {'date': '2026-10-15', 'v0': 4.0}),
        store.addRecord(id, {'date': '2026-10-16', 'v1': 55.0}),
      ]);
      expect(store.records(id).length, 2);
      expect(store.latest(id, 0), 4.0);
      expect(store.latest(id, 1), 55.0);
      await store.resetFixtures();
      expect(store.signedIn, false);
      expect(
        await store.login('demo@trackchildren.vn', DemoStore.password),
        true,
      );
      expect(store.children.length, 2);
    },
  );

  testWidgets(
    'selected child drives Home, growth, WHO metadata and account summary',
    (tester) async {
      final store = DemoStore.instance;
      await store.resetFixtures();
      await store.login('demo@trackchildren.vn', DemoStore.password);
      await store.selectChild('child_an');
      await tester.pumpWidget(
        const MaterialApp(home: HomeScreen(childName: 'Bảo An')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bảo An'), findsOneWidget);
      expect(find.textContaining('8.4 kg'), findsWidgets);
      await tester.tap(find.byTooltip('Đổi hồ sơ bé'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gia Linh').last);
      await tester.pumpAndSettle();
      expect(store.child!['id'], 'child_linh');
      expect(find.textContaining('12.5 kg'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('12.5 kg'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('12.5 kg'), findsOneWidget);
      await tester.tap(find.text('Theo dõi'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      expect(find.byType(GrowthScreen), findsOneWidget);
      expect(find.text('12.5'), findsOneWidget);
      expect(find.text('┄ Trung vị WHO'), findsOneWidget);
      await tester.tap(find.text('Cập nhật số đo'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '12.8');
      await tester.tap(find.text('Lưu số đo'));
      await tester.pumpAndSettle();
      expect(store.latest('child_linh', 0), 12.8);
      expect(store.latest('child_an', 0), 8.4);
      await tester.tap(find.text('Trang chủ').last);
      await tester.pumpAndSettle();
      expect(find.text('12.8 kg'), findsOneWidget);
      await tester.tap(find.text('Cá nhân'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('demo@trackchildren.vn'), findsOneWidget);
      await store.saveParent({'fullName': 'Mẹ Hoa cập nhật'});
      await tester.pumpAndSettle();
      expect(find.text('Mẹ Hoa cập nhật'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await store.logout();
    },
  );

  testWidgets('selection shows only logged-in family profiles', (tester) async {
    final store = DemoStore.instance;
    await store.resetFixtures();
    await store.login('bo@trackchildren.vn', DemoStore.password);
    await tester.pumpWidget(
      MaterialApp(
        home: ChildProfileSelectionScreen(
          onSelectChild: (_) {},
          onAddChild: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Minh Khang'), findsOneWidget);
    expect(find.text('Bảo An'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await store.logout();
  });
}
