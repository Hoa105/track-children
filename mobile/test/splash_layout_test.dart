import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/splash/splash_screen.dart';

void main() {
  for (final page in [0, 1]) {
    testWidgets('skip page $page saves completion and calls login once', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(home: SplashScreen(onLoginRequired: () => calls++)),
      );
      await tester.pumpAndSettle();
      if (page == 1) {
        await tester.ensureVisible(find.text('Tiếp tục'));
        await tester.tap(find.text('Tiếp tục'));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Bỏ qua').first);
      await tester.tap(find.text('Bỏ qua').first);
      await tester.tap(find.text('Bỏ qua').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(calls, 1);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'track_children_onboarding_completed',
        ),
        true,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  setUpAll(() async {
    final font = File('assets/fonts/nunito/Nunito-Variable.ttf');
    final loader = FontLoader('Nunito')
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
            child: MaterialApp(
              theme: ThemeData(
                fontFamily: 'Nunito',
                textTheme: const TextTheme(
                  headlineMedium: TextStyle(fontSize: 24),
                  bodyLarge: TextStyle(fontSize: 16),
                ),
              ),
              home: SplashScreen(onLoginRequired: () {}),
            ),
          ),
        );
        await tester.runAsync(() async {
          final context = tester.element(find.byType(PageView));
          for (final asset in ['splash_1.png', 'splash_2.png']) {
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
                ? 'Cùng con lớn khôn mỗi ngày'
                : 'Lưu giữ hành trình, cùng nhau chăm bé',
          );
          expect(title, findsOneWidget);
          final description = find.text(
            page == 0
                ? 'Theo dõi tăng trưởng, đánh giá phát triển và khám phá hoạt động phù hợp với độ tuổi của con.'
                : 'Lưu nhật ký ảnh, video, nhận xét AI và chia sẻ hồ sơ để cả nhà cùng đồng hành với bé.',
          );
          final art = find.byType(ClipRect).last;
          expect(
            tester.getRect(description).bottom,
            lessThanOrEqualTo(tester.getRect(art).top),
          );
          if (scale == 1 && (size.width == 320 || size.width == 430)) {
            await tester.ensureVisible(find.text('Bỏ qua').last);
            await tester.pumpAndSettle();
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
