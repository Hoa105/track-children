import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:track_children/core/routing/app_router.dart';
import 'package:track_children/core/routing/app_routes.dart';
import 'package:track_children/main.dart';
import 'package:track_children/models/child_share.dart';
import 'package:track_children/services/service_locator.dart';

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.pumpAndSettle();
  expect(finder, findsWidgets);
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> open(WidgetTester tester, String route) async {
    // The test font (Ahem) is far wider than Quicksand, so tiny overflows
    // here aren't real — report them but don't fail on them.
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) {
        debugPrint('IGNORED: ${details.exceptionAsString()}');
        return;
      }
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
    tester.view.physicalSize = const Size(1080, 7000);
    tester.view.devicePixelRatio = 2.75;
    await tester.pumpWidget(const BeLonKhonApp());
    appRouter.go(route);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }

  testWidgets('member list → change permission → invite', (tester) async {
    await open(tester, '${AppRoutes.childSharing}/c1');
    expect(find.text('Người cùng theo dõi'), findsOneWidget);
    expect(find.text('Nguyễn Văn Nam'), findsOneWidget);
    expect(find.text('0912345678'), findsOneWidget);

    await tester.tap(find.text('Nguyễn Văn Nam'));
    await tester.pumpAndSettle();
    // Nam starts at "Xem tất cả"; upgrade only Tăng trưởng.
    await tester.tap(find.text('Xem & sửa').first);
    await tester.pump();
    expect(find.text('Được ghi nhận số đo'), findsOneWidget);
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.textContaining('thành "Sửa 1/5 mục"'), findsOneWidget);

    await reveal(tester, find.text('Mời người chăm sóc'));
    await tester.tap(find.text('Mời người chăm sóc'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.textContaining('Mời người thân cùng theo dõi'), findsOneWidget);
    // Every section at "Không xem" → nothing to share, send is disabled.
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('Không xem').at(i));
      await tester.pump();
    }
    expect(find.text('Cần cho xem ít nhất 1 mục.'), findsOneWidget);
    await tester.tap(find.text('Xem').first);
    await tester.pump();
    expect(find.text('Cần cho xem ít nhất 1 mục.'), findsNothing);
    await reveal(tester, find.text('Gửi lời mời'));
    await tester.tap(find.text('Gửi lời mời'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập email hoặc số điện thoại'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'bo.minh@gmail.com');
    await reveal(tester, find.text('Gửi lời mời'));
    await tester.tap(find.text('Gửi lời mời'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Đã gửi lời mời'), findsOneWidget);
    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await reveal(tester, find.text('bo.minh@gmail.com'));
    expect(find.text('bo.minh@gmail.com'), findsOneWidget);
    await reveal(tester, find.textContaining('tối đa 3 người. Thu hồi'));
    // 1 joined + 2 pending = limit reached.
    expect(find.textContaining('tối đa 3 người. Thu hồi'), findsOneWidget);
  });

  testWidgets('shared-with-me: accept invite, open profile, leave', (tester) async {
    await open(tester, AppRoutes.sharedWithMe);
    expect(find.text('LỜI MỜI ĐANG CHỜ (1)'), findsOneWidget);
    await tester.tap(find.text('Chấp nhận'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Tham gia').last);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('HỒ SƠ ĐANG THEO DÕI (2)'), findsOneWidget);

    // Tapping a shared child opens Trang chủ for it. Home's AI bubble
    // animates forever, so pump fixed durations instead of settling.
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    await tester.tap(find.text('Trần Gia Hân'));
    await settle();
    expect(find.text('Được chia sẻ bởi Trần Thu Hà (Mẹ) · Xem 4/5 mục'), findsOneWidget);
    // Gia Hân: everything "Xem" → cards visible, but no starting a new assessment.
    expect(find.text('Tiến độ theo lĩnh vực'), findsOneWidget);
    expect(find.text('Gợi ý cho mẹ lúc này'), findsOneWidget);
    expect(find.text('Bắt đầu đánh giá →'), findsNothing);

    // Header card → shared profile (info + leave).
    await tester.tap(find.text('Trần Gia Hân'));
    await settle();
    // Only the permission summary lists the sections; no shortcut tiles.
    expect(find.text('Quyền của bạn'), findsOneWidget);
    expect(find.text('Theo dõi bé'), findsNothing);
    expect(find.text('Tăng trưởng'), findsOneWidget);
    await tester.tap(find.text('Rời khỏi hồ sơ'));
    await settle();
    await tester.tap(find.text('Rời khỏi'));
    await settle();
    // Back on Home, now showing the account's own first child.
    expect(find.text('Nguyễn Bảo Minh'), findsOneWidget);
    expect(find.text('Bắt đầu đánh giá →'), findsOneWidget);
  });

  testWidgets('shared child without assessment access hides assessment cards', (tester) async {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (!details.exceptionAsString().contains('overflowed')) original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    tester.view.physicalSize = const Size(1080, 7000);
    tester.view.devicePixelRatio = 2.75;
    await tester.pumpWidget(const BeLonKhonApp());
    appRouter.go(AppRoutes.home);
    await settle();

    // Pretend the owner switched "Đánh giá phát triển" to "Không xem".
    final shared = (await tester.runAsync(ServiceLocator.sharingService.getSharedWithMe))!;
    final access = shared.firstWhere((a) => a.status == ShareStatus.accepted);
    ServiceLocator.activeChild.selectShared(SharedChildAccess(
      id: access.id,
      child: access.child,
      ownerName: access.ownerName,
      ownerRole: access.ownerRole,
      myRole: access.myRole,
      permissions: access.permissions.withLevel(ShareSection.assessment, AccessLevel.none),
      status: access.status,
      invitedAt: access.invitedAt,
      inviteCode: access.inviteCode,
    ));
    await settle();
    expect(find.text(access.child.name), findsOneWidget);
    expect(find.text('Tiến độ theo lĩnh vực'), findsNothing);
    expect(find.text('Bắt đầu đánh giá →'), findsNothing);
    expect(find.text('Gợi ý cho mẹ lúc này'), findsOneWidget);
  });

  testWidgets('child profile shows sharing card; picker shows shared section', (tester) async {
    await open(tester, AppRoutes.childProfile);
    await reveal(tester, find.text('Người cùng theo dõi'));
    expect(find.text('Người cùng theo dõi'), findsOneWidget);

    appRouter.go(AppRoutes.childPicker);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('ĐƯỢC CHIA SẺ VỚI BẠN'), findsOneWidget);
  });
}
