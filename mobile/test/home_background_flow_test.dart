import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/app_colors.dart';
import 'package:track_children/features/home/background/background_chooser_sheet.dart';
import 'package:track_children/features/home/background/background_config.dart';
import 'package:track_children/features/home/background/background_crop_state.dart';
import 'package:track_children/features/home/background/background_image_service.dart';
import 'package:track_children/features/home/background/background_draft.dart';
import 'package:track_children/features/home/background/background_files.dart';
import 'package:track_children/features/home/background/background_picker_service.dart';
import 'package:track_children/features/home/background/crop_background_screen.dart';
import 'package:track_children/features/home/background/home_background_flow.dart';
import 'package:track_children/features/home/background/home_background_repository.dart';
import 'package:track_children/features/home/background/photobooth_entry_screen.dart';
import 'package:track_children/features/home/home_screen.dart';
import 'package:track_children/services/demo_store.dart';

class _Gallery extends BackgroundPickerService {
  _Gallery({required super.files, required this.source});
  String source;
  String? error;
  bool cancelled = false;
  bool denied = false;
  bool settingsFail = false;
  int settingsOpened = 0;
  @override
  Future<void> openSettings() async {
    settingsOpened++;
    if (settingsFail) throw StateError('native settings unavailable');
  }

  @override
  Future<String?> pick({
    required String accountId,
    required String childId,
  }) async {
    if (error != null) {
      throw BackgroundImageException(error!, canOpenSettings: denied);
    }
    if (cancelled) return null;
    return files.keepInput(source);
  }
}

class _Repository extends HomeBackgroundRepository {
  _Repository(BackgroundFiles files) : super(files: files);
  int writes = 0;
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<void> save({
    required String accountId,
    required BackgroundConfig config,
  }) async {
    writes++;
    if (gate != null) await gate!.future;
    if (fail) throw StateError('disk full');
    await super.save(accountId: accountId, config: config);
  }
}

