import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_overview.dart';
import 'package:track_children/features/growth/growth_weight_input.dart';

void main() {
  testWidgets(
    'weight draft validates, selects date and exports review capture',
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
      final captureKey = GlobalKey();
      GrowthMeasurementDraft? draft;
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: captureKey,
            child: GrowthWeightInputScreen(
              onContinue: (value) => draft = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('8,8'), findsOneWidget);
      expect(find.text('15/05/2025'), findsOneWidget);
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final capture = await boundary.toImage(pixelRatio: 2);
        final png = await capture.toByteData(format: ui.ImageByteFormat.png);
        final file = File('../docs/growth/screenshots/weight-input.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png!.buffer.asUint8List());
        capture.dispose();
      });
      for (final invalid in ['', '0', '-1', 'NaN', '8,8,8']) {
        await tester.enterText(find.byType(TextFormField), invalid);
        await tester.tap(find.text('Tiếp tục'));
        await tester.pumpAndSettle();
        expect(draft, isNull);
        expect(
          find.textContaining(
            invalid.isEmpty ? 'Nhập cân nặng' : 'Nhập số lớn hơn',
          ),
          findsOneWidget,
        );
      }
      await tester.enterText(find.byType(TextFormField), '9,25');
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(draft!.value, 9.25);
      expect(draft!.measuredAt, DateTime(2025, 5, 15));
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(
        picker.lastDate.isAfter(DateUtils.dateOnly(DateTime.now())),
        isFalse,
      );
      await tester.tap(find.text('16').last);
      await tester.tap(find.text('Chọn'));
      await tester.pumpAndSettle();
      expect(find.text('16/05/2025'), findsOneWidget);
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(draft!.measuredAt, DateTime(2025, 5, 16));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('small screen with keyboard, back and close flow', (
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
        home: const GrowthWeightInputScreen(easyReadMode: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '8.9');
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Tiếp tục')).bottom, lessThan(480));
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text('Đã cập nhật cân nặng mới!'), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const MaterialApp(home: GrowthOverview()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cập nhật chỉ số mới'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cân nặng'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Đóng cập nhật'));
    await tester.pumpAndSettle();
    expect(find.text('Tăng trưởng'), findsOneWidget);
    expect(find.byType(GrowthWeightInputScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
