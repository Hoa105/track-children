import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/growth_repository.dart';
import 'package:track_children/features/growth/growth_weight_detail.dart';

class RetryReferenceRepository extends MockGrowthRepository {
  RetryReferenceRepository(this.reference);
  final GrowthWeightReference reference;
  int attempts = 0;
  @override
  Future<GrowthWeightReference?> weightReference() async {
    if (++attempts == 1) throw StateError('reference unavailable');
    return reference;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GrowthWeightReference preparedReference;
  setUp(() async {
    rootBundle.evict('assets/data/who/weight_for_age_curves.json');
    preparedReference = GrowthWeightReference.fromJson(
      jsonDecode(
        await rootBundle.loadString(
          'assets/data/who/weight_for_age_curves.json',
        ),
      ) as Map<String, dynamic>,
      GrowthReferenceSex.boys,
    );
  });
  test(
    'WHO curves cover both sexes and match all existing thresholds',
    () async {
      final raw = jsonDecode(
        await rootBundle.loadString(
          'assets/data/who/weight_for_age_curves.json',
        ),
      ) as Map<String, dynamic>;
      final old = jsonDecode(
        await rootBundle.loadString('assets/data/who_growth.json'),
      ) as Map<String, dynamic>;
      for (final sex in GrowthReferenceSex.values) {
        final ref = GrowthWeightReference.fromJson(raw, sex);
        expect(ref.rows.length, 61);
        expect(ref.sourceUrl, startsWith('https://cdn.who.int/'));
        expect(ref.sourceHash.length, 64);
        for (var month = 0; month <= 60; month++) {
          final row = ref.rows[month];
          expect(row.month, month);
          expect(row.weights.length, 5);
          for (var i = 1; i < 5; i++) {
            expect(row.weights[i], greaterThan(row.weights[i - 1]));
          }
          final previous =
              ((old['weight'] as Map)[sex.name] as List)[month] as List;
          expect([
            row.weights[1],
            row.weights[2],
            row.weights[3],
          ], previous.skip(1).toList());
        }
      }
      final boys = GrowthWeightReference.fromJson(raw, GrowthReferenceSex.boys);
      expect(boys.rows.first.weights, [2.1, 2.5, 3.3, 4.4, 5.0]);
      expect(boys.rows[12].weights[2], 9.6);
      raw['unit'] = 'cm';
      expect(
        () => GrowthWeightReference.fromJson(raw, GrowthReferenceSex.boys),
        throwsFormatException,
      );
    },
  );

  test('malformed reference tables are rejected instead of drawn', () async {
    final raw = jsonDecode(
      await rootBundle.loadString('assets/data/who/weight_for_age_curves.json'),
    ) as Map<String, dynamic>;
    final boys = (raw['tables'] as Map)['boys'] as List;
    (boys[12] as List)[1] = 999;
    expect(
      () => GrowthWeightReference.fromJson(raw, GrowthReferenceSex.boys),
      throwsFormatException,
    );
    boys.removeLast();
    expect(
      () => GrowthWeightReference.fromJson(raw, GrowthReferenceSex.boys),
      throwsFormatException,
    );
  });

  testWidgets(
    'missing reference keeps measurements and retry restores five curves',
    (tester) async {
      final repo = RetryReferenceRepository(preparedReference);
      await tester.pumpWidget(
        MaterialApp(home: GrowthWeightDetailScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      expect(find.text('8,5 kg'), findsOneWidget);
      expect(
        tester
            .widget<GrowthWeightMeasurementChart>(
              find.byType(GrowthWeightMeasurementChart),
            )
            .reference,
        isNull,
      );
      await tester.scrollUntilVisible(
        find.text('Chưa tải được đường WHO. Thử lại'),
        200,
      );
      await tester.tap(find.text('Chưa tải được đường WHO. Thử lại'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<GrowthWeightMeasurementChart>(
              find.byType(GrowthWeightMeasurementChart),
            )
            .reference!
            .rows
            .length,
        61,
      );
      expect(find.text('WHO cân nặng theo tuổi · bé trai'), findsOneWidget);
      expect(find.text('Phù hợp'), findsOneWidget);
      expect(find.text('Cân đối'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
