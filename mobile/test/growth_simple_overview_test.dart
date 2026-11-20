import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_overview.dart';

void main() {
  testWidgets('overview opens metric chart and history tabs', (tester) async {
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
    expect(find.text('Đánh giá BMI'), findsOneWidget);
    expect(find.text('Đánh giá vòng đầu'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    await tester.tap(find.text('Cân nặng').first);
    await tester.pumpAndSettle();
    expect(find.text('Biểu đồ'), findsOneWidget);
    expect(find.text('Lịch sử'), findsOneWidget);
    final chart = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          (w.properties.label?.contains('Chạm để chọn số đo.') ?? false),
    );
    expect(chart, findsOneWidget);
    final size = tester.getSize(chart);
    expect(size.height, greaterThanOrEqualTo(380));
    expect(size.height, greaterThan(size.width));
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

    await tester.ensureVisible(chart);
    await tester.pumpAndSettle();
    await capture('growth-overview-preview');
    expect(find.byTooltip('Phóng to'), findsNothing);
    expect(find.text('8,5 kg'), findsWidgets);
    await tester.tap(find.text('Lịch sử'));
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture('growth-history-preview');
    await tester.tap(find.byTooltip('Ghi số đo'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);
    await capture('growth-editor-preview');
    expect(tester.takeException(), isNull);
  });
}
