import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/home/home_screen.dart';
import 'package:track_children/features/growth/growth_screen.dart';
import 'package:track_children/services/demo_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
    await DemoStore.instance.login('demo@trackchildren.vn', DemoStore.password);
    await DemoStore.instance.selectChild('child_an');
  });

  testWidgets('timeline reveals current milestone after switching child', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(childName: 'Bảo An')),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Hành trình lớn khôn'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final timeline = find.byKey(const ValueKey('home-milestones-scroll'));
    ScrollPosition horizontalPosition() => tester
        .state<ScrollableState>(
          find.descendant(of: timeline, matching: find.byType(Scrollable)),
        )
        .position;
    final before = horizontalPosition().pixels;
    final vertical = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    final verticalBefore = vertical.pixels;
    await DemoStore.instance.selectChild('child_linh');
    await tester.pumpAndSettle();
    final viewport = tester.getRect(timeline);
    final current = tester.getRect(
      find.byKey(const ValueKey('home-milestone-4')),
    );
    expect(current.left, greaterThanOrEqualTo(viewport.left));
    expect(current.right, lessThanOrEqualTo(viewport.right));
    expect(horizontalPosition().pixels, greaterThan(before));
    expect(vertical.pixels, verticalBefore);
    await DemoStore.instance.selectChild('child_an');
    await tester.pumpAndSettle();
    expect(horizontalPosition().pixels, closeTo(before, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick action opens measurement form and dismisses cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(childName: 'Bảo An')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Tạo ghi chép'));
    await tester.pumpAndSettle();
    expect(find.text('Ghi chép nhanh'), findsOneWidget);
    expect(
      tester
          .widget<ListTile>(find.widgetWithText(ListTile, 'Ghi lượng sữa'))
          .enabled,
      isFalse,
    );
    await tester.tap(find.text('Thêm số đo'));
    await tester.pumpAndSettle();
    expect(find.byType(GrowthScreen), findsOneWidget);
    expect(find.byType(TextFormField), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('height card opens height tracking', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(childName: 'Bảo An')),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Chiều cao'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Chiều cao'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<GrowthScreen>(find.byType(GrowthScreen)).initialMetric,
      1,
    );
    expect(tester.takeException(), isNull);
  });
}