void main() {
  late Directory root;
  late String source;
  late String portraitSource;
  late String smallSource;
  late DecodedBackgroundImage portrait;
  late BackgroundFiles files;
  late _Repository repository;
  late _Gallery gallery;
  late ValueNotifier<String> active;
  late bool finished;
  BackgroundConfig? applied;
  final captureKey = GlobalKey();
  ThemeData theme([TargetPlatform? platform]) => ThemeData(
    fontFamily: 'Nunito',
    platform: platform,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      surface: AppColors.surface,
    ),
  );

  setUpAll(() async {
    final loader = FontLoader('Nunito')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            await File('assets/fonts/nunito/Nunito-Variable.ttf').readAsBytes(),
          ),
        ),
      );
    await loader.load();
    final configFile = File('.dart_tool/package_config.json').absolute;
    final config =
        jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
    final flutter = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((package) => package['name'] == 'flutter');
    final fontFile = File.fromUri(
      configFile.uri
          .resolve('${flutter['rootUri']}/')
          .resolve(
            '../../bin/cache/artifacts/material_fonts/materialicons-regular.otf',
          ),
    );
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(ByteData.sublistView(await fontFile.readAsBytes())),
        ))
        .load();
    await Directory('build/background_flow_tests').create(recursive: true);
    source = 'build/background_flow_tests/landmarks.jpg';
    final image = img.Image(width: 2400, height: 1800);
    img.fillRect(
      image,
      x1: 0,
      y1: 0,
      x2: 1199,
      y2: 1799,
      color: img.ColorRgb8(240, 90, 80),
    );
    img.fillRect(
      image,
      x1: 1200,
      y1: 0,
      x2: 2399,
      y2: 1799,
      color: img.ColorRgb8(90, 180, 120),
    );
    await File(source).writeAsBytes(img.encodeJpg(image));
    smallSource = 'build/background_flow_tests/small.jpg';
    await File(smallSource)
        .writeAsBytes(img.encodeJpg(img.Image(width: 120, height: 120)));
    portraitSource = 'build/background_flow_tests/portrait.jpg';
    final tall = img.Image(width: 1800, height: 2700);
    img.fillRect(
      tall,
      x1: 0,
      y1: 0,
      x2: 1799,
      y2: 1349,
      color: img.ColorRgb8(240, 90, 80),
    );
    img.fillRect(
      tall,
      x1: 0,
      y1: 1350,
      x2: 1799,
      y2: 2699,
      color: img.ColorRgb8(90, 180, 120),
    );
    await File(portraitSource).writeAsBytes(img.encodeJpg(tall));
    portrait = await const BackgroundImageService().decode(portraitSource);
  });
  tearDownAll(() => portrait.dispose());

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
    await DemoStore.instance.login(DemoStore.demoEmail, DemoStore.password);
    await DemoStore.instance.selectChild('child_an');
    root = await Directory('build/background_flow_tests').createTemp('run_');
    files = BackgroundFiles(rootPath: root.path);
    repository = _Repository(files);
    gallery = _Gallery(files: files, source: source);
    active = ValueNotifier('child_an');
    finished = false;
    applied = null;
  });
  tearDown(() => active.dispose());

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() ready, {
    bool settle = true,
  }) async {
    for (var attempt = 0; attempt < 500 && !ready(); attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(ready(), isTrue, reason: 'Flow did not reach the expected state');
    if (settle) await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> launch(
    WidgetTester tester, {
    PhotoboothHomeLauncher? photobooth,
  }) async {
    finished = false;
    applied = null;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          theme: theme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () async {
                    applied = await HomeBackgroundFlow(
                      context: context,
                      accountId: 'parent',
                      childId: 'child_an',
                      current: const BackgroundConfig(childId: 'child_an'),
                      repository: repository,
                      picker: gallery,
                      profileChanges: active,
                      isCurrentProfile: () => active.value == 'child_an',
                      photobooth: photobooth,
                    ).open();
                    finished = true;
                  },
                  child: const Text('Đổi nền'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Đổi nền'));
    await tester.pumpAndSettle();
    expect(find.byType(BackgroundChooserSheet), findsOneWidget);
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          captureKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('build/background_flow_tests/$name.png')
          .writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'default selection requires confirmation, cancel and Apply commit once',
    (tester) async {
      await launch(tester);
      await tester.tap(find.text('Ảnh mặc định'));
      await tester.pumpAndSettle();
      expect(find.text('Dùng ảnh mặc định?'), findsOneWidget);
      expect(find.text('Xem trước trang chủ'), findsNothing);
      expect(repository.writes, 0);
      await tester.tap(find.text('Hủy'));
      await pumpUntil(tester, () => finished);
      expect(applied, isNull);
      await launch(tester);
      await tester.tap(find.text('Ảnh mặc định'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Áp dụng'));
      await pumpUntil(tester, () => finished);
      expect(applied?.source, BackgroundSource.defaultImage);
      expect(repository.writes, 1);
    },
  );

  testWidgets(
    'crop applies directly, stays open while saving, and commits cropped JPEG once',
    (tester) async {
      repository.gate = Completer<void>();
      await launch(tester);
      await tester.tap(find.text('Ảnh từ thư viện'));
      await pumpUntil(
        tester,
        () => find.byType(CropBackgroundScreen).evaluate().isNotEmpty,
      );
      expect(find.text('Tiếp tục'), findsNothing);
      expect(find.text('Áp dụng'), findsOneWidget);
      final crop = tester
          .widget<CropBackgroundScreen>(find.byType(CropBackgroundScreen))
          .crop;
      await tester.drag(find.byType(Slider), const Offset(45, 0));
      await tester.pump();
      expect(crop.zoom, greaterThan(1));
      await tester.drag(
        find.byKey(const ValueKey('background-crop-viewport')),
        const Offset(-70, 0),
      );
      await tester.pump();
      await screenshot(tester, 'crop_direct_apply_320');
      await tester.tap(find.text('Áp dụng'));
      await pumpUntil(tester, () => repository.writes == 1, settle: false);
      expect(find.byType(CropBackgroundScreen), findsOneWidget);
      expect(find.text('Đổi nền'), findsNothing);
      expect(find.text('Xem trước trang chủ'), findsNothing);
      expect(finished, isFalse);
      expect(
        (await repository.load(
          accountId: 'parent',
          childId: 'child_an',
        )).source,
        BackgroundSource.defaultImage,
      );
      repository.gate!.complete();
      await pumpUntil(tester, () => finished);
      expect(applied?.source, BackgroundSource.gallery);
      expect(repository.writes, 1);
      await tester.runAsync(() async {
        final result = await repository.load(
          accountId: 'parent',
          childId: 'child_an',
        );
        final image = img.decodeJpg(
          await File(result.finalLocalPath!).readAsBytes(),
        )!;
        expect((image.width, image.height), (1440, 960));
        expect(
          await Directory('${root.path}/pending').list().toList(),
          isEmpty,
        );
      });
    },
  );

  testWidgets(
    'small image error is visible above the source list and can retry',
    (tester) async {
      gallery.source = smallSource;
      await launch(tester);
      await tester.tap(find.text('Ảnh từ thư viện'));
      await pumpUntil(
        tester,
        () => find
            .byKey(const ValueKey('background-source-error'))
            .evaluate()
            .isNotEmpty,
      );
      final error = find.byKey(const ValueKey('background-source-error'));
      expect(
        find.textContaining('kích thước tối thiểu 1080 x 720 px'),
        findsOneWidget,
      );
      expect(error.hitTestable(), findsOneWidget);
      final rect = tester.getRect(error);
      final sheet = tester.getRect(find.byType(BackgroundChooserSheet));
      expect(rect.top, greaterThanOrEqualTo(sheet.top));
      expect(rect.bottom, lessThanOrEqualTo(sheet.bottom));
      expect(find.byType(SnackBar), findsNothing);
      expect(repository.writes, 0);
      await screenshot(tester, 'small_image_error_320');
      gallery.source = source;
      await tester.tap(find.text('Ảnh từ thư viện'));
      await pumpUntil(
        tester,
        () => find.byType(CropBackgroundScreen).evaluate().isNotEmpty,
      );
      expect(
        find.textContaining('kích thước tối thiểu 1080 x 720 px'),
        findsNothing,
      );
      await tester.tap(find.text('Hủy'));
      await pumpUntil(tester, () => finished);
      expect(applied, isNull);
    },
  );

  testWidgets(
    'picker denial/cancel and crop cancellation keep the background',
    (tester) async {
      gallery.error = 'Chưa có quyền chọn ảnh. Bạn có thể cấp quyền Ảnh trong Cài đặt rồi thử lại.';
      await launch(tester);
      await tester.tap(find.text('Ảnh từ thư viện'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('background-source-error')).hitTestable(),
        findsOneWidget,
      );
      expect(find.textContaining('Chưa có quyền'), findsOneWidget);
      gallery.error = null;
      gallery.cancelled = true;
      await tester.tap(find.text('Ảnh từ thư viện'));
      await pumpUntil(tester, () => finished);
      expect(repository.writes, 0);
      gallery.cancelled = false;
      await launch(tester);
      await tester.tap(find.text('Ảnh từ thư viện'));
      await pumpUntil(
        tester,
        () => find.byType(CropBackgroundScreen).evaluate().isNotEmpty,
      );
      await tester.tap(find.text('Hủy'));
      await pumpUntil(tester, () => finished);
      expect(applied, isNull);
    },
  );

  testWidgets(
    'failed Apply remains in crop, preserves edits and retries successfully',
    (tester) async {
      repository.fail = true;
      await launch(tester);
      await tester.tap(find.text('Ảnh từ thư viện'));
      await pumpUntil(
        tester,
        () => find.byType(CropBackgroundScreen).evaluate().isNotEmpty,
      );
      final crop = tester
          .widget<CropBackgroundScreen>(find.byType(CropBackgroundScreen))
          .crop;
      final rect = crop.normalizedRect;
      await tester.tap(find.text('Áp dụng'));
      await pumpUntil(
        tester,
        () => find.textContaining('Chưa áp dụng được').evaluate().isNotEmpty,
      );
      expect(
        find.textContaining('Chưa áp dụng được').hitTestable(),
        findsOneWidget,
      );
      expect(crop.normalizedRect, rect);
      expect(finished, isFalse);
      expect(
        (await repository.load(
          accountId: 'parent',
          childId: 'child_an',
        )).source,
        BackgroundSource.defaultImage,
      );
      await screenshot(tester, 'crop_apply_error_320');
      repository.fail = false;
      await tester.tap(find.text('Áp dụng'));
      await pumpUntil(tester, () => finished);
      expect(applied?.source, BackgroundSource.gallery);
      expect(repository.writes, 2);
    },
  );

  testWidgets('profile switch cancels crop and closes only owned routes', (
    tester,
  ) async {
    await launch(tester);
    await tester.tap(find.text('Ảnh từ thư viện'));
    await pumpUntil(
      tester,
      () => find.byType(CropBackgroundScreen).evaluate().isNotEmpty,
    );
    active.value = 'another-child';
    await pumpUntil(tester, () => finished);
    expect(applied, isNull);
    expect(repository.writes, 0);
    expect(find.text('Đổi nền'), findsOneWidget);
  });

  testWidgets(
    'default Apply failure is visible in confirmation and can cancel',
    (tester) async {
      repository.fail = true;
      await launch(tester);
      await tester.tap(find.text('Ảnh mặc định'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Chưa lưu được ảnh nền').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.text('Hủy'));
      await pumpUntil(tester, () => finished);
      expect(applied, isNull);
    },
  );

  testWidgets('Photobooth entry and injected collage use the shared crop', (
    tester,
  ) async {
    await launch(tester);
    await tester.tap(find.text('Chụp Photobooth'));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoboothEntryScreen), findsOneWidget);
    await tester.ensureVisible(find.text('Quay lại'));
    await tester.tap(find.text('Quay lại'));
    await pumpUntil(
      tester,
      () => find.byType(BackgroundChooserSheet).evaluate().isNotEmpty,
    );
    await tester.binding.handlePopRoute();
    await pumpUntil(tester, () => finished);
    await launch(
      tester,
      photobooth: (_, child) async =>
          PhotoboothHomeInput(childId: child, localPath: source),
    );
    await tester.tap(find.text('Chụp Photobooth'));
    await pumpUntil(
      tester,
      () => find.byType(CropBackgroundScreen).evaluate().isNotEmpty,
    );
    await tester.tap(find.text('Hủy'));
    await pumpUntil(tester, () => finished);
    expect(repository.writes, 0);
  });

  testWidgets(
    'default Photobooth editor callback cancels safely then applies through shared crop',
    (tester) async {
      await launch(tester);
      await tester.tap(find.text('Chụp Photobooth'));
      await tester.pumpAndSettle();
      final entry = tester.widget<PhotoboothEntryScreen>(
        find.byType(PhotoboothEntryScreen),
      );
      var completed = false;
      BackgroundConfig? result;
      entry.onUseHome!(source).then((value) {
        result = value;
        completed = true;
      });
      await pumpUntil(
        tester,
        () => find.byType(CropBackgroundScreen).evaluate().isNotEmpty,
      );
      await tester.tap(find.text('Hủy'));
      await pumpUntil(tester, () => completed);
      expect(result, isNull);
      expect(repository.writes, 0);
      expect(find.byType(PhotoboothEntryScreen), findsOneWidget);
      completed = false;
      entry.onUseHome!(source).then((value) {
        result = value;
        completed = true;
      });
      await pumpUntil(
        tester,
        () => find.byType(CropBackgroundScreen).evaluate().isNotEmpty,
      );
      await tester.tap(find.text('Áp dụng'));
      await pumpUntil(tester, () => completed);
      expect(result?.source, BackgroundSource.photobooth);
      expect(repository.writes, 1);
      Navigator.of(tester.element(find.byType(PhotoboothEntryScreen)))
          .pop(result);
      await pumpUntil(tester, () => finished);
      expect(applied?.source, BackgroundSource.photobooth);
    },
  );

  testWidgets('no child shows a request instead of assigning a background', (
    tester,
  ) async {
    await DemoStore.instance.logout();
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(childName: 'Bé')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Đổi ảnh nền trang chủ'));
    await tester.pump();
    expect(
      find.text('Bạn hãy chọn hồ sơ bé trước khi đổi ảnh nền.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Home default confirmation commits once without a preview route',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            childName: 'Bảo An',
            backgroundRepository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Đổi ảnh nền trang chủ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ảnh mặc định'));
      await tester.pumpAndSettle();
      expect(repository.writes, 0);
      expect(find.text('Xem trước trang chủ'), findsNothing);
      await tester.tap(find.text('Áp dụng'));
      await pumpUntil(
        tester,
        () =>
            repository.writes == 1 &&
            find.byType(AlertDialog).evaluate().isEmpty,
      );
      expect(repository.writes, 1);
      expect(
        (await repository.load(
          accountId: DemoStore.instance.parent['id'] as String,
          childId: 'child_an',
        )).updatedAt,
        isNotNull,
      );
    },
  );

  testWidgets('raw portrait Photobooth output reports a visible source error', (
    tester,
  ) async {
    await launch(
      tester,
      photobooth: (_, child) async =>
          PhotoboothHomeInput(childId: child, localPath: portraitSource),
    );
    await tester.tap(find.text('Chụp Photobooth'));
    await pumpUntil(
      tester,
      () => find.textContaining('Hãy tạo bố cục ngang').evaluate().isNotEmpty,
    );
    expect(find.byType(CropBackgroundScreen), findsNothing);
    expect(
      find.byKey(const ValueKey('background-source-error')).hitTestable(),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await pumpUntil(tester, () => finished);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final size in const [
      Size(320, 568),
      Size(360, 800),
      Size(393, 852),
      Size(430, 932),
    ]) {
      testWidgets('crop/source error ${platform.name} ${size.width} text 1.3', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final crop = BackgroundCropState(sourceSize: portrait.naturalSize);
        await tester.pumpWidget(
          RepaintBoundary(
            key: captureKey,
            child: MaterialApp(
              key: UniqueKey(),
              theme: theme(platform),
              home: CropBackgroundScreen(
                image: portrait,
                crop: crop,
                onApply: () async =>
                    const BackgroundConfig(childId: 'child_an'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Áp dụng').hitTestable(), findsOneWidget);
        final viewport = tester.getSize(
          find.byKey(const ValueKey('background-crop-viewport')),
        );
        final geometry = BackgroundCropGeometry(
          viewport: viewport,
          source: crop.sourceSize,
          normalizedRect: crop.normalizedRect,
        );
        expect(
          geometry.frame.width / geometry.frame.height,
          closeTo(1.5, 1e-9),
        );
        expect(geometry.image.top, greaterThanOrEqualTo(0));
        expect(geometry.image.bottom, lessThanOrEqualTo(viewport.height));
        expect(geometry.image.top, lessThan(geometry.frame.top));
        expect(geometry.image.bottom, greaterThan(geometry.frame.bottom));
        await screenshot(
          tester,
          'full_image_${platform.name}_${size.width.toInt()}',
        );
        final initialFrame = geometry.frame;
        final workspaceRect = tester.getRect(
          find.byKey(const ValueKey('background-crop-viewport')),
        );
        final drag = await tester.startGesture(
          workspaceRect.topLeft +
              Offset(geometry.image.center.dx, geometry.image.top + 8),
        );
        await drag.moveBy(const Offset(0, 20));
        await drag.up();
        await tester.pump();
        expect(crop.center.dy, lessThan(.5));
        await tester.tap(find.text('Đặt lại'));
        await tester.pump();
        final slider = tester.widget<Slider>(find.byType(Slider));
        slider.onChanged!(slider.max);
        await tester.pump();
        expect(crop.zoom, closeTo(5, 1e-6));
        final zoomed = BackgroundCropGeometry(
          viewport: tester.getSize(
            find.byKey(const ValueKey('background-crop-viewport')),
          ),
          source: crop.sourceSize,
          normalizedRect: crop.normalizedRect,
        );
        expect(zoomed.frame, initialFrame);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Đặt lại'));
        await tester.pump();
        expect(crop.zoom, 1);
        await tester.pumpWidget(
          RepaintBoundary(
            key: captureKey,
            child: MaterialApp(
              key: UniqueKey(),
              theme: theme(platform),
              home: Scaffold(
                body: BackgroundChooserSheet(
                  currentSource: BackgroundSource.gallery,
                  onSelected: (_) {},
                  errorMessage: 'Vui lòng chọn ảnh có kích thước tối thiểu 1080 x 720 px.',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        crop.dispose();
        final error = find.byKey(const ValueKey('background-source-error'));
        expect(error.hitTestable(), findsOneWidget);
        final rect = tester.getRect(error);
        expect(rect.top, greaterThanOrEqualTo(44));
        expect(rect.bottom, lessThanOrEqualTo(size.height - 34));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'denied gallery offers Settings and retries without changing Home',
    (tester) async {
      gallery.error = 'Bạn hãy cấp quyền Ảnh trong Cài đặt.';
      gallery.denied = true;
      await launch(tester);
      await tester.tap(find.text('Ảnh từ thư viện'));
      await pumpUntil(
        tester,
        () => find.text('Mở Cài đặt').evaluate().isNotEmpty,
      );
      expect(repository.writes, 0);
      await tester.tap(find.text('Mở Cài đặt'));
      await tester.pumpAndSettle();
      expect(gallery.settingsOpened, 1);
      expect(find.byType(BackgroundChooserSheet), findsOneWidget);
      gallery.settingsFail = true;
      await tester.tap(find.text('Mở Cài đặt'));
      await tester.pumpAndSettle();
      final message = find.text(
        'Bạn hãy mở Cài đặt của thiết bị và cấp quyền Ảnh rồi thử lại.',
      );
      expect(message, findsOneWidget);
      expect(tester.getRect(message).bottom, lessThan(568 - 34));
      gallery.error = null;
      await tester.ensureVisible(find.text('Ảnh từ thư viện'));
      await tester.tap(find.text('Ảnh từ thư viện'));
      await pumpUntil(
        tester,
        () => find.byType(CropBackgroundScreen).evaluate().isNotEmpty,
      );
      await tester.tap(find.text('Hủy'));
      await pumpUntil(tester, () => finished);
      expect(applied, isNull);
      expect(repository.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
