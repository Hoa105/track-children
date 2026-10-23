import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/vaccination/vaccination_history.dart';
import 'package:track_children/models/vaccination.dart';

ScheduledVaccine entry(String id, String name, DateTime date, String place) =>
    ScheduledVaccine(
      dose: VaccineDose(
        id: id,
        name: name,
        prevents: name,
        doseLabel: 'Mũi 1',
        ageMonths: 0,
      ),
      dueDate: date,
      record: VaccinationRecord(
        childId: 'test-child',
        doseId: id,
        date: date,
        place: place,
        reaction: 'Không ghi nhận phản ứng',
      ),
      status: VaccineStatus.done,
    );

void main() {
  final records = [
    entry('bcg', 'BCG', DateTime(2026, 10, 12), 'Trạm y tế phường A'),
    entry('polio', 'Bại liệt', DateTime(2025, 10, 12), 'Bệnh viện B'),
    entry('rota', 'Rotavirus', DateTime(2026, 9, 1), 'Trạm y tế phường A'),
  ];

  testWidgets('vaccine filter finds older doses and resets', (tester) async {
    ScheduledVaccine? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VaccinationHistory(
            childId: 'test-child',
            records: records,
            onSelect: (v) => selected = v,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byTooltip('Lọc vắc-xin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rotavirus').last);
    await tester.pumpAndSettle();
    expect(find.text('1 mũi · 1 buổi tiêm'), findsOneWidget);
    await tester.tap(find.byTooltip('Lọc vắc-xin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bại liệt').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bại liệt').last);
    expect(selected?.dose.id, 'polio');
    await tester.tap(find.text('Bỏ lọc'));
    await tester.pumpAndSettle();
    expect(find.text('3 mũi · 3 buổi tiêm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('year filter combines with vaccine filter and resets', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VaccinationHistory(
            childId: 'test-child',
            records: records,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Lọc năm tiêm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2025'));
    await tester.pumpAndSettle();
    expect(find.text('1 mũi · 1 buổi tiêm'), findsOneWidget);
    expect(find.text('Bại liệt'), findsOneWidget);
    await tester.tap(find.byTooltip('Lọc vắc-xin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BCG').last);
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy mũi phù hợp'), findsOneWidget);
    await tester.tap(find.text('Xóa bộ lọc'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mới nhất trước'));
    await tester.pumpAndSettle();
    expect(find.text('Bại liệt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'history filters stay accessible with large text on a small screen',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: VaccinationHistory(
              childId: 'test-child',
              records: records,
              onSelect: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final filter = find.byTooltip('Lọc vắc-xin');
      final before = tester.getCenter(filter);
      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(tester.getCenter(filter), before);
      await tester.tap(filter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bại liệt').last);
      await tester.pumpAndSettle();
      expect(find.text('1 mũi · 1 buổi tiêm'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
