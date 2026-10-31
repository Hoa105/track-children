import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_velocity_interpretation.dart';

void main() {
  for (final z in [-2.3, 0.0, 2.3, null, double.nan]) {
    testWidgets('interpretation at $z supports narrow large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: GrowthVelocityInterpretation(
                  grams: 350,
                  zScore: z,
                  from: DateTime(2025, 1, 1),
                  to: DateTime(2025, 2, 1),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('1/1/2025 – 1/2/2025'), findsOneWidget);
      if (z == null || !z.isFinite) {
        expect(
          find.text('Chỉ ghi nhận mức tăng — chưa có đối chiếu WHO phù hợp.'),
          findsOneWidget,
        );
        expect(find.byType(ExpansionTile), findsNothing);
      } else {
        expect(find.text(growthVelocityPosition(z)), findsOneWidget);
      }
      expect(find.text('Z-score này có nghĩa gì?'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
