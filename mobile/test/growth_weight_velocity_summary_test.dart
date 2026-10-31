import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_repository.dart';
import 'package:track_children/features/growth/growth_weight_velocity_data.dart';
import 'package:track_children/features/growth/growth_weight_velocity_summary.dart';
import 'package:track_children/features/growth/growth_velocity_insight_sheet.dart';

List<GrowthWeightVelocityPoint> samples(List<double> grams) => [
  for (var i = 0; i < grams.length; i++)
    GrowthWeightVelocityPoint(
      8 + i,
      grams[i],
      DateTime(2025, 1 + i, 15),
      DateTime(2025, 2 + i, 15),
    ),
];

void main() {
  test(
    'Presentation handles higher, lower, equal, oscillating and missing rates',
    () {
      final lower = GrowthVelocitySummary(samples([500, 400]));
      expect(lower.latest!.grams, 400);
      expect(lower.delta, -100);
      expect(lower.comment, contains('ít hơn 100 g'));
      expect(lower.direction, 'Tốc độ giảm so với tháng trước');
      expect(GrowthVelocitySummary(samples([300, 400])).delta, 100);
      expect(
        GrowthVelocitySummary(samples([400, 400])).direction,
        'Ít thay đổi',
      );
      expect(
        GrowthVelocitySummary(samples([300, 500, 400])).direction,
        'Dao động qua các kỳ',
      );
      expect(GrowthVelocitySummary(samples([400])).delta, isNull);
      expect(GrowthVelocitySummary(const []).latest, isNull);
      final gaps = [
        samples([400]).first,
        GrowthWeightVelocityPoint(
          10,
          500,
          DateTime(2025, 3, 15),
          DateTime(2025, 4, 15),
        ),
      ];
      expect(GrowthVelocitySummary(gaps).delta, isNull);
    },
  );
  testWidgets(
    'Shows facts and expands four evidence groups, supports WHO result',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final points = samples([500, 400]);
      final result = GrowthVelocityWhoResult(
        zScore: .4,
        from: points.last.from,
        to: points.last.to,
        classification: 'Phân loại từ kết quả mẫu',
        comparison: 'Giá trị đối chiếu do bộ đánh giá cung cấp',
        explanation: 'Diễn giải từ kết quả mẫu.',
        sourceUrl: 'https://www.who.int/tools/child-growth-standards/standards/weight-velocity',
        version: 'Phiên bản tham chiếu của kết quả mẫu',
      );
      final summary = GrowthVelocitySummary(points);
      final readings = [
        GrowthMeasurementDraft(value: 8.1, measuredAt: DateTime(2025, 1, 15)),
        GrowthMeasurementDraft(value: 8.6, measuredAt: DateTime(2025, 2, 15)),
        GrowthMeasurementDraft(value: 9, measuredAt: DateTime(2025, 3, 15)),
      ];
      Future<void> show(GrowthVelocityWhoResult? who) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  GrowthVelocityHighlights(summary: summary),
                  GrowthVelocityAssessment(
                    summary: summary,
                    readings: readings,
                    whoResult: who,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await show(null);
      expect(find.text('+400\u00A0g', findRichText: true), findsOneWidget);
      expect(find.text('Ít hơn 100\u00A0g'), findsOneWidget);
      expect(find.text(summary.comment), findsOneWidget);
      await tester.ensureVisible(find.text('Vì sao có nhận xét này'));
      await tester.tap(find.text('Vì sao có nhận xét này'));
      await tester.pumpAndSettle();
      expect(find.text('Kết quả của bé'), findsOneWidget);
      expect(find.byType(GrowthVelocityInsightSheet), findsOneWidget);
      expect(find.textContaining('(9 - 8,6) × 1.000 = 400 g'), findsOneWidget);
      expect(
        find.text('−100 g so với kỳ liền trước cùng độ dài.'),
        findsOneWidget,
      );
      expect(find.text('Căn cứ đánh giá theo WHO'), findsOneWidget);
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      await show(result);
      expect(find.text('Mức tăng cân trong kỳ của bé'), findsNothing);
      expect(result.matches(points.first), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
