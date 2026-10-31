import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/growth/api_growth_repository.dart';
import 'package:track_children/features/growth/remote_growth_repository.dart';

void main() {
  test(
    'share velocity request and invalidate after a saved measurement',
    () async {
      var gets = 0;
      final document = {
        'meta': {'schemaVersion': '1'},
        'child': {'id': 'child'},
        'actualIntervals': <dynamic>[],
        'whoIntervals': <dynamic>[],
        'referenceIntervals': <dynamic>[],
      };
      final repo = ApiGrowthRepository(
        remote: RemoteGrowthRepository(
          'child',
          transport: (method, path, {body}) async {
            if (method == 'PUT')
              return {'measurementSaved': true, 'day': document};
            gets++;
            await Future<void>.delayed(const Duration(milliseconds: 1));
            return document;
          },
        ),
      );
      await Future.wait([
        repo.weightVelocityIntervals(),
        repo.weightVelocityPeriodReference(1),
      ]);
      expect(gets, 1);
      await repo.weightVelocityIntervals();
      expect(gets, 1);
      await repo.weightVelocityPeriodReference(2);
      expect(gets, 2);
      await repo.saveRecord({'date': '2026-01-01', 'v0': 8.5});
      await repo.weightVelocityIntervals();
      expect(gets, 3);
    },
  );
  test('a failed cached request can be retried', () async {
    var calls = 0;
    final repo = ApiGrowthRepository(
      remote: RemoteGrowthRepository(
        'child',
        transport: (_, __, {body}) async {
          if (++calls == 1) throw StateError('offline');
          return {
            'meta': {'schemaVersion': '1'},
            'child': {'id': 'child'},
          };
        },
      ),
    );
    await expectLater(repo.weightVelocityIntervals(), throwsStateError);
    expect(await repo.weightVelocityIntervals(), isEmpty);
    expect(calls, 2);
  });
  for (final period in [1, 2, 3, 4, 6]) {
    test(
      'reference period $period uses server bounds without child pairs',
      () async {
        final repo = ApiGrowthRepository(
          remote: RemoteGrowthRepository(
            'child',
            transport: (_, path, {body}) async {
              expect(path, contains('intervalMonths=$period'));
              return {
                'meta': {'schemaVersion': '1'},
                'child': {'id': 'child', 'dateOfBirth': '2024-01-31'},
                'referenceIntervals': [
                  {
                    'start': 0,
                    'end': period,
                    'startUnit': 'mo',
                    'endUnit': 'mo',
                    'unit': 'g',
                    'intervalMonths': period,
                    'sdValues': [
                      {'sd': -2, 'value': -50},
                      {'sd': 0, 'value': 500},
                      {'sd': 2, 'value': 1000},
                    ],
                  },
                ],
              };
            },
          ),
        );
        final reference = (await repo.weightVelocityPeriodReference(period))!;
        final bands = reference.bands(0, 24, null);
        expect(bands.length, 1);
        expect(bands.single.low, -50);
        expect(bands.single.median, 500);
        expect(bands.single.high, 1000);
        expect(bands.single.start, 0);
      },
    );
  }
  test(
    'API intervals preserve endpoints and separate actual-only from WHO',
    () async {
      Map<String, dynamic> interval(
        String id,
        String status,
        int start,
        int end,
      ) => {
        'intervalId': id,
        'calculationStatus': 'READY',
        'deltaUnit': 'g',
        'deltaValue': 321.0,
        'from': {'measuredOn': '2025-01-01', 'ageDays': start, 'rawValue': 8.0},
        'to': {'measuredOn': '2025-02-01', 'ageDays': end, 'rawValue': 8.321},
        'elapsedDays': 31,
        'content': {
          'comment': {'status':'READY','text':'Explanation for this interval'},
          'advice': [
            {'status':'READY','text':'Approved interval advice'},
            {'status':'MAPPING_NOT_APPROVED','text':'Draft advice'},
          ],
        },
        'referenceStatus': status,
        'referenceReason': status == 'REFERENCE_MATCHED'
            ? null
            : 'OUT_OF_SCOPE_AGE',
        'zScoreStatus': 'READY',
        'zScore': .25,
        'matchedReference': {
          'tableIntervalMonths': 1,
          'intervalLabel': '10 mo - 11 mo',
          'sdValues': [{'sd':-2,'value':100.0},{'sd':0,'value':300.0},{'sd':2,'value':600.0}],
        },
      };
      final repo = ApiGrowthRepository(
        remote: RemoteGrowthRepository(
          'child',
          transport: (_, __, {body}) async => {
            'meta': {'schemaVersion': '1'},
            'child': {'id': 'child'},
            'actualIntervals': [
              interval('a', 'REFERENCE_MATCHED', 304, 335),
              interval('b', 'REFERENCE_NOT_APPLICABLE', 740, 771),
            ],
            'whoIntervals': [interval('a', 'REFERENCE_MATCHED', 304, 335)],
          },
        ),
      );
      final points = (await repo.weightVelocityIntervals())!;
      expect(points.length, 2);
      expect(points.first.id, 'a');
      expect(points.first.hasWhoReference, isTrue);
      expect(points.first.zScore, .25);
      expect(points.first.grams, 321);
      expect(points.first.fromKg, 8);
      expect(points.first.referenceValues, {-2:100.0,0:300.0,2:600.0});
      expect(points.first.explanation,'Explanation for this interval');
      expect(points.first.advice,['Approved interval advice']);
      expect(points.last.hasWhoReference, isFalse);
      expect(points.last.zScore, isNull);
      expect(points.last.intervalMonths, 0);
      expect(points.last.intervalLabel, contains('Chỉ ghi nhận'));
    },
  );
  test('API errors propagate instead of using local pairs', () async {
    final repo = ApiGrowthRepository(
      remote: RemoteGrowthRepository(
        'child',
        transport: (_, __, {body}) async => throw StateError('offline'),
      ),
    );
    await expectLater(repo.weightVelocityIntervals(), throwsStateError);
  });
}
