import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/models/tooth.dart';
import 'package:track_children/services/demo_store.dart';

void main() {
  test(
    'child lookup keeps a detached snapshot and teething readers stay isolated',
    () async {
      SharedPreferences.setMockInitialValues({});
      DemoStore.resetInstanceForTesting();
      final store = DemoStore.instance;
      await store.login('demo@trackchildren.vn', DemoStore.password);
      final id = await store.saveChild(null, {
        'full_name': 'Lookup test',
        'date_of_birth': '2025-01-01',
        'gender': 'female',
      });
      final tooth = PrimaryTooth.all.first.id;
      await store.saveTooth(id, tooth, DateTime(2026, 1, 1), note: 'Recorded');
      final snapshot = store.childById(id)!;
      (snapshot['teeth'] as List).clear();
      snapshot['server'] = true;
      snapshot['teethingAccess'] = 'none';
      expect(store.teeth(id), {tooth: DateTime(2026, 1, 1)});
      expect(store.toothNote(id, tooth), 'Recorded');
      expect(store.canEditTeething(id), isTrue);
      final records = store.teeth(id)..clear();
      expect(records, isEmpty);
      expect(store.teeth(id), hasLength(1));
      expect(store.childById('missing-child'), isNull);
      expect(store.teeth('missing-child'), isEmpty);
      expect(store.canViewTeething('missing-child'), isFalse);
      await store.logout();
      expect(store.childById(id), isNull);
      expect(store.teeth(id), isEmpty);
      expect(store.canViewTeething(id), isFalse);
    },
  );
}
