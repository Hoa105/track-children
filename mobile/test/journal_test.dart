import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/journal/journal_screen.dart';
import 'package:track_children/services/demo_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
    await DemoStore.instance.login('demo@trackchildren.vn', DemoStore.password);
  });
  test('journal persists, migrates legacy and stays isolated', () async {
    final store = DemoStore.instance;
    final legacy = store.journalEntries('child_an').single;
    await store.saveJournalEntry('child_an', {
      'id': 'new',
      'date': '2026-10-16T00:00:00',
      'note': 'Bé tập đi',
      'mood': 'Vui vẻ',
      'domains': ['Vận động thô'],
    });
    expect(store.journalEntries('child_an'), hasLength(2));
    expect(store.journalEntries('child_linh'), hasLength(1));
    DemoStore.resetInstanceForTesting();
    await DemoStore.instance.initialize();
    expect(
      DemoStore.instance
          .journalEntries('child_an')
          .any((e) => e['id'] == 'new'),
      isTrue,
    );
    await DemoStore.instance.deleteJournalEntry('child_an', 'new');
    await DemoStore.instance.deleteJournalEntry(
      'child_an',
      legacy['id'] as String,
    );
    expect(DemoStore.instance.journalEntries('child_an'), isEmpty);
    expect(DemoStore.instance.childById('child_an')!['journal'], isNull);
    await DemoStore.instance.login('bo@trackchildren.vn', DemoStore.password);
    expect(
      () => DemoStore.instance.saveJournalEntry('child_an', {}),
      throwsStateError,
    );
  });
  testWidgets('create, view and edit with large text on narrow screen', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: const JournalScreen(childId: 'child_an'),
      ),
    );
    await tester.tap(find.text('Viết nhật ký'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Bé vỗ tay');
    await tester.scrollUntilVisible(
      find.text('Lưu nhật ký'),
      250,
      scrollable: find.descendant(of: find.byType(Form), matching: find.byType(Scrollable)).first,
    );
    await tester.ensureVisible(find.text('Lưu nhật ký'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu nhật ký'));
    await tester.pumpAndSettle();
    expect(
      DemoStore.instance
          .journalEntries('child_an')
          .any((e) => e['note'] == 'Bé vỗ tay'),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
