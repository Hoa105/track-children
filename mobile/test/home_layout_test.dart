import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/main.dart';
import 'package:track_children/features/home/home_screen.dart';

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
    final iconFont = File.fromUri(
      flutterUri.resolve(
        '../../bin/cache/artifacts/material_fonts/materialicons-regular.otf',
      ),
    );
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(ByteData.sublistView(await iconFont.readAsBytes())),
        ))
        .load();
  });

  for (final size in const [
    Size(320, 640),
    Size(360, 800),
    Size(390, 844),
    Size(402, 874),
    Size(430, 932),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Home ${size.width} at text scale $scale', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        SharedPreferences.setMockInitialValues({});
        final captureKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(key: captureKey, child: const TrackChildrenApp()),
        );
        // Open Home without waiting for the start screen's looping animation.
        await tester.pump();
        tester
            .state<NavigatorState>(find.byType(Navigator).first)
            .pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const HomeScreen(childName: 'Bé Nguyễn Hoàng Minh An'),
              ),
            );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final images = tester.widgetList<Image>(find.byType(Image));
          final context = tester.element(find.byType(HomeScreen));
          for (final image in images) {
            await precacheImage(image.image, context);
          }
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final care = find.byKey(const ValueKey('home-care-card'));
        final hero = find.byKey(const ValueKey('home-hero'));
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(care, findsOneWidget);
        expect(
          tester.getRect(hero).bottom - tester.getRect(care).top,
          closeTo(10, 0.01),
        );
        expect(
          find.descendant(of: care, matching: find.byType(Icon)),
          findsNothing,
        );
        expect(
          find.descendant(of: care, matching: find.byType(Image)),
          findsNWidgets(5),
        );
        expect(
          find.descendant(of: care, matching: find.byType(SvgPicture)),
          findsNothing,
        );
        if ((size.width == 320 || size.width == 430) && scale == 1) {
          await capture(tester, captureKey, '${size.width.toInt()}_top');
          await tester.ensureVisible(find.text('Hôm nay bé cần gì?'));
          await tester.pumpAndSettle();
          await capture(tester, captureKey, '${size.width.toInt()}_care');
        }
        for (final label in [
          'Lượng sữa',
          'Tiêm chủng',
          'Mọc răng',
          'Hoạt động',
          'Nhật ký',
        ]) {
          final item = find.descendant(
            of: care,
            matching: find.bySemanticsLabel(RegExp('^$label,')),
          );
          await tester.ensureVisible(item);
          await tester.pumpAndSettle();
          await tester.tap(item);
          await tester.pumpAndSettle();
          expect(
            find.text(
              'Thông tin tổng quan. Tính năng ghi chép và chi tiết mục này chưa khả dụng.',
            ),
            findsOneWidget,
          );
          await tester.tap(find.text('Đóng'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        for (final label in [
          'Cân nặng',
          'Chiều cao',
          'Hành trình lớn khôn',
          'Nhật ký gần đây',
        ]) {
          await tester.scrollUntilVisible(
            find.text(label),
            200,
            scrollable: find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        if ((size.width == 320 || size.width == 430) && scale == 1) {
          await capture(tester, captureKey, '${size.width.toInt()}_lower');
        }
        final verticalPosition = tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byType(CustomScrollView),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            )
            .position;
        verticalPosition.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Hành trình lớn khôn'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        final timeline = find
            .ancestor(
              of: find.text('4–5 tuổi').last,
              matching: find.byType(SingleChildScrollView),
            )
            .last;
        verticalPosition.jumpTo(
          (verticalPosition.pixels +
                  tester.getCenter(timeline).dy -
                  size.height / 2)
              .clamp(
                verticalPosition.minScrollExtent,
                verticalPosition.maxScrollExtent,
              ),
        );
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(
          tester.element(timeline),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        await tester.drag(timeline, const Offset(-600, 0));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(find.text('4–5 tuổi').last).right,
          lessThanOrEqualTo(size.width),
        );
      });
    }
  }
  const stages = [
    ('0_3_months', 'baby_boy', 'Chào bé đến\nvới thế giới'),
    ('4_6_months', 'baby_boy', 'Bé khám phá\nxung quanh'),
    ('7_9_months', 'baby_boy', 'Bé ngày càng\ncứng cáp'),
    ('10_12_months', 'baby_boy', 'Cùng bé bước\nđến tuổi lên một'),
    ('1_3_years', 'boy', 'Cùng bé học\nđiều mới'),
    ('4_5_years', 'boy', 'Bé lớn khôn\nvà tự tin'),
  ];
  for (var age = 0; age < stages.length; age++) {
    for (final size in const [Size(320, 640), Size(390, 844), Size(430, 932)]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('Age $age: ${size.width}px, text $scale', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final captureKey = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: captureKey,
              child: MaterialApp(
                theme: ThemeData(fontFamily: 'Be Vietnam Pro'),
                home: HomeScreen(
                  childName: 'Bé Nguyễn Hoàng Minh An',
                  heroAgeIndex: age,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Dữ liệu xem trước'), findsNothing);
          expect(find.byType(DropdownButton<int>), findsNothing);
          expect(find.text(stages[age].$3), findsOneWidget);
          final character = tester.widget<Image>(
            find.byKey(const ValueKey('home-hero-character')),
          );
          expect(
            (character.image as AssetImage).assetName,
            'assets/images/scenery/characters/${stages[age].$2}_${stages[age].$1}.png',
          );
          expect(character.fit, BoxFit.contain);
          expect(
            tester
                .widgetList<Image>(find.byType(Image))
                .any(
                  (image) =>
                      image.image is AssetImage &&
                      (image.image as AssetImage).assetName ==
                          'assets/images/scenery/backgrounds/hero_${stages[age].$1}.png',
                ),
            isTrue,
          );
          final heroRect = tester.getRect(
            find.byKey(const ValueKey('home-hero')),
          );
          final characterRect = tester.getRect(
            find.byKey(const ValueKey('home-hero-character')),
          );
          expect(
            characterRect.left,
            greaterThanOrEqualTo(
              heroRect.left - ((age == 0 || age == 2) ? 42 : 0),
            ),
          );
          expect(characterRect.right, lessThanOrEqualTo(heroRect.right));
          expect(characterRect.top, greaterThanOrEqualTo(heroRect.top + 24));
          expect(characterRect.bottom, lessThanOrEqualTo(heroRect.bottom));
          await capture(
            tester,
            captureKey,
            '${size.width.toInt()}_age_${age}_scale_$scale',
          );
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.text('Nhật ký gần đây'),
            200,
            scrollable: find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          expect(find.text('Nhật ký gần đây').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final context = tester.element(find.byType(HomeScreen));
    for (final image in tester.widgetList<Image>(find.byType(Image))) {
      await precacheImage(image.image, context);
    }
  });
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/home_review');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}
