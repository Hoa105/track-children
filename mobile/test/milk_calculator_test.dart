import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:track_children/core/routing/app_router.dart';
import 'package:track_children/core/routing/app_routes.dart';
import 'package:track_children/main.dart';
import 'package:track_children/services/milk_calculator.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  test('first week uses per-feed stomach capacity', () {
    final day1 = estimateMilk(ageDays: 0, feedsPerDay: 10)!;
    expect((day1.minPerFeed, day1.maxPerFeed), (5, 7));
    expect((day1.minPerDay, day1.maxPerDay), (50, 70));
    expect(estimateMilk(ageDays: 6)!.maxPerFeed, 60);
  });

  test('under 6 months is weight-based and capped', () {
    expect(estimateMilk(ageDays: 60), isNull); // no weight
    final e = estimateMilk(ageDays: 60, weightKg: 5, feedsPerDay: 7)!;
    expect((e.minPerDay, e.maxPerDay), (700, 850));
    expect((e.minPerFeed, e.maxPerFeed), (100, 120));
    final heavy = estimateMilk(ageDays: 150, weightKg: 8)!;
    expect(heavy.maxPerDay, maxDailyMl);
    expect(heavy.capped, isTrue);
  });

  test('from 6 months uses fixed ranges; out of range beyond 5 years', () {
    final e = estimateMilk(ageDays: 200)!;
    expect((e.minPerDay, e.maxPerDay), (600, 800));
    expect(estimateMilk(ageDays: 18 * 30 + 12)!.maxPerDay, 500);
    expect(estimateMilk(ageDays: 61 * 30), isNull);
  });

  testWidgets('screen renders for the selected child', (tester) async {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
    tester.view.physicalSize = const Size(1080, 7000);
    tester.view.devicePixelRatio = 2.75;
    await tester.pumpWidget(const BeLonKhonApp());
    appRouter.go(AppRoutes.milkCalculator);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Tính lượng sữa tham khảo'), findsOneWidget);
    expect(find.text('Lượng sữa tham khảo mỗi ngày'), findsOneWidget);
    expect(find.text('Bảng tham khảo theo tháng tuổi'), findsOneWidget);
  });
}
