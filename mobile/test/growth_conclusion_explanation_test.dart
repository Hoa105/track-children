import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_weight_assessment.dart';
import 'package:track_children/features/growth/growth_conclusion_explanation.dart';

void main() {
  testWidgets('Assessment opens tt10 explanation, source and back navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const capture = ValueKey('capture');
    await tester.runAsync(() async {
      for (final entry in {
        'Nunito': 'assets/fonts/nunito/Nunito-Variable.ttf',
        'DancingScript':
            'assets/fonts/dancing_script/DancingScript-Variable.ttf',
        'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      }.entries) {
        await (FontLoader(
          entry.key,
        )..addFont(rootBundle.load(entry.value))).load();
      }
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Nunito'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: GrowthWeightAssessment(
                weight: 8.8,
                statureLabel: 'chiều dài',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Vì sao có kết luận này?'));
    await tester.pumpAndSettle();
    expect(find.byType(GrowthConclusionExplanationScreen), findsOneWidget);
    expect(find.text('Căn cứ đánh giá'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.ensureVisible(find.text('Nguồn tham khảo'));
    await tester.tap(find.textContaining('Tiêu chuẩn tăng trưởng trẻ em'));
    await tester.pumpAndSettle();
    expect(find.text('WHO Child Growth Standards'), findsOneWidget);
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.byType(GrowthConclusionExplanationScreen), findsNothing);
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: const GrowthConclusionExplanationScreen(easyRead: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Nguồn tham khảo'));
    expect(tester.takeException(), isNull);
  });
}
