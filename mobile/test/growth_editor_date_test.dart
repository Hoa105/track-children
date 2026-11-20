import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_repository.dart';
import 'package:track_children/features/growth/growth_tracking_flow.dart';

class DateRepository extends GrowthRepository {
  DateRepository(this.birth);
  final DateTime? birth;
  final saved = <DateTime>[];
  int deletes = 0;
  @override
  DateTime? get dateOfBirth => birth;
  @override
  Future<void> updateRecord(
    GrowthMetric metric,
    GrowthMeasurementDraft original,
    GrowthMeasurementDraft draft,
  ) async => saved.add(draft.measuredAt);
  @override
  Future<void> saveMeasurement(
    GrowthMetric metric,
    GrowthMeasurementDraft draft,
  ) async => saved.add(draft.measuredAt);
  @override
  Future<void> saveBmiMeasurements({
    required DateTime measuredAt,
    required double weightKg,
    required double heightCm,
    required GrowthMeasurementMethod heightMethod,
  }) async => saved.add(measuredAt);
  @override
  Future<void> deleteRecord(
    GrowthMetric metric,
    GrowthMeasurementDraft draft,
  ) async {
    deletes++;
  }
}

Widget editor(int kind, DateRepository repo, DateTime day) {
  if (kind == 3) {
    return TrackingBmiQuickEditor(repository: repo, initialDate: day);
  }
  if (kind == 4) {
    return TrackingHeadQuickEditor(repository: repo, initialDate: day);
  }
  return TrackingMeasurementEditor(
    repository: repo,
    metric: GrowthMetric.values[kind],
    original: GrowthMeasurementDraft(
      id: 'existing',
      value: kind == 0
          ? 5
          : kind == 1
          ? 75
          : 45.5,
      measuredAt: day,
      method: kind == 1 ? GrowthMeasurementMethod.recumbent : null,
    ),
  );
}

Future<void> open(
  WidgetTester tester,
  int kind,
  DateRepository repo,
  DateTime day,
) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => editor(kind, repo, day)),
            ),
            child: const Text('Open editor'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester, int kind) async {
  final fields = find.byType(TextFormField);
  for (var i = 0; i < fields.evaluate().length; i++) {
    await tester.enterText(
      fields.at(i),
      kind == 3
          ? (i == 0 ? '5' : '75')
          : kind == 0
          ? '5'
          : kind == 1
          ? '75'
          : '45,5',
    );
  }
  await tester.ensureVisible(find.byType(FilledButton).last);
  await tester.tap(find.byType(FilledButton).last);
  await tester.pumpAndSettle();
}

void main() {
  final birth = DateTime(2025, 1, 15);
  final today = DateUtils.dateOnly(DateTime.now());
  for (var kind = 0; kind < 5; kind++) {
    testWidgets('editor $kind calendar only allows birth through today', (
      tester,
    ) async {
      final repo = DateRepository(birth);
      await open(tester, kind, repo, today);
      await tester.scrollUntilVisible(
        find.text('Ngày đo'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Ngày đo'));
      await tester.pumpAndSettle();
      final dialog = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(dialog.firstDate, birth);
      expect(dialog.lastDate, today);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.saved, isEmpty);
      expect(tester.takeException(), isNull);
    });

    for (final day in [
      birth.subtract(const Duration(days: 1)),
      today.add(const Duration(days: 1)),
    ]) {
      testWidgets(
        'editor $kind rejects invalid initial date $day before writing',
        (tester) async {
          final repo = DateRepository(birth);
          await open(tester, kind, repo, day);
          await save(tester, kind);
          expect(
            find.text('Ngày đo phải từ ngày sinh đến hôm nay.'),
            findsOneWidget,
          );
          expect(repo.saved, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final day in [birth, today]) {
      testWidgets('editor $kind accepts boundary date $day', (tester) async {
        final repo = DateRepository(birth);
        await open(tester, kind, repo, day);
        await save(tester, kind);
        expect(repo.saved, [day]);
        expect(find.text('Open editor'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'editor $kind blocks calendar and save when birth is unavailable',
      (tester) async {
        final repo = DateRepository(null);
        await open(tester, kind, repo, today);
        await tester.scrollUntilVisible(
          find.text('Ngày đo'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Ngày đo'));
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsNothing);
        await save(tester, kind);
        expect(
          find.text('Chưa tải được ngày sinh của bé. Vui lòng thử lại.'),
          findsOneWidget,
        );
        expect(repo.saved, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    if (kind < 3) {
      testWidgets(
        'editor $kind delete is text only and cancel keeps the record',
        (tester) async {
          final repo = DateRepository(birth);
          await open(tester, kind, repo, today);
          expect(find.byIcon(Icons.delete_forever_rounded), findsNothing);
          expect(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.text('Xóa'),
            ),
            findsOneWidget,
          );
          await tester.tap(find.text('Xóa'));
          await tester.pumpAndSettle();
          expect(find.text('Xóa số đo?'), findsOneWidget);
          await tester.tap(find.text('Hủy'));
          await tester.pumpAndSettle();
          expect(repo.deletes, 0);
          expect(find.byType(TrackingMeasurementEditor), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
