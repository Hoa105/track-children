import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/growth/growth_screen.dart';
import 'package:track_children/features/home/home_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('save measurements, calculate BMI and restore saved data', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: GrowthScreen(childName: 'Test')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cập nhật số đo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '8,1');
    await tester.enterText(find.byType(TextFormField).at(1), '68');
    await tester.enterText(find.byType(TextFormField).at(2), '43');
    await tester.tap(find.text('Lưu số đo'));
    await tester.pumpAndSettle();
    expect(find.text('8.1'), findsOneWidget);
    await tester.tap(find.text('BMI'));
    await tester.pumpAndSettle();
    expect(find.text('17.5'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Chưa có khoảng tham chiếu'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Chưa có khoảng tham chiếu'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      const MaterialApp(home: GrowthScreen(childName: 'Test')),
    );
    await tester.pumpAndSettle();
    expect(find.text('8.1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tracking navigation opens screen and returns home', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(childName: 'Test')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Theo dõi'));
    await tester.pumpAndSettle();
    expect(find.byType(GrowthScreen), findsOneWidget);
    await tester.tap(find.text('Trang chủ').last);
    await tester.pumpAndSettle();
    expect(find.byType(GrowthScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
