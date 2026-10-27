import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/main.dart';
import 'package:track_children/features/growth/growth_weight_detail.dart';
import 'package:track_children/features/growth/growth_conclusion_explanation.dart';
import 'package:track_children/features/growth/growth_stature_detail.dart';
import 'package:track_children/features/growth/growth_head_detail.dart';
import 'package:track_children/features/growth/growth_bmi_detail.dart';

void main() {
  testWidgets('Opens BMI detail directly as the initial route', (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/growth/bmi-detail';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    await tester.pumpWidget(const TrackChildrenApp());
    await tester.pump();
    expect(find.byType(GrowthBmiDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Opens head detail directly as the initial route', (
    tester,
  ) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/growth/head-detail';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    await tester.pumpWidget(const TrackChildrenApp());
    await tester.pump();
    expect(find.byType(GrowthHeadDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Opens stature detail directly as the initial route', (
    tester,
  ) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/growth/length-detail';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    await tester.pumpWidget(const TrackChildrenApp());
    await tester.pump();
    expect(find.byType(GrowthStatureDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'Opens velocity explanation directly without fabricated context',
    (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/growth/weight-velocity-explanation';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      await tester.pumpWidget(const TrackChildrenApp());
      await tester.pump();
      expect(find.byType(GrowthConclusionExplanationScreen), findsOneWidget);
      expect(
        find.text(
          'Chưa có lần đo được chọn. Hãy mở phần giải thích từ tab Tốc độ.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Opens explanation directly as the initial browser route', (
    tester,
  ) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/growth/weight-explanation';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    await tester.pumpWidget(const TrackChildrenApp());
    await tester.pump();
    expect(find.byType(GrowthConclusionExplanationScreen), findsOneWidget);
    expect(
      ModalRoute.of(
        tester.element(find.byType(GrowthConclusionExplanationScreen)),
      )!.settings.name,
      '/growth/weight-explanation',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Opens weight detail directly as the initial browser route', (
    tester,
  ) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/growth/weight-detail';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    await tester.pumpWidget(const TrackChildrenApp());
    await tester.pump();
    expect(find.byType(GrowthWeightDetailScreen), findsOneWidget);
    expect(
      ModalRoute.of(tester.element(find.byType(GrowthWeightDetailScreen)))!
          .settings
          .name,
      '/growth/weight-detail',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
