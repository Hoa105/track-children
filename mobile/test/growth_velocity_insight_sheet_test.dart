import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_velocity_insight_sheet.dart';
import 'package:track_children/features/growth/growth_weight_velocity_data.dart';
import 'package:track_children/features/growth/growth_velocity_reference_scale.dart';

void main() {
  final point = GrowthWeightVelocityPoint(
    6,
    800,
    DateTime(2025, 1, 1),
    DateTime(2025, 7, 1),
    intervalMonths: 6,
    fromKg: 8,
    toKg: 8.8,
    zScore: .4,
    explanation: 'Nội dung đối chiếu của kỳ sáu tháng.',
    advice: const ['Lời khuyên đã duyệt cho kỳ sáu tháng.'],
  );
  for (final advice in [false, true]) {
    testWidgets(
      'six-month ${advice ? 'advice' : 'evidence'} follows selected interval',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GrowthVelocityInsightSheet(
                adviceMode: advice,
                point: point,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Chu kỳ 6 tháng'), findsOneWidget);
        expect(find.text(point.explanation!), findsOneWidget);
        if (advice) {
          expect(find.text(point.advice.single), findsOneWidget);
          expect(find.text('Kết quả của bé'), findsNothing);
        } else {
          expect(find.text('8 kg'), findsOneWidget);
          expect(find.text('8,8 kg'), findsOneWidget);
          expect(find.textContaining('× 1.000 = 800 g'), findsOneWidget);
          expect(find.byType(GrowthVelocityReferenceScale), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(GrowthVelocityReferenceScale),
              matching: find.text('Z-score WHO'),
            ),
            findsOneWidget,
          );
          expect(find.textContaining('g/tháng'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'missing advice stays explicit instead of inserting generic care advice',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: GrowthVelocityInsightSheet(adviceMode: true)),
        ),
      );
      expect(
        find.text('Chưa có gợi ý đã duyệt cho kỳ đo này.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
