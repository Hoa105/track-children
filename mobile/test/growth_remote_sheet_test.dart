import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_screen.dart';
import 'package:track_children/services/demo_store.dart';
import 'package:track_children/services/growth_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
    GrowthApi.instance = GrowthApi();
  });

  testWidgets(
    'remote form keeps entries on failure and saves only changed metric',
    (tester) async {
      var calls = 0;
      Map<String, dynamic>? saved;
      final now = DateTime.now();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showMeasurementSheet(
                  context,
                  records: [
                    {
                      'date': DateTime(
                        now.year,
                        now.month,
                        now.day,
                      ).toIso8601String(),
                      'v0': 8.4,
                      'v1': 69.5,
                      'v2': 43.7,
                      'measurePosition': 'lying',
                    },
                  ],
                  isPreview: false,
                  onSave: (record) async {
                    calls++;
                    if (calls == 1) {
                      throw GrowthApiException('DATABASE_UNAVAILABLE');
                    }
                    saved = record;
                  },
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final field = find.byType(TextFormField).first;
      expect(tester.widget<TextFormField>(field).controller!.text, '8.4');
      await tester.enterText(field, '8,5');
      await tester.ensureVisible(find.text('Lưu số đo'));
      await tester.tap(find.text('Lưu số đo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('DATABASE_UNAVAILABLE'), findsOneWidget);
      expect(tester.widget<TextFormField>(field).controller!.text, '8,5');
      await tester.tap(find.text('Lưu số đo'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(saved!['v0'], 8.5);
      expect(saved!.containsKey('v1'), false);
      expect(saved!.containsKey('v2'), false);
      expect(find.byType(TextFormField), findsNothing);
    },
  );

  testWidgets('remote height requires an explicit measurement position', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showMeasurementSheet(
                context,
                records: [],
                isPreview: false,
                onSave: (_) async {
                  calls++;
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), '69.5');
    await tester.ensureVisible(find.text('Lưu số đo'));
    await tester.tap(find.text('Lưu số đo'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Chọn tư thế đo chiều cao.'), findsOneWidget);
  });
}
