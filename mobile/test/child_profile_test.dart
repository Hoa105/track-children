import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/child/child_profile_screen.dart';

void main() {
  const fields = <String, Object?>{
    'full_name': 'Nguyễn Minh An',
    'gender': 'male',
    'date_of_birth': '2025-04-02',
    'gestational_weeks': 36,
    'birth_weight_kg': 2.8,
  };
  for (final width in [320.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('profile width $width scale $scale and keyboard', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 800);
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const ChildProfileScreen(initialFields: fields),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Hồ sơ bé'), findsOneWidget);
        await tester.tap(find.text('Sửa'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField).first).readOnly,
          false,
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Cân nặng sơ sinh'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('validate before calling save and keep failed edits', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ChildProfileScreen(
          initialFields: fields,
          onSave: (data, avatar) async {
            calls++;
            throw Exception('offline');
          },
        ),
      ),
    );
    await tester.tap(find.text('Sửa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, ' ');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Vui lòng nhập tên bé.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Bé An');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Chưa lưu được hồ sơ. Vui lòng thử lại.'), findsOneWidget);
    expect(find.text('Lưu'), findsOneWidget);
  });
  testWidgets('save maps database fields and validates birth measurements', (
    tester,
  ) async {
    Map<String, Object?>? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: ChildProfileScreen(
          initialFields: fields,
          onSave: (data, avatar) async {
            saved = data;
          },
        ),
      ),
    );
    await tester.tap(find.text('Sửa'));
    await tester.pumpAndSettle();
    final weeks = find.byType(TextFormField).at(1);
    await tester.ensureVisible(weeks);
    await tester.enterText(weeks, '21');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(find.text('Tuổi thai từ 22 đến 45 tuần.'), findsOneWidget);
    await tester.ensureVisible(weeks);
    await tester.enterText(weeks, '36');
    final weight = find.byType(TextFormField).at(2);
    await tester.ensureVisible(weight);
    await tester.enterText(weight, '2,85');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(saved?['gestational_weeks'], 36);
    expect(saved?['birth_weight_kg'], 2.85);
    expect(saved?['date_of_birth'], '2025-04-02');
    expect(find.text('Sửa'), findsOneWidget);
    await tester.ensureVisible(find.text('Người cùng theo dõi'));
    await tester.tap(find.text('Người cùng theo dõi'));
    await tester.pumpAndSettle();
    expect(find.text('Chia sẻ hồ sơ bé'), findsOneWidget);
    expect(find.text('Bà Nguyễn Thị Mai'), findsNothing);
  });
}
