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
import 'package:track_children/features/home/background/background_frame_spec.dart';
import 'package:track_children/services/demo_store.dart';

void main() {
  setUpAll(() async {
    // Use the app's real Nunito font instead of the test-only Ahem boxes.
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config =
        jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
    final flutterPackage = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((package) => package['name'] == 'flutter');
    final flutterUri = configFile.uri.resolve("${flutterPackage['rootUri']}/");
    final loader = FontLoader('Nunito')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            await File('assets/fonts/nunito/Nunito-Variable.ttf').readAsBytes(),
          ),
        ),
      );
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
    Size(320, 568),
    Size(360, 800),
    Size(393, 852),
    Size(402, 874),
    Size(430, 932),
  ]) {
    for (final scale in [1.0, 1.3, 2.0]) {
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
          find.descendant(
            of: find.byKey(const ValueKey('home-background-frame')),
            matching: find.byType(Text),
          ),
          findsNothing,
        );
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
            matching: find.bySemanticsLabel(label),
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
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final size in const [
      Size(320, 568),
      Size(360, 800),
      Size(393, 852),
      Size(430, 932),
    ]) {
      testWidgets('${platform.name} SafeArea ${size.width} text 1.3', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        DemoStore.resetInstanceForTesting();
        await DemoStore.instance.login(DemoStore.demoEmail, DemoStore.password);
        await DemoStore.instance.selectChild('child_an');
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(DemoStore.resetInstanceForTesting);
        final captureKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: captureKey,
            child: MaterialApp(
              theme: ThemeData(fontFamily: 'Nunito', platform: platform),
              home: const HomeScreen(childName: 'Bảo An'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final frame = tester.getRect(
          find.byKey(const ValueKey('home-background-frame')),
        );
        expect(frame.width, size.width);
        expect(frame.width / frame.height, closeTo(homeBgAspectRatio, .001));
        final header = find.byKey(const ValueKey('home-profile-header'));
        expect(tester.getSize(header).height, lessThanOrEqualTo(80));
        final headerText = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byKey(const ValueKey('home-profile-summary')),
                matching: find.byType(Text),
              ),
            )
            .map((text) => text.data)
            .toList();
        expect(headerText, [
          'Bảo An',
          DemoStore.instance.ageLabel(DemoStore.instance.child!),
        ]);
        expect(
          tester.getRect(find.text('Bảo An')).top,
          greaterThanOrEqualTo(44),
        );
        final button = tester.getRect(find.byTooltip('Đổi ảnh nền trang chủ'));
        expect(button.top, greaterThanOrEqualTo(44));
        expect(button.right, lessThanOrEqualTo(size.width - 16));
        expect(button.shortestSide, greaterThanOrEqualTo(48));
        await capture(
          tester,
          captureKey,
          '${platform.name}_${size.width.toInt()}_profile_scale_1.3',
        );
        expect(tester.takeException(), isNull);
      });
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
