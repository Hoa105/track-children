import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/services/demo_store.dart';
import 'package:track_children/services/app_notifications.dart';
import 'package:track_children/features/notifications/notifications_screen.dart';
import 'package:track_children/features/notifications/notification_settings_screen.dart';
import 'package:track_children/features/notifications/growth_reminder_settings_screen.dart';
import 'package:track_children/features/assessment/assessment_reminders.dart';

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
  test(
    'assessment remains visible after thirty days and stops after completion',
    () {
      final store = DemoStore.instance;
      final opened = DateTime(2026, 9, 1);
      final state = <String, dynamic>{
        'age_months': 9,
        'set': {'count': 10},
        'completed_milestones': [],
        'milestones': [
          {'age_months': 9, 'opens_on': opened.toIso8601String()},
        ],
      };
      AssessmentReminders.instance.put('child_an', state);
      final notices = careNotifications(store, now: DateTime(2026, 11, 20));
      expect(
        notices.any((n) => n.kind == 'assessment' && n.childId == 'child_an'),
        isTrue,
      );
      AssessmentReminders.instance.put('child_an', {
        ...state,
        'completed_milestones': [9],
      });
      expect(
        careNotifications(
          store,
          now: DateTime(2026, 11, 20),
        ).any((n) => n.kind == 'assessment' && n.childId == 'child_an'),
        isFalse,
      );
    },
  );

  testWidgets('NotificationSettingsScreen and GrowthReminderSettingsScreen load children without empty error', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NotificationSettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Cài đặt thông báo'), findsOneWidget);

    // Verify section heading and children list directly on NotificationSettingsScreen
    expect(find.text('Nhắc cập nhật số đo chỉ số'), findsOneWidget);
    expect(find.text('Chưa có hồ sơ trẻ'), findsNothing);
    expect(find.text('Chưa có hồ sơ trẻ.'), findsNothing);
    expect(find.text('Bảo An'), findsOneWidget);

    // Test wheel picker for Giờ - Phút works just like TeethingDatePicker
    expect(find.byKey(const Key('notification-time-picker')), findsOneWidget);
    expect(find.byKey(const Key('notification-time-Giờ')), findsOneWidget);
    expect(find.byKey(const Key('notification-time-Phút')), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('notification-time-Phút')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Test turning OFF notifications dims & disables lower sections
    await tester.tap(find.text('Thông báo trên thiết bị'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bảo An'), warnIfMissed: false);
    await tester.pumpAndSettle();
    // Should NOT navigate to GrowthReminderSettingsScreen when notifications are OFF
    expect(find.text('Nhắc số đo: Bảo An'), findsNothing);

    // Turn notifications back ON and tap on child "Bảo An"
    await tester.tap(find.text('Thông báo trên thiết bị'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bảo An'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Verify per-metric growth reminder screen renders cleanly
    expect(find.text('Nhắc số đo: Bảo An'), findsOneWidget);
    expect(find.text('Cân nặng'), findsOneWidget);
    expect(find.text('Chiều dài / Chiều cao'), findsOneWidget);
    expect(find.text('Vòng đầu'), findsOneWidget);
    expect(find.text('Theo độ tuổi'), findsWidgets);
    expect(find.text('Lưu cài đặt'), findsOneWidget);
  });
}
