import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/services/who_bmi_reference.dart';
import 'package:track_children/features/growth/who_bmi_card.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'official tables cover both sexes and prefer height row at 24 months',
    () async {
      final reference = await WhoBmiReference.load();
      for (final sex in ['boys', 'girls']) {
        for (var month = 0; month <= 60; month++) {
          final row = reference.row(sex, month)!;
          expect(row.length, 11);
          expect(row.first, month);
          for (var i = 4; i < 10; i++) {
            expect(row[i], lessThan(row[i + 1]));
          }
        }
      }
      expect(reference.row('boys', 0)![7], 13.4);
      expect(reference.row('girls', 0)![7], 13.3);
      expect(reference.row('girls', 24)![2], 15.6881);
      expect(reference.row('boys', 24)![2], 16.0189);
      expect(reference.row('boys', 61), isNull);
      expect(
        WhoBmiReference.ageMonths(DateTime(2025, 1, 31), DateTime(2025, 2, 28)),
        1,
      );
      expect(
        WhoBmiReference.ageMonths(DateTime(2025, 1, 15), DateTime(2025, 2, 14)),
        0,
      );
    },
  );
  testWidgets('preview displays official median without using real profile', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WhoBmiCard(
              childName: 'Test',
              preview: true,
              measured: DateTime(2026, 10, 15),
              bmi: 17.4,
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(
      find.text('Ví dụ mẫu · Chuẩn WHO · Bé trai · 8 tháng tại ngày đo'),
      findsOneWidget,
    );
    expect(find.textContaining('Trung vị tham chiếu'), findsOneWidget);
    expect(find.text('Chưa có khoảng tham chiếu'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
