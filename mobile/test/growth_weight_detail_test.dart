import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_overview.dart';
import 'package:track_children/features/growth/growth_weight_detail.dart';

class DetailRepository extends GrowthRepository {
  bool fail = false;
  Completer<List<GrowthMeasurementDraft>>? pending;
  @override
  Future<List<GrowthMetricViewData>> loadOverview() async => [];
  @override
  Future<List<GrowthMeasurementDraft>> weightMeasurements() async {
    if (fail) throw StateError('offline');
    return pending?.future ?? [];
  }
}

class PreparedReferenceRepository extends MockGrowthRepository {
  PreparedReferenceRepository(this.reference);
  final GrowthWeightReference reference;
  @override
  Future<GrowthWeightReference?> weightReference() async => reference;
  static final statureReferences = <bool, GrowthStatureReference?>{};
  @override
  Future<GrowthStatureReference?> statureReference(bool length) async =>
      statureReferences[length];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GrowthWeightReference preparedReference;
  setUp(() async {
    rootBundle.evict('assets/data/who/weight_for_age_curves.json');
    preparedReference = GrowthWeightReference.fromJson(
      jsonDecode(
        await rootBundle.loadString(
          'assets/data/who/weight_for_age_curves.json',
        ),
      ) as Map<String, dynamic>,
      GrowthReferenceSex.boys,
    );
    final source = MockGrowthRepository();
    for (final length in [true, false]) {
      PreparedReferenceRepository.statureReferences[length] = await source
          .statureReference(length);
    }
  });
  test(
    'chart calendar age handles month end and the inclusive 60-month limit',
    () {
      final birth = DateTime(2024, 5, 15);
      expect(growthChartAgeMonths(birth, DateTime(2024, 5, 15)), 0);
      expect(growthChartAgeMonths(birth, DateTime(2025, 5, 15)), 12);
      expect(growthChartAgeMonths(birth, DateTime(2029, 5, 15)), 60);
      expect(growthChartAgeMonths(birth, DateTime(2029, 5, 16)), isNull);
      expect(growthChartAgeMonths(birth, DateTime(2024, 5, 14)), isNull);
      expect(
        growthChartAgeMonths(DateTime(2024, 1, 31), DateTime(2024, 2, 29)),
        1,
      );
    },
  );
  testWidgets('detail screenshot, point selection, tabs and large text', (
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
    final repo = PreparedReferenceRepository(preparedReference);
    await repo.weightReference();
    await repo.saveWeight(
      GrowthMeasurementDraft(value: 8.8, measuredAt: DateTime(2025, 5, 15)),
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: GrowthWeightDetailScreen(repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('8,8 kg'), findsOneWidget);
    expect(find.byType(GrowthWeightMeasurementChart), findsOneWidget);
    final chart = tester.widget<GrowthWeightMeasurementChart>(
      find.byType(GrowthWeightMeasurementChart),
    );
    expect(chart.reference!.rows.length, 61);
    expect(chart.points.last.value, 8.8);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final capture = await boundary.toImage(pixelRatio: 2);
      final png = await capture.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
        '../docs/growth/screenshots/weight-detail-overview.png',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(png!.buffer.asUint8List());
      capture.dispose();
    });
    await tester.ensureVisible(find.byType(DropdownButton<int>));
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9 \u2013 12 th\u00e1ng').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<GrowthWeightMeasurementChart>(
            find.byType(GrowthWeightMeasurementChart),
          )
          .maxAgeMonths,
      12,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    tester.view.physicalSize = const Size(320, 740);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: GrowthWeightDetailScreen(repository: repo, easyReadMode: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('overview to detail, update and save refresh shared values', (
    tester,
  ) async {
    final repo = PreparedReferenceRepository(preparedReference);
    await tester.pumpWidget(
      MaterialApp(home: GrowthOverview(repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('8,5 kg'));
    await tester.pumpAndSettle();
    expect(find.byType(GrowthWeightDetailScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Cập nhật cân nặng'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '9,1');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu kết quả'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Về tổng quan'));
    await tester.pumpAndSettle();
    expect(find.byType(GrowthWeightDetailScreen), findsOneWidget);
    expect(find.text('9,1 kg'), findsOneWidget);
    await tester.tap(find.byTooltip('Về tổng quan tăng trưởng'));
    await tester.pumpAndSettle();
    expect(find.text('9,1 kg'), findsOneWidget);
    expect(find.byType(GrowthWeightDetailScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading, empty and error retry states', (tester) async {
    final repo = DetailRepository()
      ..pending = Completer<List<GrowthMeasurementDraft>>();
    await tester.pumpWidget(
      MaterialApp(home: GrowthWeightDetailScreen(repository: repo)),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repo.pending!.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('Chưa có số đo cân nặng'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    repo.fail = true;
    await tester.pumpWidget(
      MaterialApp(home: GrowthWeightDetailScreen(repository: repo)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa tải được cân nặng.'), findsOneWidget);
    repo.fail = false;
    repo.pending = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có số đo cân nặng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'age filter excludes older measurements without changing latest reading',
    (tester) async {
      final repo = PreparedReferenceRepository(preparedReference);
      await repo.saveWeight(
        GrowthMeasurementDraft(value: 12, measuredAt: DateTime(2026, 5, 15)),
      );
      await tester.pumpWidget(
        MaterialApp(home: GrowthWeightDetailScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      expect(find.text('12 kg'), findsOneWidget);
      await tester.ensureVisible(find.byType(DropdownButton<int>));
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('9 – 12 tháng').last);
      await tester.pumpAndSettle();
      final chart = tester.widget<GrowthWeightMeasurementChart>(
        find.byType(GrowthWeightMeasurementChart),
      );
      expect(chart.points.any((p) => p.measuredAt.year == 2026), isFalse);
      expect(
        chart.points.every(
          (p) => growthChartAgeMonths(repo.dateOfBirth, p.measuredAt)! <= 12,
        ),
        isTrue,
      );
      expect(find.text('12 kg'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
