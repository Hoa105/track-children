import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_overview.dart';

void main() {
  testWidgets('overview switches one chart and opens metric history', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final font = await File('assets/fonts/nunito/Nunito-Variable.ttf')
          .readAsBytes();
      for (final family in ['Nunito', 'Roboto']) {
        await (FontLoader(
          family,
        )..addFont(Future.value(ByteData.sublistView(font)))).load();
      }
      final configFile = File('.dart_tool/package_config.json').absolute;
      final config =
          jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
      final flutter = (config['packages'] as List).singleWhere(
        (p) => p['name'] == 'flutter',
      );
      final root = configFile.uri.resolve('${flutter['rootUri']}/');
      final icons = await File.fromUri(
        root.resolve(
          '../../bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        ),
      ).readAsBytes();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(icons)))).load();
    });
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preview = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: preview,
        child: MaterialApp(
          home: GrowthOverview(repository: MockGrowthRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tình hình cân nặng của bé'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    expect(find.text('Dựa trên BMI'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Ghi số đo'), findsOneWidget);
    expect(find.text('Xu hướng gần đây'), findsNothing);
    expect(find.text('Xem lịch sử'), findsNothing);
    final chart = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          (w.properties.label?.contains('Chạm để chọn số đo.') ?? false),
    );
    expect(chart, findsOneWidget);
    final size = tester.getSize(chart);
    expect((size.width - size.height).abs(), lessThanOrEqualTo(10));
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final boundary =
            preview.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('growth-overview-preview');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Vòng đầu'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Xem nhận xét vòng đầu'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cân nặng').first);
    await tester.pumpAndSettle();
    expect(find.byType(GrowthOverview), findsNothing);
    expect(find.text('Cân nặng'), findsWidgets);
    expect(tester.takeException(), isNull);
    await capture('growth-history-preview');
    await tester.tap(find.byTooltip('Ghi số đo'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);
    await capture('growth-editor-preview');
    expect(tester.takeException(), isNull);
  });
}
