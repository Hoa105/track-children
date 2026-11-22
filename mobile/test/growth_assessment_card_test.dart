import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/app_colors.dart';
import 'package:track_children/features/growth/growth_assessment_card.dart';

void main() {
  for (final (kind, code, label, color) in [
    ('bmi', 'SEVERE_THINNESS', 'Rất gầy', WeightChartColors.critical),
    ('bmi', 'THINNESS', 'Gầy', WeightChartColors.attention),
    ('bmi', 'WITHIN_RANGE', 'Cân đối', WeightChartColors.positive),
    ('bmi', 'RISK_OVERWEIGHT', 'Nguy cơ thừa cân', WeightChartColors.attention),
    ('bmi', 'OVERWEIGHT', 'Thừa cân', WeightChartColors.attention),
    ('bmi', 'OBESITY', 'Béo phì', WeightChartColors.critical),
    ('head', 'VERY_LOW_HC', 'Rất nhỏ', WeightChartColors.critical),
    ('head', 'LOW_HC', 'Nhỏ', WeightChartColors.attention),
    ('head', 'WITHIN_RANGE', 'Phù hợp', WeightChartColors.positive),
    ('head', 'HIGH_HC', 'Lớn', WeightChartColors.attention),
    ('head', 'VERY_HIGH_HC', 'Rất lớn', WeightChartColors.critical),
  ]) {
    testWidgets(
      '$kind $code shows inline summary without status badge or advice',
      (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: GrowthAssessmentCard(
                  kind: kind,
                  assessment: Future.value({
                    'current': {
                      'status': 'READY',
                      'classificationCode': code,
                      'visualRanges': [
                        {'code': code, 'label': label},
                      ],
                      'summary': 'Server assessment',
                      'action': 'Server advice',
                      'measuredOn': '2026-11-19',
                    },
                  }),
                  onTap: () => tapped = true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.text('Server assessment')).style!.color,
          color,
        );
        expect(find.text(label), findsNothing);
        expect(find.text('Server advice'), findsNothing);
        expect(find.text('Nên làm gì?'), findsNothing);
        expect(find.textContaining('Lần đo:'), findsNothing);
        expect(find.text('Xem chi tiết'), findsNothing);
        expect(find.byType(Icon), findsNWidgets(2));
        expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
        expect(
          find.text(kind == 'bmi' ? 'Đánh giá BMI' : 'Đánh giá vòng đầu'),
          findsOneWidget,
        );
        await tester.tap(find.text('Server assessment'));
        expect(tapped, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('not assessable result never displays a normal badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrowthAssessmentCard(
            kind: 'head',
            assessment: Future.value({
              'current': {
                'status': 'NOT_ASSESSABLE',
                'reason': 'WHO_FLAGGED',
                'classificationCode': 'WITHIN_RANGE',
                'visualRanges': [
                  {'code': 'WITHIN_RANGE', 'label': 'Phù hợp'},
                ],
                'summary': 'Kiểm tra lại số đo',
              },
            }),
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Phù hợp'), findsNothing);
    expect(
      tester.widget<Text>(find.text('Kiểm tra lại số đo')).style!.color,
      WeightChartColors.unknown,
    );
  });

  testWidgets('long summary fits narrow screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const summaryText =
        'Nhận xét từ hệ thống để phụ huynh theo dõi tình trạng của bé.';
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: GrowthAssessmentCard(
                kind: 'bmi',
                assessment: Future.value({
                  'current': {
                    'status': 'READY',
                    'classificationCode': 'RISK_OVERWEIGHT',
                    'classificationLabels': {
                      'RISK_OVERWEIGHT': 'Nguy cơ thừa cân',
                    },
                    'summary': summaryText,
                    'action': 'Hướng dẫn chăm sóc từ hệ thống. ' * 8,
                  },
                }),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(summaryText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

