import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_repository.dart';
import 'package:track_children/features/growth/growth_weight_velocity.dart';
import 'package:track_children/features/growth/growth_weight_velocity_data.dart';

class _CachedPreviewRepository extends MockGrowthRepository {
  final _cache = <int, GrowthWeightVelocityReference?>{};
  @override
  Future<GrowthWeightVelocityReference?> weightVelocityPeriodReference(
    int period,
  ) async {
    if (_cache.containsKey(period)) return _cache[period];
    return _cache[period] = await super.weightVelocityPeriodReference(period);
  }
}

void main() {
  testWidgets('switch to six-month reference with no paired readings', (
    tester,
  ) async {
    final repo = _CachedPreviewRepository();
    // Resolve the bundled references outside the fake async widget clock.
    await tester.runAsync(() async {
      for (final period in [1, 2, 3, 4, 6]) {
        final reference = await repo.weightVelocityPeriodReference(period);
        expect(reference!.bands(0, 24, null), isNotEmpty);
      }
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrowthWeightVelocityTab(repository: repo, readings: const []),
        ),
      ),
    );
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    final sixMonthTab = find.byKey(const ValueKey('velocity-period-tab-6'));
    await tester.ensureVisible(sixMonthTab);
    await tester.tap(sixMonthTab);
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Theo\ntháng'), findsOneWidget);
    expect(find.text('WHO: −2 đến +2 SD'), findsNothing);
    expect(find.text('Trung vị WHO (0)'), findsNothing);
    await tester.ensureVisible(find.byTooltip('Phóng to biểu đồ'));
    await tester.tap(find.byTooltip('Phóng to biểu đồ'));
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 3; i++) {
      await tester.pump();
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tốc độ tăng cân · kỳ 6 tháng'), findsOneWidget);
    expect(find.text('Trung vị WHO (0)'), findsNothing);
    expect(find.text('Mốc −3 / +3'), findsNothing);
    expect(find.text('Chưa đủ dữ liệu trong khoảng đang xem.'), findsOneWidget);
    expect(find.byTooltip('Phóng to biểu đồ'), findsNothing);
    expect(find.byKey(const ValueKey('velocity-period-tab-6')), findsNothing);
    expect(find.byKey(const ValueKey('velocity-period-tab-1')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
