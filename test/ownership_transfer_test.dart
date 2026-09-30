import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:track_children/core/routing/app_router.dart';
import 'package:track_children/core/routing/app_routes.dart';
import 'package:track_children/main.dart';
import 'package:track_children/services/service_locator.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> open(WidgetTester tester, String route) async {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (!details.exceptionAsString().contains('overflowed')) original?.call(details); // Ahem font is wider.
    };
    addTearDown(() => FlutterError.onError = original);
    tester.view.physicalSize = const Size(1080, 7000);
    tester.view.devicePixelRatio = 2.75;
    await tester.pumpWidget(const BeLonKhonApp());
    appRouter.go(route);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }

  testWidgets('owner offers ownership with password, then cancels', (tester) async {
    await open(tester, '${AppRoutes.childSharing}/c1');
    await tester.tap(find.text('Nguyễn Văn Nam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chuyển quyền chủ hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.text('Chuyển quyền chủ hồ sơ?'), findsOneWidget);

    await tester.tap(find.text('Gửi yêu cầu'));
    await tester.pump();
    expect(find.text('Mật khẩu không đúng'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'matkhau123');
    await tester.tap(find.text('Gửi yêu cầu'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Chờ nhận quyền chủ'), findsOneWidget);

    await tester.tap(find.text('Nguyễn Văn Nam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy yêu cầu chuyển quyền'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Chờ nhận quyền chủ'), findsNothing);
  });

  testWidgets('invitee accepts ownership → child becomes their own', (tester) async {
    await open(tester, AppRoutes.sharedWithMe);
    expect(find.text('YÊU CẦU NHẬN QUYỀN CHỦ HỒ SƠ (1)'), findsOneWidget);
    await tester.tap(find.text('Nhận quyền'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhận quyền chủ'));
    await tester.pump(const Duration(seconds: 1)); // mock service delays
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.textContaining('YÊU CẦU NHẬN QUYỀN CHỦ'), findsNothing);
    expect(find.text('HỒ SƠ ĐANG THEO DÕI (0)'), findsOneWidget);

    final own = (await tester.runAsync(ServiceLocator.childService.getChildren))!;
    expect(own.map((c) => c.id), contains('sc1'));
    // The previous owner stays on as a full-access member.
    final members = (await tester.runAsync(() => ServiceLocator.sharingService.getShares('sc1')))!;
    expect(members.single.inviteeName, 'Trần Thu Hà');
    expect(members.single.permissions.label, 'Xem & sửa tất cả');
  });
}
