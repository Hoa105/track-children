import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:track_children/app_colors.dart';
import 'package:track_children/features/photobooth/photobooth_edit.dart';
import 'package:track_children/features/photobooth/photobooth_catalog.dart';
import 'package:track_children/features/photobooth/photobooth_controller.dart';
import 'package:track_children/features/photobooth/photobooth_editor_entry.dart';
import 'package:track_children/features/photobooth/photobooth_export.dart';
import 'package:track_children/features/photobooth/photobooth_renderer.dart';
import 'package:track_children/features/photobooth/photobooth_session.dart';
import 'package:track_children/features/photobooth/photobooth_screen.dart';

import 'photobooth_editor_model_test.dart' show editorSession;
import 'helpers/photobooth_fakes.dart';

class StubExporter extends PhotoBoothExporter {
  int calls = 0;
  bool fail = false;
  @override
  Future<String> export(
    PhotoBoothSession session,
    PhotoBoothPainter painter,
  ) async {
    calls++;
    if (fail) throw StateError('disk full: private directory');
    return 'build/photobooth_editor_ui/photo-0.png';
  }
}

class StubGallery extends PhotoBoothGallery {
  int calls = 0;
  PhotoBoothException? failure;
  @override
  Future<void> save(String path) async {
    calls++;
    if (failure != null) throw failure!;
  }
}

