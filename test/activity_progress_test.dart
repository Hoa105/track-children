import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:track_children/core/routing/app_router.dart';
import 'package:track_children/core/routing/app_routes.dart';
import 'package:track_children/main.dart';
import 'package:track_children/models/child_share.dart';
import 'package:track_children/services/service_locator.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> open(WidgetTester tester, String route) async {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return; // Ahem test font is wider than Quicksand.
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
    tester.view.physicalSize = const Size(1080, 7000);
    tester.view.devicePixelRatio = 2.75;
    await tester.pumpWidget(const BeLonKhonApp());
    appRouter.go(route);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }

  test('"Đã làm" is stored per child', () async {
    final service = ServiceLocator.activityService;
    const activityId = 'g1-5'; // Vẽ nghịch bằng bút sáp — not done by anyone yet.
    bool isDone(List groups) =>
        groups.expand((g) => g.items).firstWhere((a) => a.id == activityId).isDone as bool;

    await service.markDone('c1', activityId, true);
    expect(isDone(await service.getGroups(childId: 'c1')), isTrue);
    expect(isDone(await service.getGroups(childId: 'c2')), isFalse);
    expect(isDone(await service.getGroups()), isFalse);
    await service.markDone('c1', activityId, false);
  });

  testWidgets('switching child changes the activity progress shown', (tester) async {
    final children = (await tester.runAsync(ServiceLocator.childService.getChildren))!;
    ServiceLocator.activeChild.selectOwn(children.first);
    await open(tester, AppRoutes.activityGroups);
    expect(find.text('Hoạt động của bé Bảo Minh'), findsOneWidget);
    final minhProgress = tester.widget<Text>(find.textContaining('Đã làm ')).data;

    ServiceLocator.activeChild.selectOwn(children[1]);
    await tester.pump();
    expect(find.text('Hoạt động của bé Bảo Minh'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Hoạt động của bé Bảo An'), findsOneWidget);
    expect(tester.widget<Text>(find.textContaining('Đã làm ')).data, isNot(minhProgress));
  });

  testWidgets('shared child with view-only activities cannot mark done', (tester) async {
    final shared = (await tester.runAsync(ServiceLocator.sharingService.getSharedWithMe))!;
    final access = shared.firstWhere((a) => a.child.id == 'sc1');
    expect(access.permissions.of(ShareSection.activities), AccessLevel.view);
    ServiceLocator.activeChild.selectShared(access);

    await open(tester, '${AppRoutes.activityDetail}/g0-0');
    expect(find.textContaining('bạn chỉ có quyền xem'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(
      find.ancestor(of: find.textContaining('đánh dấu', findRichText: true).first, matching: find.byType(ElevatedButton)),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('journal tab hidden and journal screen locked without journal access', (tester) async {
    final shared = (await tester.runAsync(ServiceLocator.sharingService.getSharedWithMe))!;
    final access = shared.firstWhere((a) => a.child.id == 'sc1');
    expect(access.permissions.of(ShareSection.journal), AccessLevel.none);
    ServiceLocator.activeChild.selectShared(access);

    await open(tester, AppRoutes.activityGroups);
    expect(find.text('Hoạt động'), findsWidgets);
    expect(find.text('Nhật ký'), findsNothing);
    expect(find.text('Theo dõi'), findsOneWidget);

    // Deep link (e.g. the "Nhật ký tuần này" notification) is blocked too.
    appRouter.go(AppRoutes.journal);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.textContaining('Bạn không có quyền xem nhật ký'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);

    // Own child: tab is back.
    final children = (await tester.runAsync(ServiceLocator.childService.getChildren))!;
    ServiceLocator.activeChild.selectOwn(children.first);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Nhật ký'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
