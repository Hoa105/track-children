import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:track_children/core/routing/app_router.dart';
import 'package:track_children/core/routing/app_routes.dart';
import 'package:track_children/main.dart';
import 'package:track_children/services/service_locator.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('shared profiles must be handed over or deleted before the request', (tester) async {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (!details.exceptionAsString().contains('overflowed')) original?.call(details); // Ahem font is wider.
    };
    addTearDown(() => FlutterError.onError = original);
    tester.view.physicalSize = const Size(1080, 7000);
    tester.view.devicePixelRatio = 2.75;
    await tester.pumpWidget(const BeLonKhonApp());
    appRouter.go(AppRoutes.deleteAccount);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Bé Minh is followed by Nam → decision required; bé An isn't shared.
    expect(find.text('Bắt buộc chọn trước khi xóa tài khoản:'), findsOneWidget);
    expect(find.text('Sẽ bị xóa'), findsOneWidget);

    ElevatedButton submit() => tester.widget<ElevatedButton>(
          find.ancestor(of: find.text('Gửi yêu cầu xóa tài khoản'), matching: find.byType(ElevatedButton)),
        );

    await tester.enterText(find.byType(TextField), 'matkhau123');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(submit().onPressed, isNull, reason: 'bé Minh still has no decision');
    expect(find.textContaining('Chọn cách xử lý cho các hồ sơ bé'), findsOneWidget);

    await tester.tap(find.text('Chuyển quyền chủ cho Nguyễn Văn Nam (Bố)'));
    await tester.pump();
    expect(submit().onPressed, isNotNull);

    await tester.tap(find.text('Gửi yêu cầu xóa tài khoản'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Đã gửi yêu cầu xóa tài khoản'), findsOneWidget);
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.text('Quên mật khẩu?'), findsOneWidget); // back on the login screen

    expect(ServiceLocator.authService.deletionScheduledAt, isNotNull);
    // The ownership offer to Nam was sent along with the request.
    appRouter.go('${AppRoutes.childSharing}/c1');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Chờ nhận quyền chủ'), findsOneWidget);
  });
}
