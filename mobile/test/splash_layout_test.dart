import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/splash/splash_screen.dart';

void main() {
  setUpAll(() async {
    // Use Flutter's fallback font instead of the test-only Ahem boxes.
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config =
        jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
    final flutterPackage = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((package) => package['name'] == 'flutter');
    final flutterUri = configFile.uri.resolve("${flutterPackage['rootUri']}/");
    final font = File.fromUri(
      flutterUri.resolve(
        '../../bin/cache/artifacts/material_fonts/roboto-regular.ttf',
      ),
    );
    final loader = FontLoader('Be Vietnam Pro')
      ..addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
    await loader.load();
  });
  for (final size in const [
    Size(320, 640),
    Size(360, 800),
    Size(390, 844),
    Size(402, 874),
    Size(430, 932),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('splash ${size.width} at text scale $scale', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        SharedPreferences.setMockInitialValues({});
        final captureKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: captureKey,
            child: MaterialApp(home: SplashScreen(onLoginRequired: () {})),
          ),
        );
        await tester.runAsync(() async {
          final context = tester.element(find.byType(PageView));
          for (final asset in ['splash_screen_1.png', 'splash_screen_2.png']) {
            await precacheImage(
              AssetImage('assets/images/scenery/backgrounds/$asset'),
              context,
            );
          }
        });
        await tester.pumpAndSettle();
        for (var page = 0; page < 2; page++) {
          expect(tester.takeException(), isNull);
          final title = find.text(
            page == 0
                ? 'Chăm sóc bé dễ dàng hơn'
                : 'Đồng hành cùng bé mỗi ngày',
          );
          expect(title, findsOneWidget);
          final description = find.text(
            page == 0
                ? 'Theo dõi hành trình lớn khôn của con qua từng cột mốc phát triển.'
                : 'Theo dõi tăng trưởng, lịch tiêm chủng, dinh dưỡng và những khoảnh khắc đáng nhớ.',
          );
          final art = find.byType(ClipRect).last;
          expect(
            tester.getRect(description).bottom,
            lessThanOrEqualTo(tester.getRect(art).top),
          );
          if (scale == 1 && (size.width == 320 || size.width == 430)) {
            final boundary =
                captureKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final directory = Directory('build/splash_review');
              await directory.create(recursive: true);
              await File(
                '${directory.path}/${size.width.toInt()}_page_$page.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          final button = find.widgetWithText(
            FilledButton,
            page == 0 ? 'Tiếp tục' : 'Bắt đầu',
          );
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          final rect = tester.getRect(button);
          expect(rect.height, greaterThanOrEqualTo(56));
          expect(rect.bottom, lessThanOrEqualTo(size.height - 24));
          if (page == 0) {
            await tester.tap(button);
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
