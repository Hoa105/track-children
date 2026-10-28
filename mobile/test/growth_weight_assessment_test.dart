import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_models.dart';
import 'package:track_children/features/growth/growth_weight_assessment.dart';

void main() {
  const wfa = GrowthIndexAssessment(
    classification: 'Phù hợp với tuổi',
    zScore: -.8,
    explanation: 'Giải thích WFA',
  );
  const wflh = GrowthIndexAssessment(
    classification: 'Cần chú ý',
    zScore: 2.345,
    explanation: 'Giải thích WFLH',
  );
  testWidgets(
    'Separate scores, combined result, missing and out-of-scope states',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Future<void> show(
        double? age,
        GrowthWeightAssessmentData? data, {
        String? sex = 'bé trai',
      }) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GrowthWeightAssessment(
                weight: 8.5,
                statureLabel: 'chiều dài',
                ageMonths: age,
                sexLabel: sex,
                assessment: data,
              ),
            ),
          ),
        ),
      );
      const complete = GrowthWeightAssessmentData(
        wfa: wfa,
        wflh: wflh,
        combinedSummary: 'Nhận xét từ cả hai chỉ số',
      );
      await show(11, complete);
      expect(find.text('Theo tu\u1ed5i \u00b7 -0,80 SD'), findsOneWidget);
      expect(
        find.text('Theo chi\u1ec1u d\u00e0i \u00b7 +2,35 SD'),
        findsOneWidget,
      );
      expect(find.text('Cần chú ý'), findsOneWidget);
      expect(find.text('Nhận xét từ cả hai chỉ số'), findsOneWidget);
      await show(
        11,
        const GrowthWeightAssessmentData(
          wfa: wfa,
          combinedSummary: 'Không được hiển thị',
        ),
      );
      expect(find.text('Theo tu\u1ed5i \u00b7 -0,80 SD'), findsOneWidget);
      expect(find.text('Chưa đủ dữ liệu đánh giá'), findsNWidgets(2));
      expect(find.text('Không được hiển thị'), findsNothing);
      for (final age in [null, -1.0, 60.01]) {
        await show(age, complete);
        expect(find.textContaining(' SD'), findsNothing);
        expect(find.text('Chưa đủ dữ liệu đánh giá'), findsNWidgets(3));
      }
      await show(60, complete);
      expect(find.text('Theo tu\u1ed5i \u00b7 -0,80 SD'), findsOneWidget);
      await show(11, complete, sex: null);
      expect(find.textContaining(' SD'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
