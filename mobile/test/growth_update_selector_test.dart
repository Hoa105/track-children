import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_overview.dart';
import 'package:track_children/features/growth/growth_update_selector.dart';

void main() {
  testWidgets(
    'selector renders, returns to overview and handles narrow large text',
    (tester) async {
      await tester.runAsync(() async {
        final config = File('.dart_tool/package_config.json').absolute;
        final packages =
            jsonDecode(await config.readAsString())['packages'] as List;
        final flutter = packages.singleWhere((p) => p['name'] == 'flutter');
        final root = config.uri.resolve('${flutter['rootUri']}/');
        final icons = await File.fromUri(
          root.resolve(
            '../../bin/cache/artifacts/material_fonts/materialicons-regular.otf',
          ),
        ).readAsBytes();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(ByteData.sublistView(icons)))).load();
      });
      for (final font in {
        'Nunito': 'nunito/Nunito-Variable.ttf',
        'DancingScript': 'dancing_script/DancingScript-Variable.ttf',
      }.entries) {
        await (FontLoader(
          font.key,
        )..addFont(rootBundle.load('assets/fonts/${font.value}'))).load();
      }
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final captureKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: captureKey,
            child: const GrowthUpdateSelectorScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Gần nhất: 8,5 kg'), findsOneWidget);
      expect(find.text('Gần nhất: 75 cm'), findsOneWidget);
      expect(find.text('Gần nhất: 45 cm'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final capture = await boundary.toImage(pixelRatio: 2);
        final png = await capture.toByteData(format: ui.ImageByteFormat.png);
        final file = File('../docs/growth/screenshots/update-selector.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png!.buffer.asUint8List());
        capture.dispose();
      });
      await tester.tap(find.text('Cân nặng'));
      await tester.pumpAndSettle();
      expect(find.text('Cập nhật cân nặng'), findsOneWidget);
      await tester.tap(find.byTooltip('Về chọn chỉ số'));
      await tester.pumpAndSettle();
      for (final title in ['Chiều dài/chiều cao', 'Vòng đầu']) {
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(
          find.text(
            title == 'Chiều dài/chiều cao'
                ? 'Cập nhật chiều dài'
                : 'Cập nhật ${title.toLowerCase()}',
          ),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('Về chọn chỉ số'));
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox());
      tester.view.physicalSize = const Size(320, 740);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const GrowthUpdateSelectorScreen(easyReadMode: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Vòng đầu'), 200);
      await tester.tap(find.text('Vòng đầu'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(const MaterialApp(home: GrowthOverview()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cập nhật chỉ số mới'));
      await tester.pumpAndSettle();
      expect(find.byType(GrowthUpdateSelectorScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Về tổng quan tăng trưởng'));
      await tester.pumpAndSettle();
      expect(find.byType(GrowthUpdateSelectorScreen), findsNothing);
      await tester.tap(find.bySemanticsLabel('Tạo ghi chép'));
      await tester.pumpAndSettle();
      expect(find.byType(GrowthUpdateSelectorScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('C19 selects correct metric and respects disabled state', (
    tester,
  ) async {
    final selected = <GrowthMetric>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GrowthUpdateSelector(onSelect: selected.add)),
      ),
    );
    for (final title in ['Cân nặng', 'Chiều dài/chiều cao', 'Vòng đầu']) {
      await tester.tap(find.text(title));
      await tester.pump();
    }
    expect(selected, GrowthMetric.values);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrowthUpdateSelector(onSelect: selected.add, enabled: false),
        ),
      ),
    );
    await tester.tap(find.text('Cân nặng'));
    expect(selected.length, 3);
  });
}
