import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:track_children/app_colors.dart';
import 'package:track_children/features/home/background/background_draft.dart';
import 'package:track_children/features/photobooth/photobooth_edit.dart';
import 'package:track_children/features/photobooth/photobooth_catalog.dart';
import 'package:track_children/features/photobooth/photobooth_controller.dart';
import 'package:track_children/features/photobooth/photobooth_editor_entry.dart';
import 'package:track_children/features/photobooth/photobooth_export.dart';
import 'package:track_children/features/photobooth/photobooth_renderer.dart';
import 'package:track_children/features/photobooth/photobooth_session.dart';
import 'package:track_children/features/photobooth/photobooth_text.dart';
import 'package:track_children/features/photobooth/photobooth_text_composer.dart';
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
  Completer<void>? gate;
  PhotoBoothException? failure;
  @override
  Future<void> save(String path) async {
    calls++;
    if (gate != null) await gate!.future;
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
    final editorKey = key ?? GlobalKey<PhotoBoothEditorEntryState>();
    final completion = ValueNotifier<PhotoBoothCompletionStatus>((
      completed: false,
      busy: false,
    ));
    addTearDown(completion.dispose);
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
            appBar: AppBar(
              title: const Text('Trang trí ảnh'),
              actions: [
                ValueListenableBuilder<PhotoBoothCompletionStatus>(
                  valueListenable: completion,
                  builder: (_, status, _) => PhotoBoothContinueEditingAction(
                    status: status,
                    onPressed: () => editorKey.currentState?.continueEditing(),
                  ),
                ),
              ],
            ),
            body: SafeArea(
              top: false,
              child: PhotoBoothEditorEntry(
                key: editorKey,
                onCompletionChanged: (status) => completion.value = status,
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
    for (final count in [1, 2, 3, 4]) {
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
          expect(find.text('Đã lưu ảnh vào thư viện!'), findsOneWidget);
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
          await tester.tap(find.byTooltip('Tiếp tục chỉnh sửa'));
          await tester.pumpAndSettle();
          expect(find.text('Hoàn tất'), findsOneWidget);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          controller.dispose();
        },
      );
    }
  }

  for (final specimen in const [
    (Size(320, 568), 1.3),
    (Size(393, 852), 1.3),
    (Size(320, 568), 1.8),
  ]) {
    testWidgets(
      '${specimen.$1.width} text ${specimen.$2}: completion actions and prominent save status remain usable',
      (tester) async {
        tester.view.physicalSize = specimen.$1;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
        tester.platformDispatcher.textScaleFactorTestValue = specimen.$2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final controller = PhotoBoothEditorController(session(2));
        final gallery = StubGallery()..gate = Completer<void>();
        await mount(tester, controller, gallery: gallery);
        await finish(tester);
        final save = find.widgetWithText(FilledButton, 'Lưu về máy');
        final home = find.widgetWithText(OutlinedButton, 'Dùng làm nền Home');
        expect(tester.getRect(save).top, tester.getRect(home).top);
        expect(tester.getRect(save).right, lessThan(tester.getRect(home).left));
        expect(find.text('Đã lưu ảnh vào thư viện!'), findsNothing);
        await tester.tap(save);
        await tester.pump();
        expect(gallery.calls, 1);
        expect(tester.widget<FilledButton>(save).onPressed, isNull);
        expect(tester.widget<OutlinedButton>(home).onPressed, isNull);
        expect(find.bySemanticsLabel(RegExp('Đang lưu ảnh')), findsOneWidget);
        final edit = find.byKey(const ValueKey('photobooth-continue-editing'));
        expect(tester.widget<IconButton>(edit).onPressed, isNull);
        expect(find.text('Quay lại chọn ảnh'), findsNothing);
        gallery.gate!.complete();
        await waitFor(
          tester,
          () => find.text('Đã lưu ảnh vào thư viện!').evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Đã lưu ảnh vào thư viện!').hitTestable(),
          findsOneWidget,
        );
        final status = find.byKey(const ValueKey('photobooth-status-message'));
        expect(
          tester.getRect(status).bottom,
          lessThanOrEqualTo(
            tester
                .getRect(find.byKey(const ValueKey('photobooth-editor-canvas')))
                .top,
          ),
        );
        expect(
          find.descendant(of: find.byType(AppBar), matching: edit),
          findsOneWidget,
        );
        expect(
          tester.getRect(edit).bottom,
          lessThanOrEqualTo(tester.getRect(status).top),
        );
        expect(find.text('Quay lại chọn ảnh'), findsNothing);
        expect(
          find.widgetWithText(TextButton, 'Tiếp tục chỉnh sửa'),
          findsNothing,
        );
        if (specimen.$2 == 1.3) {
          expect(tester.getSize(save).height, lessThan(90));
        }
        await snapshot(
          tester,
          '${specimen.$1.width.toInt()}_completion_saved_${specimen.$2}',
        );
        if (specimen.$2 == 1.3) {
          expect(edit.hitTestable(), findsOneWidget);
        }
        await tester.ensureVisible(find.byTooltip('Tiếp tục chỉnh sửa'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Tiếp tục chỉnh sửa'));
        await tester.pumpAndSettle();
        expect(find.text('Hoàn tất'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('photobooth-status-message')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      },
    );
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

  testWidgets(
    'Home opens the next step with the finished artwork and preserves its frame',
    (tester) async {
      final controller = PhotoBoothEditorController(session(4));
      final exporter = StubExporter();
      var uses = 0;
      await mount(
        tester,
        controller,
        exporter: exporter,
        onUseHome: (_) async {
          uses++;
          return false;
        },
      );
      await finish(tester);
      final strip = controller.draft.fingerprint;
      await tester.tap(find.text('Dùng làm nền Home'));
      await tester.pumpAndSettle();
      expect(controller.draft.frameKey, 'classic-600');
      expect(uses, 1);
      expect(exporter.calls, 1);
      expect(controller.draft.fingerprint, strip);
      expect(controller.stripDraft, isNull);
      expect(find.text('Lưu về máy'), findsOneWidget);
      await tester.tap(find.byTooltip('Tiếp tục chỉnh sửa'));
      await tester.pump();
      expect(controller.draft.frameKey, 'classic-600');
      expect(controller.draft.fingerprint, strip);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'Home export failure never hands off the old memento and retries safely',
    (tester) async {
      final controller = PhotoBoothEditorController(session(4));
      final exporter = StubExporter();
      var uses = 0;
      var failApply = true;
      await mount(
        tester,
        controller,
        exporter: exporter,
        onUseHome: (_) async {
          uses++;
          if (failApply) {
            throw const BackgroundImageException(
              'Không đọc được ảnh nền thử nghiệm.',
            );
          }
          return false;
        },
      );
      await finish(tester);
      controller.addText(
        'Nội dung vừa thay đổi',
        const PhotoBoothFrame(
          key: 'test',
          theme: 'classic',
          size: Size(600, 1800),
          slots: [],
        ),
      );
      final strip = controller.draft.fingerprint;
      exporter.fail = true;
      await tester.tap(find.text('Dùng làm nền Home'));
      await tester.pumpAndSettle();
      expect(uses, 0);
      expect(exporter.calls, 2);
      expect(find.textContaining('Chưa xuất được ảnh.'), findsOneWidget);
      expect(controller.draft.fingerprint, strip);
      expect(controller.draft.frameKey, 'classic-600');
      exporter.fail = false;
      await tester.tap(find.text('Dùng làm nền Home'));
      await tester.pumpAndSettle();
      expect(uses, 1);
      expect(exporter.calls, 3);
      expect(find.text('Không đọc được ảnh nền thử nghiệm.'), findsOneWidget);
      failApply = false;
      await tester.tap(find.text('Dùng làm nền Home'));
      await tester.pumpAndSettle();
      expect(uses, 2);
      expect(exporter.calls, 3);
      expect(find.text('Không đọc được ảnh nền thử nghiệm.'), findsNothing);
      expect(find.text('Dùng làm nền Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

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
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byTooltip('Quay lại chọn ảnh'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Quay lại chọn ảnh?'), findsOneWidget);
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
      final caption = controller.addText('Bé yêu', PhotoBoothFrame.home(2))!;
      await tester.pump();
      final textLibrary = tester.widget(library);
      final textCanvas = tester.widget(
        find.byKey(const ValueKey('photobooth-editor-canvas')),
      );
      for (var i = 0; i < 30; i++) {
        controller.changeText(
          caption.move(
            PhotoBoothFrame.home(2).size,
            x: .3 + i * .01,
            rotation: i * .01,
          ),
        );
        expect(layer('photos').debugNeedsPaint, isFalse);
        expect(layer('frame').debugNeedsPaint, isFalse);
        expect(layer('stickers').debugNeedsPaint, isFalse);
        expect(layer('texts').debugNeedsPaint, isTrue);
        await tester.pump();
        expect(tester.widget(library), same(textLibrary));
        expect(
          tester.widget(find.byKey(const ValueKey('photobooth-editor-canvas'))),
          same(textCanvas),
        );
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
    await tester.tap(find.byTooltip('Quay lại chọn ảnh'));
    await tester.pumpAndSettle();
    expect(find.text('Quay lại chọn ảnh?'), findsOneWidget);
    await tester.tap(find.text('Sửa tiếp'));
    await tester.pumpAndSettle();
    expect(returned, 0);
    await tester.tap(find.byTooltip('Quay lại chọn ảnh'));
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
      await selectFrame(tester, 'home-4');
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

  testWidgets(
    'new collections and shape filter show compatible frames for one photo',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final controller = PhotoBoothEditorController(session(1));
      await mount(tester, controller);
      await tester.tap(
        find.byKey(const ValueKey('photobooth-frame-shape-filter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Khung vuông'));
      await tester.pumpAndSettle();
      final grid = tester.widget<GridView>(
        find.byKey(const ValueKey('photobooth-frame-grid')),
      );
      expect(grid.childrenDelegate.estimatedChildCount, 5);
      await selectFrame(tester, 'birthday-kids-5x5-01');
      await waitFor(
        tester,
        () => controller.draft.frameKey == 'birthday-kids-5x5-01',
      );
      expect(controller.session.selectedPhotos, hasLength(1));
      await snapshot(tester, 'new_frames_square_320');
      await finish(tester);
      await tester.tap(find.text('Dùng làm nền Home'));
      await tester.pumpAndSettle();
      expect(controller.home, isFalse);
      await tester.tap(find.byTooltip('Tiếp tục chỉnh sửa'));
      await tester.pumpAndSettle();
      expect(controller.draft.frameKey, 'birthday-kids-5x5-01');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  for (final size in const [Size(320, 568), Size(393, 852)]) {
    for (final count in [1, 2]) {
      testWidgets(
        '${size.width}: Belonkhon $count-photo frames and nested stickers',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final controller = PhotoBoothEditorController(session(count));
          await mount(tester, controller);
          final category = find.byKey(
            const ValueKey('photobooth-frame-category-belonkhon'),
          );
          await tester.ensureVisible(category);
          await tester.pumpAndSettle();
          await tester.tap(category);
          await tester.pumpAndSettle();
          final grid = tester.widget<GridView>(
            find.byKey(const ValueKey('photobooth-frame-grid')),
          );
          expect(grid.childrenDelegate.estimatedChildCount, 3);
          final frameKey = 'belonkhon-scrapbook-${count}photo';
          await selectFrame(tester, frameKey);
          await waitFor(
            tester,
            () =>
                controller.draft.frameKey == frameKey &&
                find.text('Đang xử lý…').evaluate().isEmpty,
          );
          expect(find.text('6:4'), findsWidgets);
          await snapshot(
            tester,
            '${size.width.toInt()}_belonkhon_${count}_frames',
          );
          await tester.tap(find.text('Sticker'));
          await tester.pump();
          await tester.tap(find.text('Bé Lớn Khôn'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<GridView>(find.byType(GridView))
                .childrenDelegate
                .estimatedChildCount,
            45,
          );
          await snapshot(
            tester,
            '${size.width.toInt()}_belonkhon_${count}_stickers',
          );
          for (final group in ['mascot', 'care']) {
            final tile = find.byKey(
              ValueKey('photobooth-sticker-belonkhon/$group/milk_bottle'),
            );
            await tester.scrollUntilVisible(
              tile,
              80,
              scrollable: find.descendant(
                of: find.byType(GridView),
                matching: find.byType(Scrollable),
              ),
            );
            await tester.ensureVisible(tile);
            await tester.pumpAndSettle();
            await tester.tap(tile);
            await waitFor(
              tester,
              () =>
                  controller.draft.stickers.length ==
                      (group == 'mascot' ? 1 : 2) &&
                  find.text('Đang xử lý…').evaluate().isEmpty,
            );
          }
          expect(
            controller.draft.stickers.map((s) => s.assetKey).toSet(),
            hasLength(2),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
        },
      );
    }
    testWidgets(
      '${size.width}: simple text edits on the photo, selects the correct caption and styles its background',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final controller = PhotoBoothEditorController(session(2));
        final exporter = StubExporter();
        await mount(tester, controller, exporter: exporter);
        final initial = controller.draft.fingerprint;
        final input = find.byKey(const ValueKey('photobooth-text-input'));
        final confirm = find.byKey(const ValueKey('photobooth-text-confirm'));
        final cancel = find.byKey(const ValueKey('photobooth-text-cancel'));
        final canvas = find.byKey(const ValueKey('photobooth-editor-canvas'));
        PhotoBoothPainter pendingPainter() =>
            tester
                    .widget<CustomPaint>(
                      find.byKey(const ValueKey('photobooth-text-edit-texts')),
                    )
                    .painter!
                as PhotoBoothPainter;
        Offset point(double x, double y) {
          final rect = tester.getRect(canvas);
          return Offset(rect.left + x * rect.width, rect.top + y * rect.height);
        }

        Future<void> tapPoint(Offset at, {bool twice = false}) async {
          await tester.tapAt(at);
          if (twice) {
            await tester.pump(const Duration(milliseconds: 80));
            await tester.tapAt(at);
          }
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();
        }

        Future<void> tapCaption(PhotoBoothText text, {bool twice = false}) =>
            tapPoint(point(text.x, text.y), twice: twice);
        Future<void> choose(bool background, int color) async {
          await tester.tap(
            find.byKey(
              ValueKey(
                background
                    ? 'photobooth-text-background-tool'
                    : 'photobooth-text-color-tool',
              ),
            ),
          );
          await tester.pumpAndSettle();
          final chip = find.byKey(
            ValueKey(
              'photobooth-text-${background ? 'background-color' : 'color'}-$color',
            ),
          );
          await tester.ensureVisible(chip);
          await tester.pumpAndSettle();
          await tester.tap(chip);
          await tester.pump();
        }

        await tester.tap(find.text('Chữ'));
        await tester.pumpAndSettle();
        expect(input, findsOneWidget);
        expect(find.byKey(const ValueKey('photobooth-add-text')), findsNothing);
        expect(find.byType(BottomSheet), findsNothing);
        expect(controller.draft.fingerprint, initial);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(find.text('Bạn hãy nhập nội dung chữ.'), findsOneWidget);
        const content = 'Bé yêu của mẹ\n15.11.2026';
        await tester.enterText(input, content);
        await tester.pumpAndSettle();
        expect(controller.draft.texts, isEmpty);
        expect(pendingPainter().draft.texts.single.text, content);
        tester.view.viewInsets = const FakeViewPadding(bottom: 220);
        await tester.pumpAndSettle();
        final editCanvas = tester.getRect(
          find.byKey(const ValueKey('photobooth-text-edit-canvas')),
        );
        expect(
          tester.getRect(input).center.dy,
          inInclusiveRange(editCanvas.top, editCanvas.bottom),
        );
        expect(
          tester.getRect(confirm).bottom,
          lessThanOrEqualTo(size.height - 220),
        );
        await snapshot(tester, '${size.width.toInt()}_simple_text_keyboard');
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        expect(input, findsNothing);
        expect(controller.draft.texts.single.text, content);
        final firstId = controller.draft.texts.single.id;
        expect(find.byTooltip('Xoay chữ'), findsOneWidget);
        expect(find.text('Màu viền chữ'), findsNothing);
        expect(PhotoBoothTextComposer.colors, hasLength(16));

        await choose(false, 0xFFE96392);
        await choose(true, 0xFF317EC1);
        expect(controller.draft.texts.single.color, 0xFFE96392);
        expect(controller.draft.texts.single.effectiveBorderColor, 0xFFE96392);
        expect(controller.draft.texts.single.backgroundColor, 0xFF317EC1);
        await choose(true, 0);
        expect(controller.draft.texts.single.backgroundColor, 0);
        await choose(true, 0xFF317EC1);

        final slider = find.byKey(const ValueKey('photobooth-text-size'));
        await tester.ensureVisible(slider);
        await tester.pumpAndSettle();
        final beforePhoto = tester.widget(
          find.byKey(const ValueKey('photobooth-preview-photos')),
        );
        final before = controller.draft.texts.single.fontSize;
        final resizing = await tester.startGesture(tester.getCenter(slider));
        await resizing.moveBy(const Offset(30, 0));
        await tester.pump();
        final larger = controller.draft.texts.single.fontSize;
        expect(larger, greaterThan(before));
        await resizing.moveBy(const Offset(-10, 0));
        await tester.pump();
        await resizing.up();
        expect(controller.draft.texts.single.fontSize, lessThan(larger));
        expect(
          tester.widget(
            find.byKey(const ValueKey('photobooth-preview-photos')),
          ),
          same(beforePhoto),
        );

        await tapPoint(point(.18, .18));
        expect(input, findsNothing);
        expect(controller.draft.texts, hasLength(1));
        await tapPoint(point(.18, .18), twice: true);
        await tester.enterText(input, 'Bỏ đoạn mới');
        await tester.pump();
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(controller.draft.texts, hasLength(1));
        await tapPoint(point(.18, .18), twice: true);
        await tester.enterText(input, 'Chữ thứ hai');
        await tester.pump();
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(controller.draft.texts, hasLength(2));
        final second = controller.draft.texts.last;
        final first = controller.draft.texts.firstWhere(
          (text) => text.id == firstId,
        );
        await tapCaption(first);
        expect(input, findsNothing);
        expect(
          tester
              .widget<PhotoBoothTextComposer>(
                find.byType(PhotoBoothTextComposer),
              )
              .value!
              .id,
          firstId,
        );
        await choose(false, 0xFFA8DBC3);
        await choose(true, 0xFF23332E);
        expect(controller.draft.texts.first.color, 0xFFA8DBC3);
        expect(controller.draft.texts.first.backgroundColor, 0xFF23332E);
        expect(controller.draft.texts.last.toJson(), second.toJson());
        await snapshot(tester, '${size.width.toInt()}_simple_text_colors');

        await tester.tap(find.text('Khung'));
        await tester.pumpAndSettle();
        await tapCaption(second, twice: true);
        expect(tester.widget<TextField>(input).controller!.text, second.text);
        final unchanged = controller.draft.fingerprint;
        final firstUnchanged = controller.draft.texts.first.toJson();
        await tester.enterText(input, 'Không lưu');
        await tester.pump();
        expect(pendingPainter().draft.texts.last.text, 'Không lưu');
        expect(controller.draft.fingerprint, unchanged);
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(controller.draft.fingerprint, unchanged);
        await tapCaption(second, twice: true);
        await tester.enterText(input, 'Nội dung đã sửa');
        await tester.pump();
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(controller.draft.texts.last.id, second.id);
        expect(controller.draft.texts.last.text, 'Nội dung đã sửa');
        expect(controller.draft.texts.first.toJson(), firstUnchanged);

        final moving = controller.draft.texts.last;
        await tester.dragFrom(point(moving.x, moving.y), const Offset(35, 30));
        await tester.pumpAndSettle();
        expect(controller.draft.texts.last.x, greaterThan(moving.x));
        final moved = controller.draft.texts.last;
        final center = point(moved.x, moved.y);
        final one = await tester.startGesture(
          center - const Offset(8, 0),
          pointer: 1,
        );
        final two = await tester.startGesture(
          center + const Offset(8, 0),
          pointer: 2,
        );
        await one.moveTo(center - const Offset(0, 25));
        await two.moveTo(center + const Offset(0, 25));
        await tester.pump();
        final enlarged = controller.draft.texts.last.fontSize;
        expect(enlarged, greaterThan(moved.fontSize));
        expect(enlarged, lessThanOrEqualTo(.16));
        await one.moveTo(center - const Offset(0, 12));
        await two.moveTo(center + const Offset(0, 12));
        await tester.pump();
        expect(controller.draft.texts.last.fontSize, lessThan(enlarged));
        await one.up();
        await two.up();
        await tester.pumpAndSettle();
        expect(
          controller.draft.texts.last.fontSize,
          inInclusiveRange(.025, .16),
        );
        expect(controller.draft.texts.last.color, moved.color);
        expect(
          controller.draft.texts.last.backgroundColor,
          moved.backgroundColor,
        );
        expect(
          tester.widget<Slider>(slider).value,
          controller.draft.texts.last.fontSize,
        );
        expect(
          (controller.draft.texts.last.rotation - moved.rotation).abs(),
          greaterThan(.1),
        );
        expect(controller.draft.texts.first.toJson(), firstUnchanged);
        await finish(tester);
        expect(exporter.calls, 1);
        await tester.tap(find.byTooltip('Tiếp tục chỉnh sửa'));
        await tester.pumpAndSettle();
        await tapCaption(controller.draft.texts.first);
        final remove = find.descendant(
          of: find.byKey(const ValueKey('photobooth-text-quick-toolbar')),
          matching: find.byTooltip('Xóa chữ'),
        );
        await tester.ensureVisible(remove);
        await tester.tap(remove);
        await tester.pumpAndSettle();
        expect(controller.draft.texts.single.id, second.id);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      },
    );
  }

  for (final size in const [Size(320, 568), Size(393, 852)]) {
    testWidgets(
      '${size.width}: text quick toolbar styles, edits, raises and deletes only the selected caption',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final controller = PhotoBoothEditorController(session(2));
        final frame = PhotoBoothFrame.home(2);
        final first = controller.addText(
          'Bé yêu',
          frame,
          color: 0xFFE96392,
          backgroundColor: 0xFF23332E,
        )!;
        controller.changeText(first.move(frame.size, x: .28, y: .35));
        final second = controller.addText('Gia đình', frame)!;
        controller.changeText(second.move(frame.size, x: .75, y: .35));
        final secondUnchanged = controller.draft.texts.last.toJson();
        await mount(tester, controller);
        final toolbar = find.byKey(
          const ValueKey('photobooth-text-quick-toolbar'),
        );
        final panel = find.byKey(const ValueKey('photobooth-text-panel'));
        Finder action(String label) =>
            find.descendant(of: toolbar, matching: find.byTooltip(label));
        PhotoBoothText caption(int id) =>
            controller.draft.texts.firstWhere((text) => text.id == id);
        Future<void> select(int id) async {
          final text = caption(id);
          final canvas = tester.getRect(
            find.byKey(const ValueKey('photobooth-editor-canvas')),
          );
          await tester.tapAt(
            Offset(
              canvas.left + text.x * canvas.width,
              canvas.top + text.y * canvas.height,
            ),
          );
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();
        }

        await select(first.id);
        expect(toolbar, findsOneWidget);
        expect(panel, findsOneWidget);
        expect(
          find.byKey(const ValueKey('photobooth-text-input')),
          findsNothing,
        );
        expect(find.byTooltip('Xoay chữ'), findsOneWidget);
        expect(find.byTooltip('Thu nhỏ chữ'), findsNothing);
        expect(find.byTooltip('Phóng to chữ'), findsNothing);
        expect(
          find.descendant(of: panel, matching: find.byTooltip('Xóa chữ')),
          findsNothing,
        );
        expect(find.byTooltip('Xóa chữ'), findsOneWidget);
        expect(
          tester.getRect(toolbar).bottom,
          lessThanOrEqualTo(tester.getRect(panel).top),
        );
        for (final label in [
          'Thêm chữ',
          'Sửa chữ',
          'Xoay chữ',
          'Đưa chữ lên trên',
          'Xóa chữ',
          'Ẩn công cụ',
        ]) {
          expect(action(label).hitTestable(), findsOneWidget);
        }
        await snapshot(tester, '${size.width.toInt()}_text_quick_toolbar');
        final photo = tester.widget(
          find.byKey(const ValueKey('photobooth-preview-photos')),
        );
        final before = caption(first.id);
        await tester.tap(action('Xoay chữ'));
        await tester.pump();
        expect(
          caption(first.id).rotation,
          closeTo(before.rotation + math.pi / 12, 1e-9),
        );
        expect(caption(first.id).fontSize, before.fontSize);
        expect(caption(first.id).color, first.color);
        expect(caption(first.id).backgroundColor, first.backgroundColor);
        expect(caption(second.id).toJson(), secondUnchanged);
        expect(
          tester.widget(
            find.byKey(const ValueKey('photobooth-preview-photos')),
          ),
          same(photo),
        );
        await tester.tap(action('Sửa chữ'));
        await tester.pumpAndSettle();
        final input = find.byKey(const ValueKey('photobooth-text-input'));
        expect(tester.widget<TextField>(input).controller!.text, first.text);
        for (final key in [
          'photobooth-text-input-rotation',
          'photobooth-text-selection-rotation',
        ]) {
          final transform = tester
              .widget<Transform>(find.byKey(ValueKey(key)))
              .transform;
          expect(
            math.atan2(transform.entry(1, 0), transform.entry(0, 0)),
            closeTo(caption(first.id).rotation, 1e-9),
          );
        }
        await snapshot(tester, '${size.width.toInt()}_rotated_text_edit');
        await tester.enterText(input, 'Sửa nhanh');
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('photobooth-text-cancel')));
        await tester.pumpAndSettle();
        expect(caption(first.id).text, first.text);
        expect(toolbar, findsOneWidget);
        await tester.tap(action('Sửa chữ'));
        await tester.pumpAndSettle();
        await tester.enterText(input, 'Sửa nhanh');
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('photobooth-text-confirm')));
        await tester.pumpAndSettle();
        expect(caption(first.id).text, 'Sửa nhanh');
        expect(caption(second.id).toJson(), secondUnchanged);
        await tester.tap(action('Đưa chữ lên trên'));
        await tester.pump();
        expect(controller.draft.texts.last.id, first.id);
        expect(
          tester
              .widget<PhotoBoothTextComposer>(
                find.byType(PhotoBoothTextComposer),
              )
              .value!
              .id,
          first.id,
        );
        final firstUnchanged = caption(first.id).toJson();
        await tester.tap(action('Ẩn công cụ'));
        await tester.pumpAndSettle();
        expect(toolbar, findsNothing);
        expect(panel, findsOneWidget);
        await select(second.id);
        await tester.tap(action('Xoay chữ'));
        await tester.pump();
        expect(caption(second.id).rotation, greaterThan(second.rotation));
        expect(caption(second.id).fontSize, second.fontSize);
        expect(caption(first.id).toJson(), firstUnchanged);
        await tester.tap(action('Xóa chữ'));
        await tester.pumpAndSettle();
        expect(controller.draft.texts.single.id, first.id);
        expect(toolbar, findsNothing);
        await select(first.id);
        final beforeAdding = controller.draft.fingerprint;
        await tester.tap(action('Thêm chữ'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(input).controller!.text, isEmpty);
        await tester.enterText(input, 'Đoạn mới chưa lưu');
        await tester.pump();
        expect(controller.draft.fingerprint, beforeAdding);
        await tester.tap(find.byKey(const ValueKey('photobooth-text-cancel')));
        await tester.pumpAndSettle();
        expect(controller.draft.fingerprint, beforeAdding);
        expect(toolbar, findsOneWidget);
        expect(
          tester
              .widget<PhotoBoothTextComposer>(
                find.byType(PhotoBoothTextComposer),
              )
              .value!
              .id,
          first.id,
        );
        await tester.tap(action('Thêm chữ'));
        await tester.pumpAndSettle();
        await tester.enterText(input, 'Đoạn mới');
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('photobooth-text-confirm')));
        await tester.pumpAndSettle();
        expect(controller.draft.texts, hasLength(2));
        expect(controller.draft.texts.last.text, 'Đoạn mới');
        expect(controller.draft.texts.last.id, isNot(first.id));
        expect(caption(first.id).toJson(), firstUnchanged);
        expect(
          tester
              .widget<PhotoBoothTextComposer>(
                find.byType(PhotoBoothTextComposer),
              )
              .value!
              .id,
          controller.draft.texts.last.id,
        );
        while (controller.draft.texts.length < 8) {
          controller.addText(
            'Đoạn ${controller.draft.texts.length + 1}',
            frame,
          );
        }
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<IconButton>(
                find.byKey(const ValueKey('photobooth-quick-add-text')),
              )
              .onPressed,
          isNull,
        );
        await finish(tester);
        expect(toolbar, findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      },
    );
  }

  for (final size in const [Size(320, 568), Size(393, 852)]) {
    testWidgets(
      '${size.width}: quick undo restores deletions, grouped gestures and text sliders',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final controller = PhotoBoothEditorController(session(2));
        await mount(tester, controller);
        final undo = find.byKey(const ValueKey('photobooth-quick-undo'));
        expect(undo.hitTestable(), findsOneWidget);
        expect(tester.widget<IconButton>(undo).onPressed, isNull);
        final initial = controller.draft.fingerprint;
        Future<void> undoTo(String fingerprint) async {
          await tester.tap(undo);
          await waitFor(
            tester,
            () =>
                controller.draft.fingerprint == fingerprint &&
                find.text('Đang xử lý…').evaluate().isEmpty,
          );
          await tester.pumpAndSettle();
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
        final added = controller.draft.fingerprint;
        await tester.tap(find.byTooltip('Xóa sticker'));
        await tester.pump();
        expect(controller.draft.stickers, isEmpty);
        expect(undo.hitTestable(), findsOneWidget);
        await undoTo(added);
        expect(controller.draft.stickers.single.assetKey, 'animals/blue-bunny');
        await undoTo(initial);
        expect(tester.widget<IconButton>(undo).onPressed, isNull);
        await tester.tap(find.text('Chữ'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('photobooth-text-input')),
          'Bé yêu',
        );
        await tester.tap(find.byKey(const ValueKey('photobooth-text-confirm')));
        await tester.pumpAndSettle();
        final caption = controller.draft.fingerprint;
        expect(undo.hitTestable(), findsOneWidget);
        for (final label in [
          'Thêm chữ',
          'Sửa chữ',
          'Xoay chữ',
          'Đưa chữ lên trên',
          'Xóa chữ',
          'Ẩn công cụ',
        ]) {
          expect(find.byTooltip(label).hitTestable(), findsOneWidget);
        }
        final canvas = find.byKey(const ValueKey('photobooth-editor-canvas'));
        final rect = tester.getRect(canvas);
        final detector = tester.widget<GestureDetector>(canvas);
        final origin = rect.size.center(Offset.zero);
        detector.onScaleStart!(ScaleStartDetails(localFocalPoint: origin));
        for (var i = 1; i <= 3; i++) {
          detector.onScaleUpdate!(
            ScaleUpdateDetails(
              localFocalPoint: origin + Offset(i * 8, 0),
              rotation: i * .05,
              scale: 1 + i * .03,
            ),
          );
          await tester.pump();
        }
        detector.onScaleEnd!(ScaleEndDetails());
        await tester.pump();
        expect(controller.draft.fingerprint, isNot(caption));
        await undoTo(caption);
        final slider = tester.widget<Slider>(
          find.byKey(const ValueKey('photobooth-text-size')),
        );
        slider.onChangeStart!(slider.value);
        for (final value in [.08, .09, .1]) {
          final live = tester.widget<Slider>(
            find.byKey(const ValueKey('photobooth-text-size')),
          );
          live.onChanged!(value);
          await tester.pump();
        }
        tester
            .widget<Slider>(find.byKey(const ValueKey('photobooth-text-size')))
            .onChangeEnd!(.1);
        await undoTo(caption);
        await snapshot(tester, '${size.width.toInt()}_quick_undo');
        await tester.tap(find.byTooltip('Xóa chữ'));
        await tester.pump();
        await undoTo(caption);
        expect(controller.draft.texts.single.text, 'Bé yêu');
        await undoTo(initial);
        expect(controller.draft.texts, isEmpty);
        expect(tester.widget<IconButton>(undo).onPressed, isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      },
    );
  }

  testWidgets('quick undo restores a previous frame and its loaded overlay', (
    tester,
  ) async {
    final controller = PhotoBoothEditorController(session(4));
    await mount(tester, controller);
    final initial = controller.draft.fingerprint;
    await selectFrame(tester, 'film-1200');
    await waitFor(
      tester,
      () =>
          controller.draft.frameKey == 'film-1200' &&
          find.text('Đang xử lý…').evaluate().isEmpty,
    );
    await tester.tap(find.byKey(const ValueKey('photobooth-quick-undo')));
    await waitFor(
      tester,
      () =>
          controller.draft.fingerprint == initial &&
          find.text('Đang xử lý…').evaluate().isEmpty,
    );
    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byKey(const ValueKey('photobooth-preview-frame')),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as PhotoBoothPainter;
    expect(painter.frame.key, 'classic-600');
    expect(painter.images.assets.containsKey(painter.frame.asset), isTrue);
    expect(controller.canUndo, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'single taps select immediately and motion bursts update once per frame without rebuilding tools',
    (tester) async {
      final controller = PhotoBoothEditorController(session(2));
      final frame = PhotoBoothFrame.home(2);
      for (var i = 0; i < 8; i++) {
        controller.addText('Chữ $i', frame);
      }
      await mount(tester, controller);
      final canvas = find.byKey(const ValueKey('photobooth-editor-canvas'));
      final rect = tester.getRect(canvas);
      await tester.tapAt(rect.center);
      await tester.pump(); // no 300ms double-tap timeout
      final toolbar = find.byKey(
        const ValueKey('photobooth-text-quick-toolbar'),
      );
      expect(toolbar, findsOneWidget);
      // Allow the recognizer's 40ms minimum-tap tracker to expire after the
      // immediate-selection assertion, while remaining below its 300ms timeout.
      await tester.pump(const Duration(milliseconds: 50));
      final palette = find.byKey(const ValueKey('photobooth-text-palette'));
      final paletteWidget = tester.widget(palette);
      final toolbarWidget = tester.widget(toolbar);
      final photo = tester.widget(
        find.byKey(const ValueKey('photobooth-preview-photos')),
      );
      final paint =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byKey(
                        const ValueKey('photobooth-preview-texts'),
                      ),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as PhotoBoothPainter;
      final measurements = paint.images.textLayouts.measurementCount;
      final active = controller.draft.texts.last;
      final detector = tester.widget<GestureDetector>(canvas);
      final start = rect.size.center(Offset.zero);
      detector.onScaleStart!(
        ScaleStartDetails(localFocalPoint: start, focalPoint: rect.center),
      );
      var notifications = 0;
      controller.addListener(() => notifications++);
      for (var i = 1; i <= 24; i++) {
        detector.onScaleUpdate!(
          ScaleUpdateDetails(
            localFocalPoint: start + Offset(i.toDouble(), 0),
            focalPoint: rect.center + Offset(i.toDouble(), 0),
            pointerCount: 1,
          ),
        );
      }
      expect(notifications, 0);
      await tester.pump();
      expect(notifications, 1);
      expect(
        controller.draft.texts.last.x,
        closeTo(active.x + 24 / rect.width, 1e-9),
      );
      expect(paint.images.textLayouts.measurementCount, measurements);
      expect(tester.widget(palette), same(paletteWidget));
      expect(tester.widget(toolbar), same(toolbarWidget));
      expect(
        tester.widget(find.byKey(const ValueKey('photobooth-preview-photos'))),
        same(photo),
      );
      detector.onScaleEnd!(ScaleEndDetails());
      final moved = controller.draft.texts.last;
      final rotate = find.descendant(
        of: toolbar,
        matching: find.byTooltip('Xoay chữ'),
      );
      await tester.tap(rotate);
      await tester.pump();
      expect(
        controller.draft.texts.last.x,
        moved.x,
        reason: 'Cached quick actions must use the current transform',
      );
      expect(controller.draft.texts.last.rotation, greaterThan(moved.rotation));
      controller.changeText(controller.draft.texts.last.copy(fontSize: .09));
      await tester.pump();
      expect(tester.widget(palette), same(paletteWidget));
      expect(
        tester
            .widget<Slider>(find.byKey(const ValueKey('photobooth-text-size')))
            .value,
        .09,
      );
      final latest = controller.draft.texts.last;
      final origin = Offset(latest.x * rect.width, latest.y * rect.height);
      detector.onScaleStart!(ScaleStartDetails(localFocalPoint: origin));
      notifications = 0;
      detector.onScaleUpdate!(
        ScaleUpdateDetails(
          localFocalPoint: origin + const Offset(12, 0),
          pointerCount: 1,
        ),
      );
      expect(notifications, 0);
      detector.onScaleEnd!(ScaleEndDetails());
      expect(
        notifications,
        1,
        reason: 'Release flushes the last motion even before the next display frame',
      );
      await tester.pump();
      expect(notifications, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'overlapping captions select the top caption and cancel leaves its draft unchanged',
    (tester) async {
      final controller = PhotoBoothEditorController(session(2));
      final frame = PhotoBoothFrame.home(2);
      final lower = controller.addText('Chữ dưới', frame)!;
      final upper = controller.addText('Chữ trên', frame)!;
      final key = GlobalKey<PhotoBoothEditorEntryState>();
      await mount(tester, controller, key: key);
      final canvas = tester.getRect(
        find.byKey(const ValueKey('photobooth-editor-canvas')),
      );
      await tester.tapAt(canvas.center);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PhotoBoothTextComposer>(find.byType(PhotoBoothTextComposer))
            .value!
            .id,
        upper.id,
      );
      await tester.tapAt(canvas.center);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(canvas.center);
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('photobooth-text-input'));
      expect(tester.widget<TextField>(input).controller!.text, upper.text);
      await tester.enterText(input, 'Chỉ sửa chữ trên');
      await tester.pump();
      expect(controller.draft.texts.first.toJson(), lower.toJson());
      expect(controller.draft.texts.last.text, upper.text);
      expect(await key.currentState!.requestLeave(), isFalse);
      await tester.pumpAndSettle();
      expect(input, findsNothing);
      expect(controller.draft.texts.last.toJson(), upper.toJson());
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
