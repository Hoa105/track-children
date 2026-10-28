import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_repository.dart';
import 'package:track_children/features/growth/growth_weight_history.dart';
import 'package:track_children/features/growth/growth_weight_detail.dart';

class HistoryRepository extends GrowthRepository {
  @override
  DateTime get dateOfBirth => DateTime(2024, 5, 15);
  @override
  Future<List<GrowthMetricViewData>> loadOverview() async => const [];
  @override
  Future<List<GrowthMeasurementDraft>> weightMeasurements() async => [
    GrowthMeasurementDraft(value: 8.2, measuredAt: DateTime(2025, 3, 15)),
    GrowthMeasurementDraft(value: 8.5, measuredAt: DateTime(2025, 4, 15)),
  ];
}

void main() {
  test('History age uses birthday anchors including month-end', () {
    expect(
      growthHistoryAge(DateTime(2024, 5, 15), DateTime(2025, 4, 20)),
      '11 tháng 5 ngày',
    );
    expect(
      growthHistoryAge(DateTime(2024, 1, 31), DateTime(2024, 2, 29)),
      '1 tháng',
    );
    expect(growthHistoryAge(null, DateTime(2025)), 'Chưa có ngày sinh');
  });
  testWidgets(
    'History tab has newest-first timeline, deltas and reading detail',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = HistoryRepository();
      await tester.pumpWidget(
        MaterialApp(home: GrowthWeightDetailScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lịch sử'));
      await tester.pumpAndSettle();
      expect(find.text('Lịch sử đo'), findsOneWidget);
      expect(find.text('+300 g'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('15/04/2025')).dy,
        lessThan(tester.getTopLeft(find.text('15/03/2025')).dy),
      );
      await tester.tap(find.text('15/04/2025'));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết số đo'), findsOneWidget);
      expect(find.text('+300 g so với lần đo 15/03/2025.'), findsOneWidget);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tổng quan'));
      await tester.pumpAndSettle();
      expect(find.byType(GrowthWeightHistoryTab), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('History supports empty and narrow large text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = HistoryRepository();
    final data = await repo.weightMeasurements();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: GrowthWeightHistoryTab(
              readings: data,
              repository: repo,
              easyRead: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrowthWeightHistoryTab(readings: const [], repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa có số đo cân nặng.'), findsOneWidget);
  });
}
