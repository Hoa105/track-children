import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_overview.dart';
import 'package:track_children/features/growth/growth_weight_result.dart';

class RetryRepository extends MockGrowthRepository {
  int attempts = 0;
  final gate = Completer<void>();
  @override
  Future<void> saveWeight(GrowthMeasurementDraft draft) async {
    attempts++;
    if (attempts == 1) throw StateError('save failed');
    await gate.future;
    await super.saveWeight(draft);
  }
}

void main() {
  testWidgets('review draft, save and refresh overview, export screenshot', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final config = File('.dart_tool/package_config.json').absolute;
      final packages =
          jsonDecode(await config.readAsString())['packages'] as List;
      final flutter = packages.singleWhere((p) => p['name'] == 'flutter');
      final root = config.uri.resolve('${flutter['rootUri']}/');
      final icons = await File.fromUri(
        root.resolve(
          '../../bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        ),
      ).readAsBytes();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(icons)))).load();
    });
    for (final font in {
      'Nunito': 'nunito/Nunito-Variable.ttf',
      'DancingScript': 'dancing_script/DancingScript-Variable.ttf',
    }.entries) {
      await (FontLoader(
        font.key,
      )..addFont(rootBundle.load('assets/fonts/${font.value}'))).load();
    }
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final repo = MockGrowthRepository();
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: GrowthWeightResultScreen(
            repository: repo,
            draft: GrowthMeasurementDraft(
              value: 8.8,
              measuredAt: DateTime(2025, 5, 15),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('8,8 kg'), findsOneWidget);
    expect(find.text('Ngày đo: 15/05/2025'), findsOneWidget);
    expect(find.text('Tăng 300 g'), findsOneWidget);
    expect(find.text('Đã lưu cân nặng mới!'), findsNothing);
    expect(find.textContaining('Phù hợp'), findsNothing);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final capture = await boundary.toImage(pixelRatio: 2);
      final png = await capture.toByteData(format: ui.ImageByteFormat.png);
      final file = File('../docs/growth/screenshots/weight-result.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(png!.buffer.asUint8List());
      capture.dispose();
    });
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(home: GrowthOverview(repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cập nhật chỉ số mới'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cân nặng'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '8,9');
    tester.binding.buildOwner!.reassemble(tester.binding.rootElement!);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      '8,9',
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text('8,9 kg'), findsOneWidget);
    expect(find.text('Tăng 400 g'), findsOneWidget);
    await tester.tap(find.byTooltip('Sửa số đo'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      '8,9',
    );
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu kết quả'));
    await tester.pumpAndSettle();
    expect(find.text('Đã lưu cân nặng mới!'), findsOneWidget);
    expect((await repo.loadOverview()).first.value, '8,9');
    tester.binding.buildOwner!.reassemble(tester.binding.rootElement!);
    await tester.pumpAndSettle();
    expect(find.text('Đã lưu cân nặng mới!'), findsOneWidget);
    await tester.tap(find.text('Về tổng quan'));
    await tester.pumpAndSettle();
    expect(find.text('8,9 kg'), findsOneWidget);
    expect(find.byType(GrowthWeightResultScreen), findsNothing);
    await tester.tap(find.text('Cập nhật chỉ số mới'));
    await tester.pumpAndSettle();
    expect(find.text('Gần nhất: 8,9 kg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'save failure retries without duplicate submissions; large text fits',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final repo = RetryRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: GrowthWeightResultScreen(
              repository: repo,
              easyReadMode: true,
              draft: GrowthMeasurementDraft(
                value: 8.1,
                measuredAt: DateTime(2025, 5, 15),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Giảm 400 g'), findsOneWidget);
      await tester.tap(find.text('Lưu kết quả'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Chưa lưu được số đo. Bạn thử lại nhé.'),
        150,
      );
      expect(find.text('Đã lưu cân nặng mới!'), findsNothing);
      await tester.tap(find.text('Lưu kết quả'));
      await tester.pump();
      expect(find.text('Đang lưu…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(repo.attempts, 2);
      repo.gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Đã lưu cân nặng mới!'), findsOneWidget);
      expect(find.text('Về tổng quan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'mock save preserves chronology, replaces same day, does not persist',
    () async {
      final repo = MockGrowthRepository();
      final initialCount = (await repo.weightMeasurements()).length;
      expect(await repo.weightBefore(DateTime(2020)), isNull);
      await repo.saveWeight(
        GrowthMeasurementDraft(value: 8.8, measuredAt: DateTime(2025, 5, 15)),
      );
      await repo.saveWeight(
        GrowthMeasurementDraft(value: 8.9, measuredAt: DateTime(2025, 5, 15)),
      );
      await repo.saveWeight(
        GrowthMeasurementDraft(value: 7, measuredAt: DateTime(2024, 8, 15)),
      );
      final data = (await repo.loadOverview()).first;
      expect(data.value, '8,9');
      expect((await repo.weightMeasurements()).length, initialCount + 2);
      expect((await MockGrowthRepository().loadOverview()).first.value, '8,5');
      expect(
        () => repo.saveWeight(
          GrowthMeasurementDraft(value: -1, measuredAt: DateTime(2025)),
        ),
        throwsArgumentError,
      );
    },
  );
}
