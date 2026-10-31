import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_repository.dart';
import 'package:track_children/features/growth/stature_velocity_data.dart';
import 'package:track_children/features/growth/stature_overview.dart';
import 'package:track_children/features/growth/stature_velocity_view.dart';
import 'package:track_children/features/growth/weight_chart_view.dart';
import 'package:track_children/features/growth/stature_insight_sheet.dart';

final raw = jsonDecode(
  File('assets/data/who/stature_velocity_periods.json').readAsStringSync(),
) as Map<String, dynamic>;
StatureVelocityReference ref(int period, [String sex = 'boys']) =>
    StatureVelocityReference.fromJson(raw, sex, period);
GrowthMeasurementDraft reading(
  int month,
  double value, {
  int days = 0,
  GrowthMeasurementMethod method = GrowthMeasurementMethod.recumbent,
}) => GrowthMeasurementDraft(
  value: value,
  measuredAt: DateTime(2024, 1 + month, 15 + days),
  method: method,
);

class _Repo extends GrowthRepository {
  @override
  DateTime get dateOfBirth => DateTime(2024, 1, 15);
  @override
  Future<List<GrowthMetricViewData>> loadOverview() async => [];
  @override
  Future<StatureVelocityReference?> statureVelocityPeriodReference(
    int period,
  ) async => ref(period);
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final entry in {
      'Nunito': 'assets/fonts/nunito/Nunito-Variable.ttf',
      'DancingScript': 'assets/fonts/dancing_script/DancingScript-Variable.ttf',
    }.entries) {
      await (FontLoader(entry.key)..addFont(
            Future.value(
              ByteData.sublistView(File(entry.value).readAsBytesSync()),
            ),
          ))
          .load();
    }
  });
  testWidgets(
    'both evidence sheets follow weight format and support large text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final velocity in [false, true]) {
        for (final scale in [1.0, 2.0]) {
          final boundary = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(fontFamily: 'Nunito'),
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(390, 844),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: RepaintBoundary(
                    key: boundary,
                    child: StatureInsightSheet(
                      measurement: reading(12, 74),
                      birth: DateTime(2024, 1, 15),
                      zScore: .2,
                      label: 'Phù hợp',
                      period: velocity ? 2 : null,
                      interval: velocity
                          ? StatureVelocityInterval(
                              reading(10, 71),
                              reading(12, 74),
                              10,
                              12,
                              row: ref(2).rows[10],
                            )
                          : null,
                      reference: velocity ? ref(2) : null,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Kết quả của bé'), findsOneWidget);
          expect(find.text('Căn cứ đánh giá theo WHO'), findsOneWidget);
          expect(find.byTooltip('Quay lại'), findsOneWidget);
          expect(find.byTooltip('Đóng'), findsOneWidget);
          expect(
            find.text(velocity ? 'Chu kỳ 2 tháng' : 'Theo tuổi'),
            findsOneWidget,
          );
          expect(find.text('Z-score này có nghĩa gì?'), findsNothing);
          if (scale == 1 && const bool.fromEnvironment('STATURE_PREVIEW')) {
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage();
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                '../tmp/stature-${velocity ? 'velocity' : 'overview'}-insight-preview.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(data!.buffer.asUint8List());
            });
          }
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
  test(
    'all eight WHO tables retain intervals, precision and published SD values',
    () {
      for (final sex in ['boys', 'girls']) {
        for (final period in [2, 3, 4, 6]) {
          final table = ref(period, sex);
          expect(table.rows.length, 25 - period);
          expect(table.rows.last.end, 24);
          for (final r in table.rows) {
            expect(r.zScore(r.m), closeTo(0, 1e-9));
            expect(r.zScore(-.1), isNull);
            expect(r.zScore(0)!.isFinite, isTrue);
            for (final sd in [-3, -2, 0, 2, 3]) {
              if (1 + r.l * r.s * sd > 0) {
                expect(r.centile(sd.toDouble()), closeTo(r.sd[sd + 3], .051));
              }
            }
          }
        }
      }
    },
  );
  test('WHO 2009 p227 examples cover LMS and both extended tails', () {
    final rows = ref(3, 'girls').rows;
    expect(rows[9].zScore(7.5), closeTo(3.80, .02));
    expect(rows[15].zScore(.5), closeTo(-3.26, .02));
    expect(rows[3].zScore(8), closeTo(1.90, .02));
  });
  test('independent endpoints, tolerances, measurement method and 24-month boundary', () {
    final birth = DateTime(2024, 1, 15);
    final data = [
      reading(0, 50),
      reading(1, 54),
      reading(2, 58, days: 3),
      reading(4, 62),
    ];
    final points = statureVelocityIntervals(data, birth, 2, ref(2));
    expect(points.map((p) => p.gain), [8, 4]);
    expect(
      statureVelocityIntervals(
        [reading(0, 50), reading(2, 58, days: 4)],
        birth,
        2,
        ref(2),
      ),
      isEmpty,
    );
    expect(
      statureVelocityIntervals(
        [
          reading(0, 50),
          reading(2, 58, method: GrowthMeasurementMethod.standing),
        ],
        birth,
        2,
        ref(2),
      ),
      isEmpty,
    );
    final boundary = statureVelocityIntervals(
      [reading(22, 85), reading(24, 87), reading(26, 89)],
      birth,
      2,
      ref(2),
    );
    expect(boundary.length, 1);
    expect(boundary.single.row!.end, 24);
    final older = statureVelocityIntervals(
      [
        reading(24, 87, method: GrowthMeasurementMethod.standing),
        reading(26, 89, method: GrowthMeasurementMethod.standing),
      ],
      birth,
      2,
      ref(2),
    );
    expect(older.single.gain, 2);
    expect(older.single.z, isNull);
  });
  test('overview converts posture and preserves both reference values at 24 months', () {
    final birth = DateTime(2024, 1, 15);
    expect(
      statureValueForAge(
        reading(12, 75, method: GrowthMeasurementMethod.standing),
        birth,
      ),
      75.7,
    );
    expect(statureValueForAge(reading(30, 90), birth), 89.3);
    expect(statureAgeLabel(-3), 'Thấp');
    expect(statureAgeLabel(-2), 'Phù hợp');
    expect(statureAgeLabel(3), 'Phù hợp');
    expect(statureAgeLabel(3.1), 'Rất cao');
  });
  testWidgets(
    'period selection, separate insight, full screen and screenshot',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Nunito'),
          home: Scaffold(
            body: RepaintBoundary(
              key: boundary,
              child: ColoredBox(
                color: Colors.white,
                child: StatureVelocityView(
                  repository: _Repo(),
                  readings: [
                    for (var m = 0; m <= 12; m++)
                      reading(m, 50 + 2 * m.toDouble()),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Z-score này có nghĩa gì?'), findsNothing);
      expect(find.textContaining('trung vị tham chiếu WHO'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('stature-period-6')),
      );
      await tester.tap(find.byKey(const ValueKey('stature-period-6')));
      await tester.pumpAndSettle();
      expect(find.text('+12\u00A0cm'), findsOneWidget);
      expect(find.textContaining('Nhiều hơn'), findsNothing);
      if (const bool.fromEnvironment('STATURE_PREVIEW')) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final f = File('../tmp/stature-velocity-preview.png');
          await f.parent.create(recursive: true);
          await f.writeAsBytes(data!.buffer.asUint8List());
        });
      }
      await tester.ensureVisible(find.text('Vì sao có nhận xét này?'));
      await tester.tap(find.text('Vì sao có nhận xét này?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('trung vị tham chiếu WHO'), findsOneWidget);
      expect(find.text('Z-score này có nghĩa gì?'), findsNothing);
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Mở rộng biểu đồ'));
      await tester.tap(find.byTooltip('Mở rộng biểu đồ'));
      await tester.pumpAndSettle();
      expect(find.text('Mức tăng chiều dài · kỳ 6 tháng'), findsOneWidget);
      expect(
        find.byKey(const Key('stature-velocity-expanded-legend')),
        findsOneWidget,
      );
      expect(find.text('Số đo của bé'), findsOneWidget);
      expect(find.textContaining('Bán kính'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'expanded velocity matches overview layout at narrow and large text sizes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final width in [320.0, 390.0]) {
        tester.view.physicalSize = Size(width, 844);
        for (final scale in [1.0, 2.0]) {
          final boundary = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(fontFamily: 'Nunito'),
              home: Scaffold(
                appBar: AppBar(
                  title: const Text('Mức tăng chiều dài · kỳ 2 tháng'),
                ),
                body: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 844),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: RepaintBoundary(
                    key: boundary,
                    child: ColoredBox(
                      color: Colors.white,
                      child: StatureVelocityView(
                        key: ValueKey('$width-$scale'),
                        repository: _Repo(),
                        expanded: true,
                        readings: [
                          for (var m = 0; m <= 12; m++)
                            reading(m, 50 + 2 * m.toDouble()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(GrowthChartLegend), findsOneWidget);
          expect(find.textContaining('Bán kính'), findsNothing);
          final canvas = find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is StatureIncrementPainter,
          );
          expect(tester.getSize(canvas).height, closeTo(844 * .6, .01));
          if (width == 390 &&
              scale == 1 &&
              const bool.fromEnvironment('STATURE_PREVIEW')) {
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage();
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final f = File('../tmp/stature-velocity-expanded-preview.png');
              await f.parent.create(recursive: true);
              await f.writeAsBytes(data!.buffer.asUint8List());
            });
          }
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
  testWidgets(
    'overview combines separate length and height curves and screenshot',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final raw = jsonDecode(
        File('assets/data/who/stature_for_age_curves.json').readAsStringSync(),
      );
      GrowthWeightReference reference(String key) => GrowthWeightReference(
        sex: GrowthReferenceSex.boys,
        rows: [
          for (final r in raw['tables'][key])
            GrowthWeightReferenceRow((r[0] as num).toInt(), [
              for (final v in (r as List).skip(1)) (v as num).toDouble(),
            ]),
        ],
        sourceUrl: '',
        sourceHash: '',
      );
      final curves = statureAgeCurves(
        reference('length_boys'),
        reference('height_boys'),
      );
      final at24 = curves.where((c) => c.x == weightAgeTick(24)).toList();
      expect(at24.length, 2);
      expect(at24.first.kg[2] - at24.last.kg[2], closeTo(.7, .001));
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Nunito'),
          home: Scaffold(
            body: RepaintBoundary(
              key: boundary,
              child: ColoredBox(
                color: Colors.white,
                child: StatureOverview(
                  points: [
                    for (var m = 0; m <= 12; m++)
                      reading(m, 50 + 2 * m.toDouble()),
                  ],
                  repository: _Repo(),
                  lengthReference: reference('length_boys'),
                  heightReference: reference('height_boys'),
                  scoreFor: (_) => null,
                  onUpdate: () {},
                  onRetry: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<WeightChartView>(find.byType(WeightChartView)).unit,
        'cm',
      );
      if (const bool.fromEnvironment('STATURE_PREVIEW')) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final f = File('../tmp/stature-overview-preview.png');
          await f.parent.create(recursive: true);
          await f.writeAsBytes(data!.buffer.asUint8List());
        });
      }
      expect(tester.takeException(), isNull);
    },
  );
}
