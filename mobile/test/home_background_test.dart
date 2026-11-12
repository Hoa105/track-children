import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/home/background/background_config.dart';
import 'package:track_children/features/home/background/background_files.dart';
import 'package:track_children/features/home/background/background_frame_spec.dart';
import 'package:track_children/features/home/background/default_background_resolver.dart';
import 'package:track_children/features/home/background/home_background_frame.dart';
import 'package:track_children/features/home/background/home_background_repository.dart';
import 'package:track_children/features/home/background/home_background_section.dart';
import 'package:track_children/features/home/home_screen.dart';
import 'package:track_children/services/demo_store.dart';

class _DelayedRepository extends HomeBackgroundRepository {
  final requests = <String, Completer<BackgroundConfig>>{};
  final saved = <BackgroundConfig>[];

  @override
  Future<BackgroundConfig> load({
    required String accountId,
    required String childId,
  }) => (requests['$accountId/$childId'] ??= Completer<BackgroundConfig>())
      .future;

  @override
  Future<void> save({
    required String accountId,
    required BackgroundConfig config,
  }) async {
    saved.add(config);
  }
}

void main() {
  const repository = HomeBackgroundRepository(
    files: BackgroundFiles(rootPath: 'build/home_background_test/managed'),
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
  });

  Future<void> home(
    WidgetTester tester, {
    HomeBackgroundChooser? chooser,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Nunito'),
        home: HomeScreen(
          childName: 'Bảo An',
          onChangeBackground: chooser,
          backgroundRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  HomeBackgroundFrame frame(WidgetTester tester) =>
      tester.widget<HomeBackgroundFrame>(find.byType(HomeBackgroundFrame));

  Future<void> login() async {
    await DemoStore.instance.login(DemoStore.demoEmail, DemoStore.password);
    await DemoStore.instance.selectChild('child_an');
  }

  testWidgets('first open, child switch and role update use the right assets', (
    tester,
  ) async {
    await login();
    await home(tester);
    expect(
      frame(tester).assetPath,
      endsWith('mother-playing-with-lovely-son-bedroom.jpg'),
    );
    await DemoStore.instance.selectChild('child_linh');
    await tester.pumpAndSettle();
    expect(
      frame(tester).assetPath,
      endsWith('mother-daughter-studying-alphabet.jpg'),
    );
    await DemoStore.instance.saveParent({'role': 'grandmother'});
    await tester.pumpAndSettle();
    expect(
      frame(tester).assetPath,
      endsWith('granddaughter-grandmother-with-homework.jpg'),
    );
    await DemoStore.instance.saveParent({'role': 'guardian'});
    await tester.pumpAndSettle();
    expect(
      frame(tester).assetPath,
      endsWith('boy-girl-are-happily-playing-colorful-wood-block-toy.jpg'),
    );
  });

  testWidgets(
    'custom config survives gender/role edits and switching away and back',
    (tester) async {
      await login();
      final accountId = DemoStore.instance.parent['id'] as String;
      await repository.save(
        accountId: accountId,
        config: const BackgroundConfig(
          childId: 'child_an',
          source: BackgroundSource.photobooth,
          finalLocalPath: 'build/private/photostrip-home.jpg',
        ),
      );
      await home(tester);
      expect(frame(tester).source, BackgroundSource.photobooth);
      await DemoStore.instance.saveChild('child_an', {'gender': 'female'});
      await DemoStore.instance.saveParent({'role': 'father'});
      await tester.pumpAndSettle();
      expect(frame(tester).source, BackgroundSource.photobooth);
      expect(frame(tester).finalLocalPath, 'build/private/photostrip-home.jpg');
      await DemoStore.instance.selectChild('child_linh');
      await tester.pumpAndSettle();
      expect(frame(tester).source, BackgroundSource.defaultImage);
      expect(frame(tester).finalLocalPath, isNull);
      await DemoStore.instance.selectChild('child_an');
      await tester.pumpAndSettle();
      expect(frame(tester).source, BackgroundSource.photobooth);
      expect(
        (await repository.load(
          accountId: accountId,
          childId: 'child_an',
        )).finalLocalPath,
        'build/private/photostrip-home.jpg',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancel keeps the previous config, confirmed result persists after remount',
    (tester) async {
      await login();
      final accountId = DemoStore.instance.parent['id'] as String;
      var confirm = false;
      await home(
        tester,
        chooser: (_, current) async => confirm
            ? BackgroundConfig(
                childId: current.childId,
                source: BackgroundSource.gallery,
                finalLocalPath: 'build/private/confirmed.jpg',
              )
            : null,
      );
      final change = find.byTooltip('Đổi ảnh nền trang chủ');
      await tester.tap(change);
      await tester.pumpAndSettle();
      expect(frame(tester).source, BackgroundSource.defaultImage);
      expect(
        (await repository.load(
          accountId: accountId,
          childId: 'child_an',
        )).source,
        BackgroundSource.defaultImage,
      );
      confirm = true;
      await tester.tap(change);
      await tester.pumpAndSettle();
      expect(frame(tester).source, BackgroundSource.gallery);
      await tester.pumpWidget(const SizedBox());
      await home(tester);
      expect(frame(tester).source, BackgroundSource.gallery);
      expect(frame(tester).finalLocalPath, 'build/private/confirmed.jpg');
    },
  );

  testWidgets(
    'default chooser opens the source sheet and has a 48dp accessible target',
    (tester) async {
      await login();
      await home(tester);
      final button = find.byTooltip('Đổi ảnh nền trang chủ');
      final semantics = tester.ensureSemantics();
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Đổi ảnh nền trang chủ'), findsOneWidget);
      expect(tester.getSize(button).shortestSide, greaterThanOrEqualTo(48));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Đổi ảnh nền'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      semantics.dispose();
    },
  );

  testWidgets(
    'stale loads and pending chooser cannot cross account/profile boundaries',
    (tester) async {
      final repository = _DelayedRepository();
      final choice = Completer<BackgroundConfig?>();
      var activeAccount = 'a';
      var activeChild = 'one';
      Future<void> show(String account, String child) async {
        activeAccount = account;
        activeChild = child;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: HomeBackgroundSection(
                  accountId: account,
                  childId: child,
                  role: 'mother',
                  childGender: 'male',
                  repository: repository,
                  isCurrentProfile: () =>
                      activeAccount == account && activeChild == child,
                  onChangeBackground: (_, _) => choice.future,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await show('a', 'one');
      await show('b', 'two');
      repository.requests['a/one']!.complete(
        const BackgroundConfig(
          childId: 'one',
          source: BackgroundSource.gallery,
          finalLocalPath: 'private-one.jpg',
        ),
      );
      await tester.pump();
      expect(frame(tester).loading, isTrue);
      expect(frame(tester).finalLocalPath, isNull);
      repository.requests['b/two']!.complete(
        const BackgroundConfig(childId: 'two'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Đổi ảnh nền trang chủ'));
      await tester.pump();
      await show('a', 'three');
      choice.complete(
        const BackgroundConfig(
          childId: 'two',
          source: BackgroundSource.gallery,
          finalLocalPath: 'private-two.jpg',
        ),
      );
      await tester.pump();
      expect(repository.saved, isEmpty);
      expect(frame(tester).finalLocalPath, isNull);
      repository.requests['a/three']!.complete(
        const BackgroundConfig(childId: 'three'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('corrupt preferences show default and a readable status', (
    tester,
  ) async {
    await login();
    final accountId = DemoStore.instance.parent['id'] as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('home_background_v1:$accountId:child_an', '{broken');
    await home(tester);
    expect(frame(tester).source, BackgroundSource.defaultImage);
    expect(
      find.text('Chưa tải được tùy chọn ảnh nền. Đang dùng ảnh mặc định.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final kind in ['missing', 'corrupt', 'valid']) {
    testWidgets('$kind local image retains the frame and handles errors', (
      tester,
    ) async {
      final path = 'build/home_background_test/$kind.jpg';
      await tester.runAsync(() async {
        await Directory('build/home_background_test').create(recursive: true);
        if (kind == 'corrupt') {
          await File(path).writeAsString('not an image');
        }
        if (kind == 'valid') {
          await File(defaultBackgroundManifest.first.assetPath).copy(path);
        }
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: HomeBackgroundFrame(
                source: BackgroundSource.gallery,
                finalLocalPath: path,
                assetPath: defaultBackgroundManifest.last.assetPath,
              ),
            ),
          ),
        ),
      );
      // FileImage starts I/O during a fake-async build. Give real I/O a turn,
      // then pump its callbacks instead of awaiting that fake-zone future.
      for (var attempt = 0; attempt < 50; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        if (kind != 'valid' &&
            find
                .text('Không mở được ảnh đã lưu. Đang dùng ảnh mặc định.')
                .evaluate()
                .isNotEmpty) {
          break;
        }
        final customPixels = find.descendant(
          of: find.byKey(
            ValueKey<(BackgroundSource, String?)>((
              BackgroundSource.gallery,
              path,
            )),
          ),
          matching: find.byType(RawImage),
        );
        if (kind == 'valid' &&
            customPixels.evaluate().any(
              (element) => (element.widget as RawImage).image != null,
            )) {
          break;
        }
      }
      await tester.pumpAndSettle();
      final size = tester.getSize(
        find.byKey(const ValueKey('home-background-frame')),
      );
      expect(size.width / size.height, closeTo(homeBgAspectRatio, .001));
      expect(
        find.text('Không mở được ảnh đã lưu. Đang dùng ảnh mặc định.'),
        kind == 'valid' ? findsNothing : findsOneWidget,
      );
      if (kind == 'valid') {
        final pixels = tester.widget<RawImage>(
          find.descendant(
            of: find.byKey(
              ValueKey<(BackgroundSource, String?)>((
                BackgroundSource.gallery,
                path,
              )),
            ),
            matching: find.byType(RawImage),
          ),
        );
        expect(pixels.image, isNotNull);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
