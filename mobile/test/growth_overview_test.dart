import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_overview.dart';

class EmptyRepository extends GrowthRepository {
  @override
  Future<List<GrowthMetricViewData>> loadOverview() async => [];
}

class FailedRepository extends GrowthRepository {
  @override
  Future<List<GrowthMetricViewData>> loadOverview() async =>
      throw StateError('offline');
}

void main() {
  test('BMI uses same-day measurements and refreshes after edits', () async {
    final repository = MockGrowthRepository();
    Future<GrowthMetricViewData> bmi() async =>
        (await repository.loadOverview()).singleWhere((m) => m.asset == 'bmi');
    expect((await bmi()).value, '15,1');
    final date = DateTime(2025, 5, 15);
    await repository.saveWeight(GrowthMeasurementDraft(value: 9, measuredAt: date));
    expect((await bmi()).value, '15,1');
    await repository.saveMeasurement(
      GrowthMetric.lengthHeight,
      GrowthMeasurementDraft(value: 75, measuredAt: date,
        method: GrowthMeasurementMethod.recumbent),
    );
    expect((await bmi()).value, '16,0');
    await repository.saveWeight(GrowthMeasurementDraft(value: 8.5, measuredAt: date));
    expect((await bmi()).value, '15,1');
  });

  testWidgets('overview reflows, changes range, and exports review screenshot', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final configFile = File('.dart_tool/package_config.json').absolute;
      final config =
          jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
      final flutter = (config['packages'] as List).singleWhere(
        (p) => p['name'] == 'flutter',
      );
      final root = configFile.uri.resolve('${flutter['rootUri']}/');
      final bytes = await File.fromUri(
        root.resolve(
          '../../bin/cache/artifacts/material_fonts/materialicons-regular.otf',
        ),
      ).readAsBytes();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    });
    for (final font in {
      'Nunito': 'nunito/Nunito-Variable.ttf',
      'PatrickHand': 'patrick_hand/PatrickHand-Regular.ttf',
      'DancingScript': 'dancing_script/DancingScript-Variable.ttf',
    }.entries) {
      await (FontLoader(
        font.key,
      )..addFont(rootBundle.load('assets/fonts/${font.value}'))).load();
    }
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();
    Future<void> render(double scale) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: tester.view.physicalSize,
              textScaler: TextScaler.linear(scale),
            ),
            child: RepaintBoundary(
              key: boundaryKey,
              child: const GrowthOverview(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await render(1);
    expect(find.text('8,5 kg'), findsOneWidget);
    expect(find.text('75 cm'), findsOneWidget);
    expect(find.text('45 cm'), findsOneWidget);
    expect(find.text('15,1 kg/m²'), findsOneWidget);
    expect(find.text('z ~ __'), findsNWidgets(4));
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(4));
    expect(find.text('Số đo gần nhất'), findsNothing);
    expect(find.text('15/05/2025'), findsNothing);
    expect(find.textContaining('DEMO'), findsNothing);
    expect(find.text('Phù hợp'), findsNothing);
    expect(tester.takeException(), isNull);
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final capture = await boundary.toImage(pixelRatio: 2);
      final bytes = await capture.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('../docs/growth/screenshots');
      await directory.create(recursive: true);
      await File('${directory.path}/overview.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      capture.dispose();
    });
    await tester.ensureVisible(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 tháng').last);
    await tester.pumpAndSettle();
    expect(find.text('Đầu tháng'), findsOneWidget);
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tùy chọn hiển thị'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckedPopupMenuItem<String>));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(320, 740);
    await render(2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await render(1.6);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Cập nhật chỉ số mới'), 250);
    await tester.tap(find.text('Cập nhật chỉ số mới'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn chỉ số bạn muốn cập nhật'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty and error states do not fabricate measurements', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: GrowthOverview(repository: EmptyRepository())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa có số đo'), findsOneWidget);
    expect(find.text('8,5 kg'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(home: GrowthOverview(repository: FailedRepository())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa tải được số đo.'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa tải được số đo.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
