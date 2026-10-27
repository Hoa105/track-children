import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_overview.dart';
import 'package:track_children/features/growth/growth_weight_input.dart';
import 'package:track_children/features/growth/growth_weight_result.dart';

void main() {
  testWidgets(
    'length and head flows save independently and export four screens',
    (tester) async {
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
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: GrowthOverview(repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('../docs/growth/screenshots/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(png!.buffer.asUint8List());
          image.dispose();
        });
      }

      for (final metric in [
        GrowthMetric.lengthHeight,
        GrowthMetric.headCircumference,
      ]) {
        await tester.tap(find.text('Cập nhật chỉ số mới'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(metric.title));
        await tester.pumpAndSettle();
        expect(
          find.text(
            metric == GrowthMetric.lengthHeight
                ? 'Cập nhật chiều dài'
                : 'Cập nhật ${metric.lowerTitle}',
          ),
          findsOneWidget,
        );
        expect(find.text('cm'), findsOneWidget);
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField))
              .controller!
              .text,
          metric.initialValue,
        );
        await capture('${metric.routeKey}-input');
        await tester.enterText(find.byType(TextFormField), '0');
        await tester.tap(find.text('Tiếp tục'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Nhập số lớn hơn 0'), findsOneWidget);
        await tester.enterText(find.byType(TextFormField), metric.initialValue);
        await tester.tap(find.text('Tiếp tục'));
        await tester.pumpAndSettle();
        expect(find.text('${metric.initialValue} cm'), findsOneWidget);
        expect(
          find.text(
            metric == GrowthMetric.lengthHeight ? 'Tăng 1,5 cm' : 'Tăng 0,5 cm',
          ),
          findsOneWidget,
        );
        expect(find.text('so với 1 tháng trước'), findsOneWidget);
        expect(find.text('Phù hợp'), findsNothing);
        if (metric == GrowthMetric.lengthHeight) {
          expect(find.text('Cách đo: Chiều dài nằm'), findsOneWidget);
        }
        await capture('${metric.routeKey}-result');
        await tester.tap(find.byTooltip('Sửa số đo'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField))
              .controller!
              .text,
          metric.initialValue,
        );
        await tester.tap(find.text('Tiếp tục'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lưu kết quả'));
        await tester.pumpAndSettle();
        expect(find.text('Đã lưu ${metric.lowerTitle} mới!'), findsOneWidget);
        await tester.tap(find.text('Về tổng quan'));
        await tester.pumpAndSettle();
        expect(find.text('${metric.initialValue} cm'), findsOneWidget);
        expect(find.text('8,5 kg'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.text('Cập nhật chỉ số mới'));
      await tester.pumpAndSettle();
      expect(find.text('Gần nhất: 76,5 cm'), findsOneWidget);
      expect(find.text('Gần nhất: 45,5 cm'), findsOneWidget);
      expect((await repo.weightMeasurements()).last.value, 8.5);
    },
  );

  for (final metric in [
    GrowthMetric.lengthHeight,
    GrowthMetric.headCircumference,
  ]) {
    testWidgets('${metric.routeKey} reflows with keyboard and large text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: GrowthWeightInputScreen(metric: metric, easyReadMode: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        metric.initialValue.replaceAll(',', '.'),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Tiếp tục')).bottom, lessThan(480));
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.byType(GrowthWeightResultScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Lưu kết quả'));
      await tester.pumpAndSettle();
      expect(find.text('Đã lưu ${metric.lowerTitle} mới!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('different length method is preserved without a false delta', (
    tester,
  ) async {
    final repo = MockGrowthRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: GrowthWeightInputScreen(
          metric: GrowthMetric.lengthHeight,
          repository: repo,
          initialDate: DateTime(2026, 5, 15),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cập nhật chiều cao'), findsOneWidget);
    expect(find.text('Cách đo'), findsNothing);
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text('Cách đo: Chiều cao đứng'), findsOneWidget);
    expect(find.text('Khác cách đo'), findsOneWidget);
    expect(find.text('Tăng 1,5 cm'), findsNothing);
    await tester.tap(find.text('Lưu kết quả'));
    await tester.pumpAndSettle();
    final stored = (await repo.measurements(GrowthMetric.lengthHeight)).last;
    expect(stored.method, GrowthMeasurementMethod.standing);
    expect(stored.value, 76.5);
    expect(tester.takeException(), isNull);
  });

  test(
    'cm stores retain chronology, replace same day and reject missing method',
    () async {
      final repo = MockGrowthRepository();
      for (final metric in [
        GrowthMetric.lengthHeight,
        GrowthMetric.headCircumference,
      ]) {
        final method = metric == GrowthMetric.lengthHeight
            ? GrowthMeasurementMethod.recumbent
            : null;
        final value = metric == GrowthMetric.lengthHeight ? 77.0 : 46.0;
        final expectedDates = {
          for (final point in await repo.measurements(metric))
            DateUtils.dateOnly(point.measuredAt),
          DateTime(2025, 5, 15),
          DateTime(2024, 12, 15),
        };
        await repo.saveMeasurement(
          metric,
          GrowthMeasurementDraft(
            value: value,
            measuredAt: DateTime(2025, 5, 15),
            method: method,
          ),
        );
        await repo.saveMeasurement(
          metric,
          GrowthMeasurementDraft(
            value: value + .1,
            measuredAt: DateTime(2025, 5, 15),
            method: method,
          ),
        );
        await repo.saveMeasurement(
          metric,
          GrowthMeasurementDraft(
            value: value - 5,
            measuredAt: DateTime(2024, 12, 15),
            method: method,
          ),
        );
        final data = await repo.measurements(metric);
        expect(data.length, expectedDates.length);
        expect(data.last.value, value + .1);
        expect(data.last.method, method);
      }
      await expectLater(
        repo.saveMeasurement(
          GrowthMetric.lengthHeight,
          GrowthMeasurementDraft(value: 80, measuredAt: DateTime(2025, 6, 15)),
        ),
        throwsArgumentError,
      );
    },
  );
}
