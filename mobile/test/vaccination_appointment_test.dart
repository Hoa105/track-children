import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/vaccination/vaccination_screen.dart';
import 'package:track_children/features/vaccination/vaccine_appointment_sheet.dart';
import 'package:track_children/services/demo_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
    await DemoStore.instance.login('demo@trackchildren.vn', DemoStore.password);
  });

  /// Opens the sheet the way the vaccination book does (a modal route).
  Future<void> openSheet(WidgetTester tester) async {
    final dose = vaccinationSchedule('child_an')
        .firstWhere((v) => v.dose.id == 'measles-1');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) =>
                    VaccineAppointmentSheet(childId: 'child_an', vaccine: dose),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('parent sets, then clears, an appointment for a scheduled dose', (
    tester,
  ) async {
    final store = DemoStore.instance;
    final expected = vaccinationSchedule('child_an')
        .firstWhere((v) => v.dose.id == 'measles-1')
        .dueDate;

    await openSheet(tester);
    expect(find.text('Sửa thông tin'), findsOneWidget);
    expect(find.text('Xóa thông tin đã lưu · dùng ngày dự kiến'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('appointment-place')),
      'Trạm y tế phường',
    );
    await tester.tap(find.byKey(const ValueKey('appointment-product')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MVVac · Việt Nam').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('appointment-save')));
    await tester.pumpAndSettle();
    expect(find.byType(VaccineAppointmentSheet), findsNothing);

    final saved = store.vaccinations('child_an').single;
    expect(saved['id'], 'measles-1');
    expect(saved['given'], isFalse);
    expect(saved['place'], 'Trạm y tế phường');
    expect(saved['product'], 'mvvac');
    // Mặc định là ngày dự kiến của lịch
    expect(DateTime.parse(saved['date'] as String), expected);
    final booked = vaccinationSchedule('child_an')
        .firstWhere((v) => v.dose.id == 'measles-1');
    expect(booked.hasAppointment, isTrue);
    expect(booked.appointmentPlace, 'Trạm y tế phường');
    // Ghi nhận đã tiêm sẽ điền sẵn loại vắc-xin này
    expect(booked.plannedProduct, 'mvvac');

    await openSheet(tester);
    await tester.tap(find.text('Xóa thông tin đã lưu · dùng ngày dự kiến'));
    await tester.pumpAndSettle();
    expect(store.vaccinations('child_an'), isEmpty);
  });
}
