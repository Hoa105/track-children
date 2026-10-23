import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/feeding/milk_calculator_screen.dart';
import 'package:track_children/services/demo_store.dart';
import 'package:track_children/features/home/home_screen.dart';

void main() {
  testWidgets('Home opens calculator for selected child', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1200);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
    await DemoStore.instance.login('demo@trackchildren.vn', DemoStore.password);
    await DemoStore.instance.selectChild('child_an');
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(childName: 'Bảo An')),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Lượng sữa'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Lượng sữa'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<MilkCalculatorScreen>(find.byType(MilkCalculatorScreen))
          .childId,
      'child_an',
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'calculates using explicit conditions and invalidates edited result',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      DemoStore.resetInstanceForTesting();
      final store = DemoStore.instance;
      await store.login('demo@trackchildren.vn', DemoStore.password);
      final birth = DateTime.now().subtract(const Duration(days: 20));
      final id = await store.saveChild(null, {
        'full_name': 'Bé thử',
        'date_of_birth': birth.toIso8601String(),
      });
      await store.addRecord(id, {
        'date': DateTime.now().toIso8601String(),
        'v0': 3.2,
      });
      tester.view.physicalSize = const Size(390, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: MilkCalculatorScreen(childId: id)),
      );
      expect(find.text('60 mL/cữ'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.text('Tính theo cân nặng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tính lượng sữa'));
      await tester.pumpAndSettle();
      expect(
        find.text('Vui lòng chọn tình trạng sức khỏe của bé.'),
        findsOneWidget,
      );
      expect(find.text('Vui lòng chọn hình thức bú của bé.'), findsOneWidget);
      expect(find.text('Chưa thể ước tính'), findsNothing);
      await tester.tap(find.text('Có'));
      await tester.pump();
      expect(
        find.text('Vui lòng chọn tình trạng sức khỏe của bé.'),
        findsNothing,
      );
      expect(find.text('Vui lòng chọn hình thức bú của bé.'), findsOneWidget);
      await tester.tap(find.text('Hoàn toàn bằng bình'));
      await tester.tap(find.text('Tính lượng sữa'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(find.textContaining('480 mL/ngày · 8 cữ/ngày'), findsOneWidget);
      await tester.tap(find.text('Tính theo cân nặng'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '3,5');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.textContaining('480 mL/ngày · 8 cữ/ngày'), findsOneWidget);
      expect(store.latest(id, 0), 3.2);
      await tester.tap(find.text('Tính theo cân nặng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Không / chưa rõ'));
      await tester.tap(find.text('Hoàn toàn bằng bình'));
      await tester.tap(find.text('Tính lượng sữa'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Chưa thể ước tính'), findsOneWidget);
      expect(
        find.textContaining('cần kế hoạch nuôi dưỡng riêng'),
        findsOneWidget,
      );
      expect(find.textContaining('480 mL/ngày'), findsNothing);
      expect(find.text('60 mL/cữ'), findsNothing);
      await tester.tap(find.text('Dùng mức mặc định'));
      await tester.pumpAndSettle();
      expect(find.text('60 mL/cữ'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      tester.view.physicalSize = const Size(320, 700);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
