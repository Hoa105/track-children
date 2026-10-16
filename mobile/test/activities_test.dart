import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/activities/activities_screen.dart';
import 'package:track_children/models/activity.dart';
import 'package:track_children/services/demo_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DemoStore.resetInstanceForTesting();
    await DemoStore.instance.login('demo@trackchildren.vn', DemoStore.password);
  });

  test('progress and favorites persist and stay isolated', () async {
    final store = DemoStore.instance;
    final children = store.children;
    final first = children.first['id'] as String;
    final second = children.last['id'] as String;
    await store.setActivityDone(first, activityCatalog.first.id, true);
    await store.setActivityFavorite(activityCatalog.first.id, true);
    expect(store.completedActivities(second), isEmpty);
    DemoStore.resetInstanceForTesting();
    await DemoStore.instance.initialize();
    expect(
      DemoStore.instance.completedActivities(first),
      contains(activityCatalog.first.id),
    );
    expect(
      DemoStore.instance.favoriteActivities,
      contains(activityCatalog.first.id),
    );
    await DemoStore.instance.login('bo@trackchildren.vn', DemoStore.password);
    expect(DemoStore.instance.favoriteActivities, isEmpty);
    expect(
      () => DemoStore.instance.setActivityDone(
        first,
        activityCatalog.first.id,
        false,
      ),
      throwsStateError,
    );
  });

  for (final width in [320.0, 768.0]) {
    testWidgets('activity flow at $width with large text', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1000);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const ActivitiesScreen(childId: 'child_an'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Vận động thô'), 200);
      await tester.ensureVisible(find.text('Vận động thô'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vận động thô'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Bộ lọc'));
      await tester.pumpAndSettle();
      expect(find.text('Bộ lọc hoạt động'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Đóng bộ lọc'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Tập đứng vịn'), 150);
      await tester.ensureVisible(find.text('Tập đứng vịn'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tập đứng vịn'));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết hoạt động'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Đánh dấu đã thực hiện'));
      await tester.pumpAndSettle();
      expect(
        DemoStore.instance.completedActivities('child_an'),
        contains('g0-4'),
      );
      expect(find.text('Bỏ đánh dấu'), findsOneWidget);
    });
  }

  testWidgets('discovery switches suggestions and opens featured activity', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ActivitiesScreen(childId: 'child_an')),
    );
    await tester.pumpAndSettle();
    expect(find.text('HÔM NAY CHƠI GÌ?'), findsOneWidget);
    await tester.tap(find.byTooltip('Đổi gợi ý'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Cùng bé chơi'));
    await tester.tap(find.text('Cùng bé chơi'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết hoạt động'), findsOneWidget);
    await tester.tap(find.byTooltip('Yêu thích'));
    await tester.pumpAndSettle();
    expect(DemoStore.instance.favoriteActivities, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
