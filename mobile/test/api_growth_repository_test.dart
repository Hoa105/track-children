import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/api_growth_repository.dart';
import 'package:track_children/features/growth/growth_overview.dart';
import 'package:track_children/features/growth/remote_growth_repository.dart';

void main() {
  test(
    'original repository saves through API and propagates network errors',
    () async {
      final calls = <Map<String, dynamic>>[];
      final remote = RemoteGrowthRepository(
        'child',
        transport: (method, path, {body}) async {
          calls.add({'method': method, 'body': body});
          if (method == 'PUT') {
            return {
              'measurementSaved': true,
              'day': {
                'meta': {'schemaVersion': '1'},
                'child': {'id': 'child'},
              },
            };
          }
          throw StateError('offline');
        },
      );
      final repo = ApiGrowthRepository(remote: remote);
      await repo.saveMeasurement(
        GrowthMetric.lengthHeight,
        GrowthMeasurementDraft(
          value: 75,
          measuredAt: DateTime(2026, 1, 1),
          method: GrowthMeasurementMethod.recumbent,
        ),
      );
      expect(calls.single['body'], {
        'height': {'value': 75.0, 'measurePosition': 'lying'},
      });
      await expectLater(repo.loadOverview(), throwsStateError);
    },
  );

  testWidgets(
    'original overview uses server values with original tiles and palette',
    (tester) async {
      final remote = RemoteGrowthRepository(
        'child',
        transport: (_, _, {body}) async => {
          'meta': {'schemaVersion': '1'},
          'child': {
            'id': 'child',
            'dateOfBirth': '2025-01-01',
            'sex': 'female',
          },
          'cards': [
            for (final metric in [
              'weight',
              'height',
              'head_circumference',
              'bmi',
            ])
              {
                'metric': metric,
                'latest': {'value': 9.5},
                'sparkline': [
                  {'value': 9.5},
                ],
              },
          ],
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: GrowthOverview(repository: ApiGrowthRepository(remote: remote)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GrowthMetricTile), findsNWidgets(4));
      final tiles = tester
          .widgetList<GrowthMetricTile>(find.byType(GrowthMetricTile))
          .toList();
      expect(tiles.map((t) => t.data.color), [
        const Color(0xFFE58A42),
        const Color(0xFF4B92C6),
        const Color(0xFF9B7AC2),
        const Color(0xFF277B58),
      ]);
      expect(tiles.map((t) => t.data.value), everyElement('9,5'));
      expect(tester.takeException(), isNull);
    },
  );
}
