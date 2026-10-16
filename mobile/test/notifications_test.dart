import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/services/demo_store.dart';
import 'package:track_children/services/app_notifications.dart';
import 'package:track_children/features/notifications/notifications_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
    final store = DemoStore.instance;
    await store.login('demo@trackchildren.vn', DemoStore.password);
    await store.saveVaccination('child_an', {
      'id': 'custom-reminder',
      'custom': true,
      'given': false,
      'name': 'Lịch hẹn mẫu',
      'prevents': '',
      'doseLabel': 'Mũi 1',
      'date': DateTime.now().toIso8601String(),
    });
  });
  test(
    'read state persists, respects settings and isolates accounts',
    () async {
      final store = DemoStore.instance;
      final item = careNotifications(store)
          .firstWhere((n) => n.id.contains('custom-reminder'));
      await store.saveParent({
        'readNotifications': [item.id],
      });
      DemoStore.resetInstanceForTesting();
      await DemoStore.instance.initialize();
      expect(readNotificationIds(DemoStore.instance), contains(item.id));
      await DemoStore.instance.saveParent({'notifications': false});
      expect(careNotifications(DemoStore.instance), isEmpty);
      await DemoStore.instance.saveParent({'notifications': true});
      await DemoStore.instance.saveVaccination('child_an', {
        'id': 'custom-reminder',
        'custom': true,
        'given': true,
        'name': 'Lịch hẹn mẫu',
        'prevents': '',
        'doseLabel': 'Mũi 1',
        'date': DateTime.now().toIso8601String().split('T').first,
      });
      expect(
        careNotifications(DemoStore.instance)
            .any((n) => n.id.contains('custom-reminder')),
        isFalse,
      );
      await DemoStore.instance.login('bo@trackchildren.vn', DemoStore.password);
      expect(readNotificationIds(DemoStore.instance), isEmpty);
      expect(
        careNotifications(DemoStore.instance)
            .any((n) => n.childId == 'child_an'),
        isFalse,
      );
    },
  );
  testWidgets('mark all read and filter at narrow width with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 1000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: const NotificationsScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Đọc tất cả'));
    await tester.pumpAndSettle();
    expect(unreadNotificationCount(DemoStore.instance), 0);
    await tester.tap(find.text('Chưa đọc (0)'));
    await tester.pumpAndSettle();
    expect(find.text('Không có thông báo chưa đọc'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
