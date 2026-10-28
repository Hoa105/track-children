import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/growth/growth_screen.dart';
import 'package:track_children/services/demo_store.dart';

void main() {
  testWidgets('home shortcut opens the form and saves without a growth route', (
    tester,
  ) async {
    DemoStore.resetInstanceForTesting();
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  openMeasurementFromHome(context, childName: 'Test'),
              child: const Text('Add measurement'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Add measurement'));
    await tester.pumpAndSettle();
    expect(find.byType(GrowthScreen), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(3));
    await tester.enterText(find.byType(TextFormField).first, '9.1');
    await tester.tap(find.text('Lưu số đo'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    final records = jsonDecode(prefs.getString('growth_v1_Test')!) as List;
    expect(records.single['v0'], 9.1);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(GrowthScreen), findsNothing);
    expect(find.text('Add measurement'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  setUp(() {
    DemoStore.resetInstanceForTesting();
    SharedPreferences.setMockInitialValues({
      'growth_v1_Test': jsonEncode([
        {'date': '2026-08-01', 'v0': 8.0, 'v1': 70.0, 'v2': 43.0},
        {'date': '2026-09-01', 'v0': 8.5},
      ]),
    });
  });

  testWidgets('latest values stay separate from new entries and partial save', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LegacyGrowthScreen(childName: 'Test')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cập nhật số đo'));
    await tester.pumpAndSettle();
    expect(find.text('8.5 kg'), findsOneWidget);
    expect(find.text('70.0 cm'), findsOneWidget);
    expect(find.text('43.0 cm'), findsOneWidget);
    expect(find.text('Gần nhất · 01/09/2026'), findsOneWidget);
    expect(find.text('Gần nhất · 01/08/2026'), findsNWidgets(2));
    for (final field in tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    )) {
      expect(field.controller!.text, isEmpty);
    }
    await tester.enterText(find.byType(TextFormField).first, '9,1');
    await tester.tap(find.text('Lưu số đo'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    final records = jsonDecode(prefs.getString('growth_v1_Test')!) as List;
    expect(records.last['v0'], 9.1);
    expect(records.last.containsKey('v1'), isFalse);
    expect(records.last.containsKey('v2'), isFalse);
    await tester.tap(find.byTooltip('Cập nhật số đo'));
    await tester.pumpAndSettle();
    expect(find.text('9.1 kg'), findsOneWidget);
    expect(find.text('70.0 cm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small screen, large text, keyboard and live BMI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(1.6),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: const LegacyGrowthScreen(childName: 'Test'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cập nhật số đo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '9');
    final height = find.byType(TextFormField).at(1);
    await tester.ensureVisible(height);
    await tester.pumpAndSettle();
    await tester.enterText(height, '75');
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Lưu số đo')).bottom, lessThan(440));
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('BMI lần đo này: 16.0 kg/m²'));
    await tester.pumpAndSettle();
    expect(find.text('BMI lần đo này: 16.0 kg/m²'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
