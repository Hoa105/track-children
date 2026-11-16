import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/home/home_screen.dart';
import 'package:track_children/features/growth/growth_screen.dart';
import 'package:track_children/services/demo_store.dart';

import 'package:track_children/features/feeding/milk_calculator_screen.dart';
import 'package:track_children/features/vaccination/vaccination_screen.dart';
import 'package:track_children/features/teething/teething_screen.dart';
import 'package:track_children/features/activities/activities_screen.dart';
import 'package:track_children/features/journal/journal_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
    await DemoStore.instance.login('demo@trackchildren.vn', DemoStore.password);
    await DemoStore.instance.selectChild('child_an');
  });

  testWidgets('reduced motion disables hero fades and background zoom', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const HomeScreen(childName: 'Bảo An'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    expect(find.byKey(const ValueKey('home-background-scale')), findsNothing);
    await DemoStore.instance.selectChild('child_linh');
    await tester.pumpAndSettle();
    expect(find.text('Gia Linh'), findsOneWidget);
    expect(find.text('Bảo An'), findsNothing);
    expect(tester.takeException(), isNull);
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
      find.byKey(const ValueKey('home-milestones-scroll')),
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

  testWidgets(
    'home plus preserves metric choice and opens measurement editor',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: HomeScreen(childName: 'Bảo An')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Tạo ghi chép'));
      await tester.pumpAndSettle();
      expect(find.text('Ghi chép nhanh'), findsNothing);
      expect(find.byType(GrowthScreen), findsNothing);
      expect(find.text('Thêm số đo mới'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Cân nặng'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tracking remains accessible from bottom navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(childName: 'Bảo An')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chiều cao'), findsNothing);
    await tester.tap(find.text('Theo dõi'));
    await tester.pumpAndSettle();
    expect(find.byType(GrowthScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final route in <String, Type>{
    'Lượng sữa': MilkCalculatorScreen,
    'Tiêm chủng': VaccinationScreen,
    'Mọc răng': TeethingScreen,
    'Hoạt động': ActivitiesScreen,
    'Nhật ký': JournalScreen,
  }.entries) {
    testWidgets('care shortcut opens ${route.value}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: HomeScreen(childName: 'Bảo An')),
      );
      await tester.pumpAndSettle();
      final shortcut = find.bySemanticsLabel(route.key);
      await tester.ensureVisible(shortcut);
      await tester.pumpAndSettle();
      await tester.tap(shortcut);
      await tester.pumpAndSettle();
      expect(find.byType(route.value), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
