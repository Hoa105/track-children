import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/growth/growth_screen.dart';
import 'package:track_children/features/growth/growth_chart.dart';
import 'package:track_children/services/demo_store.dart';

Future<void> settleData(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
  });
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await rootBundle.loadString('assets/data/who_bmi.json');
    await rootBundle.loadString('assets/data/who_growth.json');
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config =
        jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
    final flutter = (config['packages'] as List).singleWhere(
      (p) => p['name'] == 'flutter',
    );
    final uri = configFile.uri.resolve('${flutter['rootUri']}/');
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final file = File.fromUri(
        uri.resolve('../../bin/cache/artifacts/material_fonts/${entry.value}'),
      );
      await (FontLoader(entry.key)..addFont(
            Future.value(ByteData.sublistView(await file.readAsBytes())),
          ))
          .load();
    }
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
  });
  testWidgets(
    'chart scrubbing updates headline and WHO layers toggle independently',
    (tester) async {
      tester.view.physicalSize = const Size(390, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: GrowthScreen(childName: 'Test')),
      );
      await settleData(tester);
      final plot = find.byKey(const ValueKey('growth-who-chart'));
      await tester.ensureVisible(plot);
      await tester.pumpAndSettle();
      final rect = tester.getRect(plot);
      await tester.tapAt(rect.topLeft + const Offset(43, 110));
      await tester.pumpAndSettle();
      expect(find.text('6.5'), findsOneWidget);
      expect(find.text('Số đo đang xem'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      final moved = tester.getRect(plot);
      final gesture = await tester.startGesture(
        moved.topLeft + const Offset(44, 110),
      );
      await gesture.moveBy(const Offset(25, 0));
      await tester.pump();
      await gesture.moveTo(Offset(moved.right - 15, moved.top + 110));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('8.4'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('toggle-who-median')),
      );
      await tester.tap(find.byKey(const ValueKey('toggle-who-median')));
      await tester.pumpAndSettle();
      var painter =
          tester.widget<CustomPaint>(plot).painter! as GrowthChartPainter;
      expect(painter.showMedian, false);
      expect(painter.showBand, true);
      await tester.tap(find.byKey(const ValueKey('toggle-who-band')));
      await tester.pumpAndSettle();
      painter = tester.widget<CustomPaint>(plot).painter! as GrowthChartPainter;
      expect(painter.showBand, false);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('rapidly revisiting measurements keeps animation keys unique', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: GrowthScreen(childName: 'Test')),
    );
    await settleData(tester);
    for (final index in [1, 2, 1, 2, 1, 0, 1]) {
      tester.widget<GrowthChart>(find.byType(GrowthChart)).onSelected!(index);
      await tester.pump(const Duration(milliseconds: 30));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(find.text('6.9'), findsOneWidget);
      for (final tab in ['Chiều cao', 'Cân nặng', 'Chiều cao', 'Cân nặng']) {
        await tester.tap(find.text(tab).first);
        await tester.pump(const Duration(milliseconds: 30));
        expect(tester.takeException(), isNull);
      }
      await settleData(tester);
      expect(tester.takeException(), isNull);
  });
  testWidgets(
    'history expands on demand and WHO explanation opens separately',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: GrowthScreen(childName: 'Test')),
      );
      await settleData(tester);
      await tester.scrollUntilVisible(
        find.text('Xem tất cả 7 lần đo'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Xem tất cả 7 lần đo'));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNWidgets(3));
      await tester.tap(find.text('Xem tất cả 7 lần đo'));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNWidgets(7));
      await tester.scrollUntilVisible(
        find.text('Thu gọn'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Thu gọn'));
      await tester.tap(find.text('Thu gọn'));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNWidgets(3));
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      final info = find.widgetWithIcon(IconButton, Icons.info_outline_rounded);
      await tester.ensureVisible(info);
      await tester.pumpAndSettle();
      await tester.tap(info);
      await tester.pumpAndSettle();
      expect(find.text('Hiểu biểu đồ WHO'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('measurement sheet visual preview', (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: const MaterialApp(home: GrowthScreen(childName: 'Test')),
      ),
    );
    await settleData(tester);
    await tester.tap(find.byTooltip('Cập nhật số đo'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final rendered =
          await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
      final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/previews/measurement-sheet.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      rendered.dispose();
    });
  });
  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('growth layout $width scale $scale with reduced motion', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 850),
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: RepaintBoundary(
                key: boundary,
                child: const GrowthScreen(childName: 'Test'),
              ),
            ),
          ),
        );
        await settleData(tester);
        for (final tab in ['Cân nặng', 'Chiều cao', 'Vòng đầu', 'BMI']) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          await tester.tap(find.text(tab).first);
          await settleData(tester);
          expect(tester.takeException(), isNull);
          await tester.drag(find.byType(ListView).first, const Offset(0, -450));
          await settleData(tester);
          expect(tester.takeException(), isNull);
        }
        if (width == 390 && scale == 1) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final rendered =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 1);
            final bytes = await rendered.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File('build/previews/growth-bmi.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            rendered.dispose();
          });
        }
      });
    }
  }
}
