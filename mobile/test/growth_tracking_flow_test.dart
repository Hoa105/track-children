import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_repository.dart';
import 'package:track_children/features/growth/growth_tracking_flow.dart';
import 'package:track_children/features/growth/growth_overview.dart';

class FailedSave extends MockGrowthRepository {
  @override
  Future<void> createRecord(
    GrowthMetric metric,
    GrowthMeasurementDraft draft,
  ) async => throw StateError('offline');
}

class ReadOnly extends MockGrowthRepository {
  @override
  bool get canEdit => false;
}

class FailedRead extends MockGrowthRepository {
  @override
  Future<void> refreshMeasurements() async => throw StateError('offline');
}

class ReviewRepository extends MockGrowthRepository {
  @override
  Future<Map<String, dynamic>> parentAssessment(
    String kind, {
    String? selectedId,
  }) async => {
    'current': {
      'status': 'READY',
      'summary': 'Bé có thể có nguy cơ thừa cân.',
      'action': 'Tiếp tục theo dõi theo lịch.',
      'bmi': 17.4,
      'zScore': 1.4,
      'sourceStandard': 'WHO-2006',
      'sources': [
        {
          'metric': 'weight',
          'value': 10,
          'unit': 'kg',
          'measuredOn': '2026-11-01',
        },
        {
          'metric': 'height',
          'value': 76,
          'unit': 'cm',
          'measuredOn': '2026-11-02',
        },
      ],
    },
  };
}

void main() {
  testWidgets('overview reflows with large text and reports load failures', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: GrowthOverview(repository: MockGrowthRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(home: GrowthOverview(repository: FailedRead())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa tải được số đo.'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa tải được số đo.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('new editor starts empty with today and saves one metric', (
    tester,
  ) async {
    final repository = MockGrowthRepository();
    final before = (await repository.measurements(GrowthMetric.weight)).length;
    await tester.pumpWidget(
      MaterialApp(
        home: TrackingMeasurementEditor(
          repository: repository,
          metric: GrowthMetric.weight,
        ),
      ),
    );
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      isEmpty,
    );
    expect(find.textContaining('Hôm nay'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '12,25');
    await tester.tap(find.text('Lưu số đo'));
    await tester.pumpAndSettle();
    final after = await repository.measurements(GrowthMetric.weight);
    expect(after.length, before + 1);
    expect(after.last.value, 12.25);
    expect(DateUtils.isSameDay(after.last.measuredAt, DateTime.now()), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('height requires actual measurement position', (tester) async {
    final repository = MockGrowthRepository();
    final before = (await repository.measurements(GrowthMetric.lengthHeight))
        .length;
    await tester.pumpWidget(
      MaterialApp(
        home: TrackingMeasurementEditor(
          repository: repository,
          metric: GrowthMetric.lengthHeight,
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), '90');
    await tester.tap(find.text('Lưu số đo'));
    await tester.pumpAndSettle();
    expect(
      find.text('Mẹ hãy xác nhận bé được đo nằm hay đứng.'),
      findsOneWidget,
    );
    expect(
      (await repository.measurements(GrowthMetric.lengthHeight)).length,
      before,
    );
    await tester.tap(find.text('Đứng đo chiều cao'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu số đo'));
    await tester.pumpAndSettle();
    expect(
      (await repository.measurements(GrowthMetric.lengthHeight)).last.method,
      GrowthMeasurementMethod.standing,
    );
  });

  testWidgets('save failure preserves the typed value', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TrackingMeasurementEditor(
          repository: FailedSave(),
          metric: GrowthMetric.weight,
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), '12,5');
    await tester.tap(find.text('Lưu số đo'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      '12,5',
    );
    expect(find.text('Chưa thực hiện được. Vui lòng thử lại.'), findsOneWidget);
  });

  testWidgets('history delete requires confirmation and leaves height intact', (
    tester,
  ) async {
    final repository = MockGrowthRepository();
    final weights = (await repository.measurements(GrowthMetric.weight)).length;
    final heights = (await repository.measurements(GrowthMetric.lengthHeight))
        .length;
    await tester.pumpWidget(
      MaterialApp(
        home: TrackingHistoryScreen(
          repository: repository,
          metric: GrowthMetric.weight,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(
      (await repository.measurements(GrowthMetric.weight)).length,
      weights,
    );
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
    await tester.pumpAndSettle();
    expect(
      (await repository.measurements(GrowthMetric.weight)).length,
      weights - 1,
    );
    expect(
      (await repository.measurements(GrowthMetric.lengthHeight)).length,
      heights,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('read only history has no edit or delete controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TrackingHistoryScreen(
          repository: ReadOnly(),
          metric: GrowthMetric.weight,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.byTooltip('Ghi số đo'), findsNothing);
  });

  testWidgets(
    'assessment shows both source dates and hides technical details initially',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TrackingAssessmentScreen(
            repository: ReviewRepository(),
            kind: 'bmi',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bé có thể có nguy cơ thừa cân.'), findsOneWidget);
      expect(find.text('01/11/2026'), findsOneWidget);
      expect(find.text('02/11/2026'), findsOneWidget);
      expect(find.textContaining('Z-score:'), findsNothing);
      expect(find.textContaining('xu hướng'), findsNothing);
    },
  );
}
