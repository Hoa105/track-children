import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_models.dart';
import 'package:track_children/features/growth/growth_weight_assessment.dart';
import 'package:track_children/features/growth/growth_weight_insight_sheet.dart';

void main() {
  setUpAll(() async {
    for (final f in {
      'Nunito': 'nunito/Nunito-Variable.ttf',
      'DancingScript': 'dancing_script/DancingScript-Variable.ttf',
    }.entries) {
      await (FontLoader(f.key)..addFont(
            Future.value(
              ByteData.sublistView(
                await File('assets/fonts/${f.value}').readAsBytes(),
              ),
            ),
          ))
          .load();
    }
    final config = File('.dart_tool/package_config.json').absolute;
    final packages =
        jsonDecode(await config.readAsString())['packages'] as List;
    final root = config.uri.resolve(
      '${packages.singleWhere((p) => p['name'] == 'flutter')['rootUri']}/',
    );
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(
            ByteData.sublistView(
              await File.fromUri(
                root.resolve(
                  '../../bin/cache/artifacts/material_fonts/materialicons-regular.otf',
                ),
              ).readAsBytes(),
            ),
          ),
        ))
        .load();
  });
  const wfa = GrowthIndexAssessment(
    classification: 'Không nhẹ cân',
    zScore: -.45,
    explanation: 'Cân nặng theo tuổi nằm trong dải tham chiếu đang áp dụng. Chỉ số này không xác định thừa cân.',
    advice: ['Mang lịch sử cân đến buổi tư vấn để xem diễn tiến các lần đo.'],
  );
  const wfl = GrowthIndexAssessment(
    classification: 'Cân đối theo chiều dài',
    zScore: .3,
    explanation: 'Kết quả theo chiều dài của lần đo này.',
    overview: 'Cân nặng của bé đang cân đối với chiều dài hiện tại.',
    advice: ['Kiểm tra chiều dài đo nằm và cân nặng cùng ngày.'],
  );

  for (final advice in [false, true]) {
    testWidgets(
      '${advice ? 'advice' : 'explanation'} sheet keeps indicator-specific content',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Nunito'),
            home: Scaffold(
              backgroundColor: const Color(0xFFE8ECEF),
              body: RepaintBoundary(
                key: const Key('capture'),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: GrowthWeightInsightSheet(
                    adviceMode: advice,
                    weight: 10.2,
                    statureLabel: 'chiều dài',
                    ageMonths: 20.4,
                    measuredAt: DateTime(2026, 1, 15),
                    wfa: wfa,
                    wflh: wfl,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const Key('capture')),
          matchesGoldenFile(
            'goldens/weight-insight-${advice ? 'advice' : 'explanation'}.png',
          ),
        );
        await tester.tap(find.text('Theo chiều dài'));
        await tester.pumpAndSettle();
        if (advice) {
          expect(find.text('Dinh dưỡng'), findsOneWidget);
          expect(find.text('Vận động'), findsOneWidget);
          expect(find.text('Theo dõi'), findsOneWidget);
          expect(find.text(wfa.advice.single), findsNothing);
        } else {
          expect(find.text(wfl.explanation), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('overview smile and both entry points open dismissible sheets', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GrowthWeightAssessment(
              weight: 10.2,
              statureLabel: 'chiều dài',
              ageMonths: 20,
              sexLabel: 'bé gái',
              overviewOnly: true,
              assessment: GrowthWeightAssessmentData(
                wfa: wfa,
                wflh: wfl,
                combinedSummary: 'Nhận xét của lần đo hiện tại.',
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Cân nặng của bé thế nào?'), findsOneWidget);
    expect(find.text('${wfl.overview}\n\n${wfl.advice.single}'), findsOneWidget);
    expect(find.text('Nhận xét của lần đo hiện tại.'), findsNothing);
    for (final title in ['Vì sao có nhận xét này', 'Gợi ý cho ba mẹ']) {
      await tester.ensureVisible(find.text(title));
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.byType(GrowthWeightInsightSheet), findsOneWidget);
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();
      expect(find.byType(GrowthWeightInsightSheet), findsNothing);
    }
  });
}
