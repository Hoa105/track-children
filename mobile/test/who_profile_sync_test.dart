import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/child/child_profile_screen.dart';
import 'package:track_children/features/growth/who_bmi_card.dart';
import 'package:track_children/services/demo_store.dart';
import 'package:track_children/services/who_bmi_reference.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
  });
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async => WhoBmiReference.load());
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'who_profile_Test_sex': 'girls',
      'who_profile_Test_birth': '2020-01-01',
    });
    DemoStore.resetInstanceForTesting();
    await DemoStore.instance.login('demo@trackchildren.vn', DemoStore.password);
    await DemoStore.instance.saveChild('child_an', {
      'gender': 'male',
      'date_of_birth': '2026-02-15',
    });
  });

  Widget card({bool compact = false, DateTime? measured}) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: WhoBmiCard(
          childId: 'child_an',
          childName: 'Test',
          compact: compact,
          preview: false,
          measured: measured ?? DateTime(2026, 10, 15),
          bmi: 17.4,
        ),
      ),
    ),
  );

  for (final compact in [true, false]) {
    testWidgets('profile is source of WHO metadata, compact=$compact', (
      tester,
    ) async {
      await tester.pumpWidget(card(compact: compact));
      await settle(tester);
      expect(
        find.text('Chuẩn WHO · Bé trai · 8 tháng tại ngày đo'),
        findsOneWidget,
      );
      expect(find.text('Bổ sung hồ sơ'), findsNothing);
      expect(find.byIcon(Icons.tune_rounded), findsNothing);
      await DemoStore.instance.saveChild('child_an', {
        'gender': 'female',
        'date_of_birth': '2026-01-15',
      });
      await settle(tester);
      expect(
        find.text('Chuẩn WHO · Bé gái · 9 tháng tại ngày đo'),
        findsOneWidget,
      );
      await tester.pumpWidget(
        card(compact: compact, measured: DateTime(2026, 5, 15)),
      );
      await settle(tester);
      expect(
        find.text('Chuẩn WHO · Bé gái · 4 tháng tại ngày đo'),
        findsOneWidget,
      );
      expect(find.text('Bổ sung hồ sơ'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('missing gender opens actual profile and follows saved changes', (
    tester,
  ) async {
    await DemoStore.instance.saveChild('child_an', {'gender': null});
    await tester.pumpWidget(card(compact: true));
    await settle(tester);
    expect(find.textContaining('Bé gái'), findsNothing);
    await tester.tap(find.text('Bổ sung hồ sơ'));
    await settle(tester);
    expect(find.byType(ChildProfileScreen), findsOneWidget);
    final profile = tester.widget<ChildProfileScreen>(
      find.byType(ChildProfileScreen),
    );
    expect(profile.initialFields!['id'], 'child_an');
    await profile.onSave!({'gender': 'male'}, null);
    await tester.pageBack();
    await settle(tester);
    expect(
      find.text('Chuẩn WHO · Bé trai · 8 tháng tại ngày đo'),
      findsOneWidget,
    );
    expect(find.text('Bổ sung hồ sơ'), findsNothing);
    expect(DemoStore.instance.childById('child_an')!['gender'], 'male');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'missing birthday requires profile, old WHO preferences are ignored',
    (tester) async {
      await DemoStore.instance.saveChild('child_an', {'date_of_birth': null});
      await tester.pumpWidget(card());
      await settle(tester);
      expect(find.text('Chuẩn WHO · Bé trai'), findsOneWidget);
      expect(find.text('Bổ sung hồ sơ'), findsOneWidget);
      expect(find.text('Trung vị tham chiếu'), findsNothing);
    },
  );
}
