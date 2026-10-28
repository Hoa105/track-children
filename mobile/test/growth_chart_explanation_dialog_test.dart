import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_chart_explanation_dialog.dart';

void main() {
  testWidgets('Explanation scrolls at 320px and large text and closes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const GrowthChartExplanationDialog(
                  title: Text('Cân nặng theo chiều dài'),
                  content: Text(
                    'Trục ngang và trục dọc.\n\nCác đường WHO theo giới tính.\n\nChọn khoảng chiều dài để theo dõi.\n\nGhi chú cuối cùng.',
                  ),
                  actions: [],
                ),
              ),
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    expect(find.text('Cùng đọc biểu đồ'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Ghi chú cuối cùng.'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });
}
