import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_head_detail.dart';
import 'package:track_children/features/growth/growth_repository.dart';
import 'package:track_children/features/growth/head_velocity_data.dart';
import 'package:track_children/features/growth/head_velocity_view.dart';

import 'growth_head_velocity_test.dart' show HeadVelocityRepo;

class _VisualRepo extends HeadVelocityRepo {
  @override
  Future<GrowthWeightReference?> headAgeReference() async {
    final raw = jsonDecode(
      File('assets/data/who/head_for_age_curves.json').readAsStringSync(),
    );
    return GrowthWeightReference(
      sex: GrowthReferenceSex.boys,
      rows: [
        for (final r in raw['tables']['boys'])
          GrowthWeightReferenceRow((r[0] as num).toInt(), [
            for (final v in (r as List).skip(1)) (v as num).toDouble(),
          ]),
      ],
      sourceUrl: raw['sources']['boys']['url'],
      sourceHash: raw['sources']['boys']['sha256'],
    );
  }
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final entry in {
      'Nunito': 'assets/fonts/nunito/Nunito-Variable.ttf',
      'DancingScript': 'assets/fonts/dancing_script/DancingScript-Variable.ttf',
    }.entries) {
      await (FontLoader(entry.key)..addFont(
            Future.value(
              ByteData.sublistView(File(entry.value).readAsBytesSync()),
            ),
          ))
          .load();
    }
  });
  final raw = jsonDecode(
    File('assets/data/who/head_velocity_periods.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  test(
    'All eight original WHO tables preserve age domains and published ties',
    () {
      for (final sex in ['boys', 'girls']) {
        for (final period in [2, 3, 4, 6]) {
          final ref = HeadVelocityReference.fromJson(raw, sex, period);
          final maxAge = period <= 3 ? 12 : 24;
          expect(ref.rows.length, maxAge + 1 - period);
          expect(ref.rows.first.start, 0);
          expect(ref.rows.last.end, maxAge);
        }
      }
      final ref = HeadVelocityReference.fromJson(raw, 'boys', 2);
      expect(ref.rows.first.sd, [2.5, 3.2, 3.9, 4.7, 5.4, 6.2, 7.0]);
    },
  );

  test('Head intervals accept method-free readings, WHO tolerance and recording-only ages', () {
    final birth = DateTime(2024, 1, 1);
    GrowthMeasurementDraft reading(int days, double cm) =>
        GrowthMeasurementDraft(
          measuredAt: birth.add(Duration(days: days)),
          value: cm,
        );
    final ref = HeadVelocityReference.fromJson(raw, 'boys', 2);
    final intervals = headVelocityIntervals(
      [reading(1, 34), reading(63, 39)],
      birth,
      2,
      ref,
    );
    expect(intervals.single.gain, 5);
    expect(intervals.single.row, ref.rows.first);
    expect(intervals.single.z, isNull);
    expect(
      headVelocityIntervals([reading(1, 34), reading(65, 39)], birth, 2, ref),
      isEmpty,
    );
    final later = headVelocityIntervals(
      [
        GrowthMeasurementDraft(value: 46, measuredAt: DateTime(2025, 1, 1)),
        GrowthMeasurementDraft(value: 47, measuredAt: DateTime(2025, 3, 1)),
      ],
      birth,
      2,
      ref,
    );
    expect(later.single.row, isNull);
  });

  for (final velocity in [false, true]) {
    testWidgets('Head ${velocity ? 'velocity' : 'overview'} visual layout', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: GrowthHeadDetailScreen(repository: _VisualRepo()),
        ),
      );
      await tester.pumpAndSettle();
      if (velocity) {
        await tester.tap(find.text('Tốc độ'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/head-${velocity ? 'velocity' : 'overview'}.png',
        ),
      );
      if (velocity) {
        await tester.tap(find.byKey(const ValueKey('head-period-4')));
        await tester.pumpAndSettle();
        expect(find.text('0–24 tháng (WHO)'), findsOneWidget);
        await tester.tap(find.byTooltip('Mở rộng biểu đồ'));
        await tester.pumpAndSettle();
        final expanded = tester
            .widgetList<HeadVelocityView>(find.byType(HeadVelocityView))
            .last;
        expect(expanded.expanded, isTrue);
        expect(expanded.initialPeriod, 4);
        expect(
          find.byKey(const Key('head-velocity-expanded-legend')),
          findsOneWidget,
        );
        expect(find.text('Điểm'), findsNothing);
        expect(find.textContaining('Bán kính'), findsNothing);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(Scaffold).last,
          matchesGoldenFile('goldens/head-velocity-expanded.png'),
        );
        await tester.tap(find.byTooltip('Thông tin biểu đồ').last);
        await tester.pumpAndSettle();
        expect(find.textContaining('Điểm tím'), findsOneWidget);
      }
    });
  }
}
