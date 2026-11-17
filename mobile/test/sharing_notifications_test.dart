import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/notifications/notifications_screen.dart';
import 'package:track_children/features/sharing/shared_with_me_screen.dart';
import 'package:track_children/services/app_notifications.dart';
import 'package:track_children/services/demo_store.dart';
import 'package:track_children/services/sharing_api.dart';
import 'package:track_children/services/sharing_invitations.dart';

IncomingInvitation _invitation(String id, {required int daysAgo}) {
  final created = DateTime.now().subtract(Duration(days: daysAgo));
  return IncomingInvitation(
    id: id,
    childId: 'child-$id',
    childName: 'Bé $id',
    inviterName: 'Mẹ Lan',
    relationship: 'maternal_grandmother',
    permissions: const {'diary': 'edit', 'growth': 'view'},
    createdAt: created,
    expiresAt: created.add(const Duration(days: 7)),
  );
}

void main() {
  var invitations = <IncomingInvitation>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
    SharingInvitations.resetForTesting();
    invitations = [
      _invitation('Na', daysAgo: 2),
      _invitation('Bin', daysAgo: 0),
    ];
    SharingInvitations.fetchOverride = () async => invitations;
    await DemoStore.instance.login('demo@trackchildren.vn', DemoStore.password);
  });

  test('pending invitations become notifications, newest first', () async {
    await SharingInvitations.instance.refresh();
    final all = careNotifications(DemoStore.instance);
    final sharing = all.where((n) => n.kind == 'sharing').toList();

    expect(sharing.map((n) => n.id), ['sharing:Bin', 'sharing:Na']);
    expect(all.take(2).every((n) => n.kind == 'sharing'), isTrue);
    expect(sharing.first.title, 'Mẹ Lan mời bạn cùng chăm sóc Bé Bin');
    expect(sharing.first.message, contains('Vai trò: Bà ngoại'));
    expect(
      sharing.first.message,
      contains('Xem & sửa: Nhật ký · Chỉ xem: Tăng trưởng'),
    );
    expect(unreadNotificationCount(DemoStore.instance), greaterThanOrEqualTo(2));

    // Đã trả lời / hết hạn: thông báo biến mất ở lần tải sau
    invitations = [];
    await SharingInvitations.instance.refresh();
    expect(
      careNotifications(DemoStore.instance).where((n) => n.kind == 'sharing'),
      isEmpty,
    );
  });

  test('logout clears invitations of the previous account', () async {
    await SharingInvitations.instance.refresh();
    SharingInvitations.instance.clear();
    expect(SharingInvitations.instance.invitations, isEmpty);
  });

  testWidgets('tapping an invitation notification opens the invitations screen', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
    await tester.pumpAndSettle();

    final title = find.text('Mẹ Lan mời bạn cùng chăm sóc Bé Bin');
    expect(title, findsOneWidget);
    expect(find.text('Xem lời mời →'), findsNWidgets(2));

    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(find.byType(SharedWithMeScreen), findsOneWidget);
    expect(
      readNotificationIds(DemoStore.instance),
      contains('sharing:Bin'),
    );
  });
}