void main() {
  final boundary = GlobalKey();
  const root = 'build/photobooth_editor_ui';
  setUpAll(() async {
    await Directory(root).create(recursive: true);
    await (FontLoader('Nunito')..addFont(
          Future.value(
            ByteData.sublistView(
              await File('assets/fonts/nunito/Nunito-Variable.ttf')
                  .readAsBytes(),
            ),
          ),
        ))
        .load();
    final config = jsonDecode(
      await File('.dart_tool/package_config.json').readAsString(),
    ) as Map<String, dynamic>;
    final flutter = (config['packages'] as List).firstWhere(
      (p) => p['name'] == 'flutter',
    );
    final font = File('.dart_tool/package_config.json').absolute.uri
        .resolve('${flutter['rootUri']}/')
        .resolve(
          '../../bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        );
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(
            ByteData.sublistView(await File.fromUri(font).readAsBytes()),
          ),
        ))
        .load();
    for (var i = 0; i < 4; i++) {
      final image = img.Image(width: 480, height: 640);
      img.fill(image, color: img.ColorRgb8(100 + i * 30, 160, 140));
      img.fillCircle(
        image,
        x: 240,
        y: 220,
        radius: 100,
        color: img.ColorRgb8(245, 210, 170),
      );
      img.fillCircle(
        image,
        x: 205,
        y: 200,
        radius: 12,
        color: img.ColorRgb8(40, 60, 40),
      );
      img.fillCircle(
        image,
        x: 275,
        y: 200,
        radius: 12,
        color: img.ColorRgb8(40, 60, 40),
      );
      await File('$root/photo-$i.png').writeAsBytes(img.encodePng(image));
    }
  });

  PhotoBoothSession session(int count) => editorSession(count: count).withShots(
    List.generate(
      6,
      (i) => LocalPhoto(
        path: '$root/photo-${i % 4}.png',
        width: 480,
        height: 640,
        capturedAt: DateTime(2026),
        frontCamera: true,
      ),
    ),
  );

  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 180; i++) {
      if (done()) {
        await tester.pump();
        return;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    fail('Editor transition timed out');
  }

  Future<void> mount(
    WidgetTester tester,
    PhotoBoothEditorController controller, {
    StubExporter? exporter,
    StubGallery? gallery,
    VoidCallback? onBack,
    Future<bool> Function(String)? onUseHome,
    GlobalKey<PhotoBoothEditorEntryState>? key,
    PhotoBoothCatalog? catalog,
  }) async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    // Cached futures belong to the previous widget test's fake clock.
    rootBundle.evict('assets/photobooth/catalog.json');
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          theme: ThemeData(
            fontFamily: 'Nunito',
            scaffoldBackgroundColor: AppColors.background,
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.background,
            ),
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
          ),
          home: Scaffold(
            appBar: AppBar(title: const Text('Trang trí ảnh')),
            body: SafeArea(
              top: false,
              child: PhotoBoothEditorEntry(
                key: key,
                session: controller.session,
                controller: controller,
                catalog: catalog,
                onBack: onBack ?? () {},
                onUseHome: onUseHome ?? (_) async => false,
                exporter: exporter ?? StubExporter(),
                gallery: gallery ?? StubGallery(),
              ),
            ),
          ),
        ),
      ),
    );
    await waitFor(
      tester,
      () => find
          .byKey(const ValueKey('photobooth-editor-canvas'))
          .evaluate()
          .isNotEmpty,
    );
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.tap(find.text('Hoàn tất'));
    await waitFor(tester, () => find.text('Lưu về máy').evaluate().isNotEmpty);
  }

  Future<void> selectFrame(WidgetTester tester, String key) async {
    final tile = find.byKey(ValueKey('photobooth-frame-$key'));
    await tester.scrollUntilVisible(
      tile,
      80,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('photobooth-frame-grid')),
        matching: find.byType(Scrollable),
      ),
    );
    await Scrollable.ensureVisible(tester.element(tile), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(tile);
  }

  Future<void> snapshot(WidgetTester tester, String name) async {
    await waitFor(
      tester,
      () => tester
          .widgetList<RawImage>(find.byType(RawImage))
          .every((image) => image.image != null),
    );
    await tester.pump();
    await tester.runAsync(() async {
      final repaint =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await repaint.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$root/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final size in const [
    Size(320, 568),
    Size(360, 800),
    Size(393, 852),
    Size(430, 932),
  ]) {
    for (final count in [2, 4]) {
      testWidgets(
        '${size.width}: editor $count photos, tabs, finish and return',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final controller = PhotoBoothEditorController(session(count));
          final gallery = StubGallery();
          await mount(tester, controller, gallery: gallery);
          expect(gallery.calls, 0);
          expect(tester.takeException(), isNull);
          if (count == 4) {
            await selectFrame(tester, 'classic-1200');
            await waitFor(
              tester,
              () => controller.draft.frameKey == 'classic-1200',
            );
            await selectFrame(tester, 'film-1200');
            await waitFor(
              tester,
              () => controller.draft.frameKey == 'film-1200',
            );
          }
          await tester.tap(find.text('Sticker'));
          await tester.pump();
          await tester.tap(
            find.byKey(const ValueKey('photobooth-sticker-animals/blue-bunny')),
          );
          await waitFor(
            tester,
            () =>
                controller.draft.stickers.isNotEmpty &&
                find.text('Đang xử lý…').evaluate().isEmpty,
          );
          final before = controller.draft.stickers.single.rotation;
          await tester.tap(find.byTooltip('Xoay sticker'));
          await tester.pump();
          expect(
            controller.draft.stickers.single.rotation,
            greaterThan(before),
          );
          await snapshot(tester, '${size.width.toInt()}_${count}_editing');
          await tester.tap(find.byTooltip('Xóa sticker'));
          await tester.pump();
          expect(controller.draft.stickers, isEmpty);
          await finish(tester);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Lưu về máy'));
          await tester.pumpAndSettle();
          expect(gallery.calls, 1);
          expect(
            find.text('Đã lưu ảnh vào thư viện của thiết bị.'),
            findsOneWidget,
          );
          await tester.runAsync(() async {
            final repaint =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await repaint.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('$root/${size.width.toInt()}_${count}_finished.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          await tester.tap(find.text('Tiếp tục chỉnh sửa'));
          await tester.pumpAndSettle();
          expect(find.text('Hoàn tất'), findsOneWidget);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          controller.dispose();
        },
      );
    }
  }

  testWidgets(
    'export/gallery failures stay visible and edits remain retryable',
    (tester) async {
      final exporter = StubExporter()..fail = true;
      final gallery = StubGallery()
        ..failure = const PhotoBoothException(
          'Bạn hãy cho phép lưu ảnh.',
          canOpenSettings: true,
        );
      final controller = PhotoBoothEditorController(session(2));
      await mount(tester, controller, exporter: exporter, gallery: gallery);
      await tester.tap(find.text('Hoàn tất'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Chưa xuất được ảnh.'), findsOneWidget);
      expect(find.textContaining('private directory'), findsNothing);
      exporter.fail = false;
      await finish(tester);
      await tester.tap(find.text('Lưu về máy'));
      await tester.pumpAndSettle();
      expect(find.text('Bạn hãy cho phép lưu ảnh.'), findsOneWidget);
      expect(find.text('Mở Cài đặt'), findsOneWidget);
      gallery.failure = null;
      await tester.tap(find.text('Lưu về máy'));
      await tester.pumpAndSettle();
      expect(gallery.calls, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('Home creates separate landscape and waits for explicit export', (
    tester,
  ) async {
    final controller = PhotoBoothEditorController(session(4));
    var uses = 0;
    await mount(
      tester,
      controller,
      onUseHome: (_) async {
        uses++;
        return false;
      },
    );
    await finish(tester);
    await tester.tap(find.text('Dùng làm nền Home'));
    await tester.pumpAndSettle();
    expect(controller.draft.frameKey, 'home-4');
    expect(uses, 0);
    await finish(tester);
    await tester.tap(find.text('Dùng làm nền Home'));
    await tester.pumpAndSettle();
    expect(uses, 1);
    expect(find.text('Lưu về máy'), findsOneWidget);
    await tester.tap(find.text('Tiếp tục chỉnh sửa'));
    await tester.pump();
    await tester.tap(find.text('Quay lại khung kỷ niệm'));
    await waitFor(tester, () => controller.draft.frameKey == 'classic-600');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'canvas gestures pan photos and move, pinch and rotate stickers',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = PhotoBoothEditorController(session(2));
      await mount(tester, controller);
      final canvas = find.byKey(const ValueKey('photobooth-editor-canvas'));
      final rect = tester.getRect(canvas);
      await tester.tapAt(Offset(rect.left + rect.width * .25, rect.center.dy));
      await tester.pump();
      await tester.drag(find.byType(Slider), const Offset(100, 0));
      await tester.pump();
      expect(controller.draft.photos[0]!.zoom, greaterThan(1));
      final oldX = controller.draft.photos[0]!.x;
      await tester.dragFrom(
        Offset(rect.left + rect.width * .25, rect.center.dy),
        const Offset(40, 20),
      );
      await tester.pump();
      expect(controller.draft.photos[0]!.x, isNot(oldX));
      await tester.tap(find.text('Sticker'));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('photobooth-sticker-animals/blue-bunny')),
      );
      await waitFor(
        tester,
        () =>
            controller.draft.stickers.isNotEmpty &&
            find.text('Đang xử lý…').evaluate().isEmpty,
      );
      final center = tester.getCenter(canvas);
      final old = controller.draft.stickers.single;
      final one = await tester.startGesture(
        center - const Offset(10, 0),
        pointer: 1,
      );
      final two = await tester.startGesture(
        center + const Offset(10, 0),
        pointer: 2,
      );
      await one.moveTo(center - const Offset(0, 25));
      await two.moveTo(center + const Offset(0, 25));
      await tester.pump();
      await one.up();
      await two.up();
      expect(controller.draft.stickers.single.width, isNot(old.width));
      expect(controller.draft.stickers.single.rotation.abs(), greaterThan(.1));
      final sticker = controller.draft.stickers.single;
      final bounds = tester.getRect(canvas);
      await tester.dragFrom(
        Offset(
          bounds.left + bounds.width * sticker.x,
          bounds.top + bounds.height * sticker.y,
        ),
        const Offset(40, 20),
      );
      await tester.pump();
      expect(controller.draft.stickers.single.x, isNot(sticker.x));
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'screen Back keeps draft across photo pool; profile removal closes large preview',
    (tester) async {
      rootBundle.evict('assets/photobooth/catalog.json');
      final files = FakeBoothFiles();
      final capture = PhotoBoothController(
        session: session(4),
        camera: FakeBoothCamera(),
        files: files,
      )..phase = CapturePhase.editing;
      final show = ValueNotifier(true);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: show,
            builder: (_, visible, _) => visible
                ? PhotoBoothScreen(
                    accountId: 'account',
                    childId: 'child',
                    controller: capture,
                  )
                : const Scaffold(body: Text('Hồ sơ khác')),
          ),
        ),
      );
      await waitFor(
        tester,
        () => find
            .byKey(const ValueKey('photobooth-editor-canvas'))
            .evaluate()
            .isNotEmpty,
      );
      final editor = tester
          .state<PhotoBoothEditorEntryState>(find.byType(PhotoBoothEditorEntry))
          .editor;
      editor.setPhoto(0, const PhotoBoothPhotoTransform(zoom: 2));
      await tester.pump();
      await tester.tap(find.byTooltip('Đóng Photobooth'));
      await tester.pumpAndSettle();
      expect(find.text('Chỉnh sửa chưa xuất'), findsOneWidget);
      await tester.tap(find.text('Quay lại'));
      await tester.pumpAndSettle();
      expect(capture.phase, CapturePhase.reviewing);
      await tester.tap(find.text('Trang trí ảnh'));
      await waitFor(
        tester,
        () => find
            .byKey(const ValueKey('photobooth-editor-canvas'))
            .evaluate()
            .isNotEmpty,
      );
      expect(
        tester
            .state<PhotoBoothEditorEntryState>(
              find.byType(PhotoBoothEditorEntry),
            )
            .editor,
        same(editor),
      );
      expect(editor.draft.photos[0]!.zoom, 2);
      await tester.tap(find.byTooltip('Xem ảnh lớn'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Đóng ảnh lớn'), findsOneWidget);
      show.value = false;
      await tester.pumpAndSettle();
      expect(find.byTooltip('Đóng ảnh lớn'), findsNothing);
      expect(find.text('Hồ sơ khác'), findsOneWidget);
      expect(files.cleared, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      show.dispose();
    },
  );

  testWidgets(
    'workspace reserves more space and divider resizes without changing the draft',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final controller = PhotoBoothEditorController(session(4));
      await mount(tester, controller);
      final preview = find.byKey(const ValueKey('photobooth-preview-area'));
      final library = find.byKey(const ValueKey('photobooth-library-panel'));
      final libraryWidget = tester.widget(library);
      final beforePreview = tester.getSize(preview).height;
      final beforeLibrary = tester.getSize(library).height;
      expect(beforePreview, greaterThan(200));
      expect(beforeLibrary, greaterThanOrEqualTo(140));
      expect(find.text('Chạm ảnh hoặc sticker để chỉnh.'), findsNothing);
      final fingerprint = controller.draft.fingerprint;
      await tester.drag(
        find.byKey(const ValueKey('photobooth-preview-resize')),
        const Offset(0, -60),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(preview).height, lessThan(beforePreview));
      expect(tester.getSize(library).height, greaterThan(beforeLibrary));
      expect(controller.draft.fingerprint, fingerprint);
      expect(tester.widget(library), same(libraryWidget));
      expect(find.text('Hoàn tất').hitTestable(), findsOneWidget);
      await snapshot(tester, '320_library_expanded');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'new catalog category, name and format appear without changing the UI',
    (tester) async {
      rootBundle.evict('assets/photobooth/catalog.json');
      final base = (await tester.runAsync(() => PhotoBoothCatalog.load()))!;
      final template = base.frame('classic-600', 4);
      final extension = PhotoBoothCatalog.fromJson({
        'frames': [
          {
            'key': 'orbit-custom',
            'theme': 'space',
            'title': 'Trời sao',
            'categoryTitle': 'Vũ trụ',
            'format': 'Khổ mới',
            'asset': template.asset,
            'width': 600,
            'height': 1800,
            'slots': [
              for (final slot in template.slots)
                {
                  'x': slot.rect.left,
                  'y': slot.rect.top,
                  'width': slot.rect.width,
                  'height': slot.rect.height,
                  'photo': slot.photo,
                },
            ],
          },
        ],
        'stickers': [],
      });
      final catalog = PhotoBoothCatalog([
        base.frame('birthday-600', 4),
        ...extension.frames,
      ], base.stickers);
      final controller = PhotoBoothEditorController(session(4));
      await mount(tester, controller, catalog: catalog);
      final category = find.byKey(
        const ValueKey('photobooth-frame-category-space'),
      );
      await tester.scrollUntilVisible(
        category,
        140,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('photobooth-library-panel')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(category);
      await tester.pumpAndSettle();
      expect(find.text('Trời sao'), findsOneWidget);
      expect(find.text('Khổ mới'), findsOneWidget);
      await selectFrame(tester, 'orbit-custom');
      await waitFor(tester, () => controller.draft.frameKey == 'orbit-custom');
      expect(controller.session.selectedPhotos, hasLength(4));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'moving a sticker or photo keeps the library stable and only repaints its own layer',
    (tester) async {
      final controller = PhotoBoothEditorController(session(2));
      await mount(tester, controller);
      await tester.tap(find.text('Sticker'));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('photobooth-sticker-animals/blue-bunny')),
      );
      await waitFor(
        tester,
        () =>
            controller.draft.stickers.isNotEmpty &&
            find.text('Hoàn tất').evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      final library = find.byKey(const ValueKey('photobooth-library-panel'));
      final originalLibrary = tester.widget(library);
      final originalCanvas = tester.widget(
        find.byKey(const ValueKey('photobooth-editor-canvas')),
      );
      RenderRepaintBoundary layer(String name) =>
          tester.renderObject<RenderRepaintBoundary>(
            find.byKey(ValueKey('photobooth-preview-$name')),
          );
      for (var i = 0; i < 30; i++) {
        final sticker = controller.draft.stickers.single;
        controller.changeSticker(
          PhotoBoothSticker(
            id: sticker.id,
            assetKey: sticker.assetKey,
            x: .35 + i * .005,
            y: .5,
            width: sticker.width,
            rotation: i * .01,
          ),
        );
        expect(layer('photos').debugNeedsPaint, isFalse);
        expect(layer('frame').debugNeedsPaint, isFalse);
        expect(layer('stickers').debugNeedsPaint, isTrue);
        await tester.pump();
        expect(tester.widget(library), same(originalLibrary));
        expect(
          tester.widget(find.byKey(const ValueKey('photobooth-editor-canvas'))),
          same(originalCanvas),
        );
      }
      for (var i = 0; i < 30; i++) {
        controller.setPhoto(
          0,
          PhotoBoothPhotoTransform(x: .5, y: .5, zoom: 1.1 + i * .02),
        );
        expect(layer('photos').debugNeedsPaint, isTrue);
        expect(layer('frame').debugNeedsPaint, isFalse);
        expect(layer('stickers').debugNeedsPaint, isFalse);
        await tester.pump();
        expect(tester.widget(library), same(originalLibrary));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('dirty draft confirmation keeps edits on return and cancel', (
    tester,
  ) async {
    final controller = PhotoBoothEditorController(session(2));
    var returned = 0;
    await mount(tester, controller, onBack: () => returned++);
    controller.setPhoto(0, const PhotoBoothPhotoTransform(zoom: 2));
    await tester.pump();
    await tester.tap(find.byTooltip('Quay lại bộ ảnh'));
    await tester.pumpAndSettle();
    expect(find.text('Chỉnh sửa chưa xuất'), findsOneWidget);
    await tester.tap(find.text('Ở lại'));
    await tester.pumpAndSettle();
    expect(returned, 0);
    await tester.tap(find.byTooltip('Quay lại bộ ảnh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();
    expect(returned, 1);
    expect(controller.draft.photos[0]!.zoom, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'four-photo Home layout chooses two highlights without changing the strip',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final controller = PhotoBoothEditorController(session(4));
      final initialSession = controller.session;
      final strip = controller.draft.fingerprint;
      await mount(tester, controller);
      await finish(tester);
      await tester.tap(find.text('Dùng làm nền Home'));
      await tester.pumpAndSettle();
      expect(controller.homePhotoIndices, [0, 1, 2, 3]);
      await tester.tap(find.byKey(const ValueKey('photobooth-home-layout-2')));
      await tester.pump();
      for (final index in [2, 3]) {
        final choice = find.byKey(ValueKey('photobooth-home-photo-$index'));
        await tester.ensureVisible(choice);
        await tester.pumpAndSettle();
        await tester.tap(choice);
        await tester.pump();
      }
      expect(controller.homePhotoIndices, [2, 3]);
      expect(identical(controller.session, initialSession), isTrue);
      final homeScroll = find
          .descendant(
            of: find.byKey(const ValueKey('photobooth-home-layouts')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('photobooth-home-layout-4')),
        -80,
        scrollable: homeScroll,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('photobooth-home-layout-4')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('photobooth-home-layout-4')));
      await tester.pump();
      expect(controller.homePhotoIndices, [0, 1, 2, 3]);
      await tester.tap(find.byKey(const ValueKey('photobooth-home-layout-2')));
      await tester.pump();
      expect(controller.homePhotoIndices, [2, 3]);
      final back = find.text('Quay lại khung kỷ niệm');
      await tester.scrollUntilVisible(back, 80, scrollable: homeScroll);
      await tester.ensureVisible(back);
      await tester.pumpAndSettle();
      await tester.tap(back);
      await waitFor(tester, () => !controller.home);
      expect(controller.draft.fingerprint, strip);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
