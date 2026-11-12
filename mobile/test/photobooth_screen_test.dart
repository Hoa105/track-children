import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:track_children/app_colors.dart';
import 'package:track_children/features/photobooth/photobooth_screen.dart';
import 'package:track_children/features/photobooth/photobooth_session.dart';

import 'helpers/photobooth_fakes.dart';

void main() {
  final boundary = GlobalKey();
  const fixtures = 'build/photobooth_ui_tests';

  setUpAll(() async {
    await Directory(fixtures).create(recursive: true);
    final font = FontLoader('Nunito')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            await File('assets/fonts/nunito/Nunito-Variable.ttf').readAsBytes(),
          ),
        ),
      );
    await font.load();
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config =
        jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
    final flutter = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((p) => p['name'] == 'flutter');
    final uri = configFile.uri
        .resolve("${flutter['rootUri']}/")
        .resolve(
          '../../bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        );
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(
            ByteData.sublistView(await File.fromUri(uri).readAsBytes()),
          ),
        ))
        .load();
    for (var i = 0; i < 4; i++) {
      final picture = img.Image(width: 240, height: 320);
      img.fill(picture, color: img.ColorRgb8(100 + i * 25, 155, 145 + i * 15));
      img.fillCircle(
        picture,
        x: 120,
        y: 110,
        radius: 55,
        color: img.ColorRgb8(250, 215, 175),
      );
      img.fillCircle(
        picture,
        x: 103,
        y: 100,
        radius: 5,
        color: img.ColorRgb8(35, 60, 50),
      );
      img.fillCircle(
        picture,
        x: 137,
        y: 100,
        radius: 5,
        color: img.ColorRgb8(35, 60, 50),
      );
      img.fillRect(
        picture,
        x1: 55,
        y1: 180,
        x2: 185,
        y2: 319,
        color: img.ColorRgb8(215, 220 - i * 20, 170),
      );
      await File('$fixtures/photo_$i.jpg').writeAsBytes(img.encodeJpg(picture));
    }
  });

  Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 150; i++) {
      if (done()) {
        await tester.pump();
        return;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    fail('Photobooth UI transition timed out');
  }

  Future<void> cachePhotos(WidgetTester tester) async {
    // Let file IO and codecs finish outside the fake clock, then paint them.
    // Awaiting precache while no frames are pumped can deadlock ResizeImage.
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      final images = tester
          .widgetList<RawImage>(find.byType(RawImage))
          .toList();
      if (images.isNotEmpty && images.every((image) => image.image != null)) {
        break;
      }
    }
    expect(
      tester
          .widgetList<RawImage>(find.byType(RawImage))
          .every((image) => image.image != null),
      isTrue,
      reason: 'Review photos must finish decoding',
    );
    await tester.pumpAndSettle();
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    await tester.pump();
    await tester.runAsync(() async {
      final repaint =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await repaint.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$fixtures/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final size in const [
      Size(320, 568),
      Size(360, 800),
      Size(393, 852),
      Size(430, 932),
    ]) {
      for (final mode in PhotoBoothMode.values) {
        testWidgets(
          '${platform.name} ${size.width} ${mode.name}: duration, camera, pool, slots, add more, handoff',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
            tester.platformDispatcher.textScaleFactorTestValue = 1.3;
            addTearDown(tester.view.reset);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final camera = FakeBoothCamera();
            // A codec created under a previous test's fake clock must not be
            // reused by the next case; give each case its own file/cache keys.
            final caseDirectory =
                '$fixtures/${platform.name}_${size.width.toInt()}_${mode.name}';
            await tester.runAsync(() async {
              await Directory(caseDirectory).create(recursive: true);
              for (var i = 0; i < 4; i++) {
                await File('$fixtures/photo_$i.jpg')
                    .copy('$caseDirectory/photo_$i.jpg');
              }
            });
            final files = FakeBoothFiles()..fixtureDirectory = caseDirectory;
            final controller = testBooth(
              duration: mode == PhotoBoothMode.two
                  ? PhotoBoothDuration.fifteen
                  : PhotoBoothDuration.thirty,
              camera: camera,
              files: files,
              countdown: const Duration(seconds: 1),
            );
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: MaterialApp(
                  theme: ThemeData(
                    fontFamily: 'Nunito',
                    platform: platform,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: AppColors.primary,
                      surface: AppColors.background,
                    ),
                  ),
                  home: PhotoBoothScreen(
                    accountId: 'account-test',
                    childId: 'child-test',
                    controller: controller,
                    editorBuilder: (_, _, onBack) => Column(
                      children: [
                        const Text('Bộ ảnh đã sẵn sàng'),
                        TextButton(
                          onPressed: onBack,
                          child: const Text('Quay lại bộ ảnh'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (mode == PhotoBoothMode.two) {
              await screenshot(
                tester,
                '${platform.name}_${size.width.toInt()}_start',
              );
            }
            await tester.ensureVisible(find.text('Bắt đầu chụp'));
            await tester.tap(find.text('Bắt đầu chụp'));
            await tester.pumpAndSettle();
            expect(controller.canStart, isTrue);
            expect(
              tester
                  .getSize(
                    find.byKey(const ValueKey('photobooth-camera-viewport')),
                  )
                  .height,
              greaterThan(80),
            );
            await tester.tap(find.byKey(const ValueKey('photobooth-shutter')));
            await tester.pump();
            expect(controller.countdown, 3);
            expect(camera.captures, 0);
            if (mode == PhotoBoothMode.four) {
              await screenshot(
                tester,
                '${platform.name}_${size.width.toInt()}_countdown',
              );
            }
            await pumpUntil(
              tester,
              () => controller.phase == CapturePhase.reviewing,
            );
            final initialCount = controller.session.duration.estimatedPhotos;
            expect(camera.captures, initialCount);
            expect(controller.session.complete, isFalse);
            await cachePhotos(tester);
            expect(tester.takeException(), isNull);
            await tester.tap(
              find.byKey(ValueKey('photobooth-layout-${mode.count}')),
            );
            await tester.pump();
            await cachePhotos(tester);
            final selectionBounds = tester.getRect(
              find.byKey(const ValueKey('photobooth-selected-photos')),
            );
            expect(
              tester
                  .getSize(
                    find.byKey(const ValueKey('photobooth-review-scroll')),
                  )
                  .height,
              greaterThan(120),
            );
            if (mode == PhotoBoothMode.four) {
              await screenshot(
                tester,
                '${platform.name}_${size.width.toInt()}_review',
              );
            }
            expect(
              tester
                  .widget<FilledButton>(
                    find.widgetWithText(FilledButton, 'Trang trí ảnh'),
                  )
                  .onPressed,
              isNull,
            );
            for (var slot = 0; slot < mode.count; slot++) {
              final photo = mode.count - slot - 1;
              final tile = find.byKey(ValueKey('photobooth-review-$photo'));
              await tester.scrollUntilVisible(
                tile,
                slot == 0 ? 100 : -100,
                scrollable: find.descendant(
                  of: find.byKey(const ValueKey('photobooth-review-scroll')),
                  matching: find.byType(Scrollable),
                ),
              );
              await Scrollable.ensureVisible(
                tester.element(tile),
                alignment: .5,
              );
              await tester.pumpAndSettle();
              await tester.tap(tile);
              await tester.pump();
            }
            expect(
              controller.session.selectedIndices,
              List.generate(mode.count, (i) => mode.count - i - 1),
            );
            expect(
              tester.getRect(
                find.byKey(const ValueKey('photobooth-selected-photos')),
              ),
              selectionBounds,
              reason:
                  'Selected slots stay visible while scrolling the photo pool',
            );
            if (mode == PhotoBoothMode.four) {
              await cachePhotos(tester);
              await screenshot(
                tester,
                '${platform.name}_${size.width.toInt()}_selected',
              );
            }
            await tester.tap(find.text('Chụp thêm'));
            await tester.pumpAndSettle();
            expect(find.text('Trước'), findsNothing);
            expect(find.text('Sau'), findsNothing);
            expect(controller.session.shots, hasLength(initialCount));
            await tester.tap(find.text('Bắt đầu chụp'));
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('photobooth-shutter')));
            await pumpUntil(tester, () => camera.captures > initialCount);
            await tester.tap(find.text('Dừng chụp'));
            await pumpUntil(
              tester,
              () => controller.phase == CapturePhase.reviewing,
            );
            expect(camera.captures, initialCount + 1);
            expect(controller.session.complete, isTrue);
            expect(
              controller.session.selectedIndices,
              List.generate(mode.count, (i) => mode.count - i - 1),
            );
            await tester.tap(find.text('Trang trí ảnh'));
            await tester.pumpAndSettle();
            expect(controller.phase, CapturePhase.editing);
            expect(files.handoffs.single.shots, hasLength(initialCount + 1));
            expect(files.handoffs.single.selectedPhotos, hasLength(mode.count));
            expect(find.text('Bộ ảnh đã sẵn sàng'), findsOneWidget);
            await tester.tap(find.text('Quay lại bộ ảnh'));
            await tester.pumpAndSettle();
            expect(controller.phase, CapturePhase.reviewing);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            expect(files.cleared, 1);
          },
        );
      }
    }
  }

  testWidgets(
    'permission denial shows retry and Settings without leaving camera screen',
    (tester) async {
      final camera = FakeBoothCamera()
        ..openFailure = const PhotoBoothException(
          'Quyền Camera đang bị tắt.',
          canOpenSettings: true,
        );
      final controller = testBooth(camera: camera);
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoBoothScreen(
            accountId: 'account-test',
            childId: 'child-test',
            controller: controller,
          ),
        ),
      );
      await tester.tap(find.text('Bắt đầu chụp'));
      await tester.pumpAndSettle();
      expect(find.text('Quyền Camera đang bị tắt.'), findsOneWidget);
      await tester.tap(find.text('Mở Cài đặt'));
      await tester.pumpAndSettle();
      expect(camera.settingsOpened, 1);
      camera.openFailure = null;
      await tester.tap(find.text('Thử lại camera'));
      await tester.pumpAndSettle();
      expect(controller.canStart, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Back asks before discarding and keeps the full photo pool', (
    tester,
  ) async {
    final files = FakeBoothFiles()..fixtureDirectory = fixtures;
    final controller = testBooth(files: files);
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoBoothScreen(
          accountId: 'account-test',
          childId: 'child-test',
          controller: controller,
        ),
      ),
    );
    await tester.tap(find.text('Bắt đầu chụp'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('photobooth-shutter')));
    await pumpUntil(tester, () => controller.phase == CapturePhase.reviewing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Bỏ bộ ảnh này?'), findsOneWidget);
    await tester.tap(find.text('Giữ lại'));
    await tester.pumpAndSettle();
    expect(files.cleared, 0);
    expect(controller.session.shots, hasLength(5));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('lifecycle stops countdown and requires a new shutter tap', (
    tester,
  ) async {
    final camera = FakeBoothCamera();
    final files = FakeBoothFiles()..fixtureDirectory = fixtures;
    final controller = testBooth(
      camera: camera,
      files: files,
      countdown: const Duration(seconds: 1),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoBoothScreen(
          accountId: 'account-test',
          childId: 'child-test',
          controller: controller,
        ),
      ),
    );
    await tester.tap(find.text('Bắt đầu chụp'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('photobooth-shutter')));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(controller.phase, CapturePhase.paused);
    await tester.pump(const Duration(seconds: 10));
    expect(camera.captures, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(controller.canStart, isTrue);
    expect(camera.captures, 0);
    expect(find.text('Tiếp tục chụp'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('profile replacement removes the discard dialog and session', (
    tester,
  ) async {
    final show = ValueNotifier(true);
    final files = FakeBoothFiles()..fixtureDirectory = fixtures;
    final controller = testBooth(files: files);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: show,
          builder: (_, visible, _) => visible
              ? PhotoBoothScreen(
                  accountId: 'account-test',
                  childId: 'child-test',
                  controller: controller,
                )
              : const Scaffold(body: Text('Hồ sơ đã đổi')),
        ),
      ),
    );
    await tester.tap(find.text('Bắt đầu chụp'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('photobooth-shutter')));
    await pumpUntil(tester, () => controller.phase == CapturePhase.reviewing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Bỏ bộ ảnh này?'), findsOneWidget);
    show.value = false;
    await tester.pumpAndSettle();
    expect(find.text('Bỏ bộ ảnh này?'), findsNothing);
    expect(files.cleared, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    show.dispose();
  });
  testWidgets('start selects 15/30/60 seconds without lens or layout choices', (
    tester,
  ) async {
    final camera = FakeBoothCamera();
    final controller = testBooth(
      camera: camera,
      duration: PhotoBoothDuration.thirty,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PhotoBoothScreen(
          accountId: 'account-test',
          childId: 'child-test',
          controller: controller,
        ),
      ),
    );
    expect(controller.session.duration, PhotoBoothDuration.thirty);
    expect(find.text('15 giây'), findsOneWidget);
    expect(find.text('30 giây'), findsOneWidget);
    expect(find.text('60 giây'), findsOneWidget);
    expect(find.text('Trước'), findsNothing);
    expect(find.text('Sau'), findsNothing);
    expect(find.text('Khung 2 ảnh'), findsNothing);
    await tester.ensureVisible(find.text('60 giây'));
    await tester.tap(find.text('60 giây'));
    await tester.pump();
    expect(controller.remainingSeconds, 60);
    await tester.tap(find.text('Bắt đầu chụp'));
    await tester.pumpAndSettle();
    expect(camera.front, isTrue);
    await tester.tap(find.byTooltip('Đổi camera'));
    await tester.pumpAndSettle();
    expect(camera.front, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'early stop with one photo offers add more and disables incomplete handoff',
    (tester) async {
      final camera = FakeBoothCamera();
      final files = FakeBoothFiles()..fixtureDirectory = fixtures;
      final controller = testBooth(camera: camera, files: files);
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoBoothScreen(
            accountId: 'account-test',
            childId: 'child-test',
            controller: controller,
          ),
        ),
      );
      await tester.tap(find.text('Bắt đầu chụp'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('photobooth-shutter')));
      await pumpUntil(tester, () => camera.captures == 1);
      await tester.tap(find.text('Dừng chụp'));
      await pumpUntil(tester, () => controller.phase == CapturePhase.reviewing);
      expect(controller.session.shots, hasLength(1));
      expect(find.text('Cần thêm 1 ảnh để tiếp tục'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Trang trí ảnh'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Chụp thêm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quay lại bộ ảnh'));
      await tester.pumpAndSettle();
      expect(controller.session.shots, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
