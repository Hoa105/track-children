import 'package:flutter/material.dart';

import '../../services/demo_store.dart';
import 'growth_repository.dart';
import 'growth_stature_velocity_reference.dart';
import 'growth_weight_velocity_data.dart';
import 'remote_growth_repository.dart';

/// Adapts server data to the original widgets without changing their styling.
class ApiGrowthRepository extends GrowthRepository {
  ApiGrowthRepository({RemoteGrowthRepository? remote})
    : remote =
          remote ??
          RemoteGrowthRepository(
            DemoStore.instance.child?['id'] as String? ?? '',
          ),
      _birth = DateTime.tryParse(
        DemoStore.instance.child?['date_of_birth']?.toString() ?? '',
      );

  final RemoteGrowthRepository remote;
  DateTime? _birth;
  GrowthReferenceSex _sex = GrowthReferenceSex.boys;
  final _details = <String, Future<GrowthDocument>>{};
  final _snapshots = <String, GrowthDocument>{};
  final _velocity = <Map<String, dynamic>>[];
  @override
  DateTime? get dateOfBirth => _birth;
  void _profile(GrowthDocument doc) {
    _birth = DateTime.tryParse(doc.child['dateOfBirth']?.toString() ?? '');
    _sex = doc.child['sex'] == 'female'
        ? GrowthReferenceSex.girls
        : GrowthReferenceSex.boys;
  }

  Future<GrowthDocument> _detail(String metric) =>
      _details.putIfAbsent(metric, () async {
        final doc = await remote.detail(metric);
        _profile(doc);
        _snapshots[metric] = doc;
        return doc;
      });
  String _key(GrowthMetric metric) => switch (metric) {
    GrowthMetric.weight => 'weight',
    GrowthMetric.lengthHeight => 'height',
    GrowthMetric.headCircumference => 'head_circumference',
  };

  Future<List<Map<String, dynamic>>> recordsForSheet() async {
    final days = <String, Map<String, dynamic>>{};
    for (var i = 0; i < GrowthMetric.values.length; i++) {
      for (final row in await measurements(GrowthMetric.values[i])) {
        final record = days.putIfAbsent(
          _day(row.measuredAt),
          () => {'date': row.measuredAt.toIso8601String()},
        );
        record['v$i'] = row.value;
        if (row.method != null) {
          record['measurePosition'] =
              row.method == GrowthMeasurementMethod.recumbent
              ? 'lying'
              : 'standing';
        }
      }
    }
    for (final row in await bmiMeasurements()) {
      days[_day(row.measuredAt)]?['bmi'] = row.value;
    }
    return days.values.toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
  }

  Future<void> saveRecord(Map<String, dynamic> record) async {
    await remote.save(_day(DateTime.parse(record['date'] as String)), {
      if (record['v0'] != null) 'weightKg': record['v0'],
      if (record['v1'] != null)
        'height': {
          'value': record['v1'],
          'measurePosition': record['measurePosition'],
        },
      if (record['v2'] != null) 'headCircumferenceCm': record['v2'],
    });
    _details.clear();
    _snapshots.clear();
    _velocity.clear();
  }

  String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<List<GrowthMetricViewData>> loadOverview() async {
    _details.clear();
    _snapshots.clear();
    _velocity.clear();
    final doc = await remote.overview();
    _profile(doc);
    const titles = ['Cân nặng', 'Chiều dài', 'Vòng đầu', 'BMI'];
    const keys = ['weight', 'height', 'head_circumference', 'bmi'];
    const assets = ['weight', 'height', 'head', 'bmi'];
    const colors = [
      Color(0xFFE58A42),
      Color(0xFF4B92C6),
      Color(0xFF9B7AC2),
      Color(0xFF277B58),
    ];
    return [
      for (var i = 0; i < keys.length; i++)
        (() {
          final card = doc
              .list('cards')
              .firstWhere((c) => c['metric'] == keys[i]);
          final latest = card['latest'] as Map?;
          final value = latest?['value'] as num?;
          return GrowthMetricViewData(
            titles[i],
            value == null ? '__' : formatGrowthValue(value.toDouble()),
            i == 0
                ? 'kg'
                : i == 3
                ? 'kg/m²'
                : 'cm',
            assets[i],
            colors[i],
            [
              for (final p in (card['sparkline'] as List? ?? []))
                (p['value'] as num).toDouble(),
            ],
          );
        })(),
    ];
  }

  @override
  Future<List<GrowthMeasurementDraft>> measurements(GrowthMetric metric) async {
    final key = _key(metric);
    final doc = await _detail(key);
    return [
      for (final m in doc.list('measurements').where((m) => m['metric'] == key))
        GrowthMeasurementDraft(
          value: (m['value'] as num).toDouble(),
          measuredAt: DateTime.parse(m['measuredOn'] as String),
          method: m['measurePosition'] == 'lying'
              ? GrowthMeasurementMethod.recumbent
              : m['measurePosition'] == 'standing'
              ? GrowthMeasurementMethod.standing
              : null,
        ),
    ];
  }

  @override
  Future<List<GrowthMeasurementDraft>> weightMeasurements() =>
      measurements(GrowthMetric.weight);
  @override
  Future<List<GrowthMeasurementDraft>> bmiMeasurements() async {
    final doc = await _detail('bmi');
    return [
      for (final s in doc.list('samples'))
        GrowthMeasurementDraft(
          value: (s['value'] as num).toDouble(),
          measuredAt: DateTime.parse(s['measuredOn'] as String),
          method: (s['normalization'] as Map?)?['basis'] == 'standing_height'
              ? GrowthMeasurementMethod.standing
              : GrowthMeasurementMethod.recumbent,
        ),
    ];
  }

  @override
  Future<GrowthMeasurementDraft?> weightBefore(DateTime date) =>
      measurementBefore(GrowthMetric.weight, date);
  @override
  Future<GrowthMeasurementDraft?> measurementBefore(
    GrowthMetric metric,
    DateTime date,
  ) async {
    final rows =
        (await measurements(metric))
            .where((m) => m.measuredAt.isBefore(DateUtils.dateOnly(date)))
            .toList()
          ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    return rows.lastOrNull;
  }

  @override
  Future<void> saveWeight(GrowthMeasurementDraft draft) =>
      saveMeasurement(GrowthMetric.weight, draft);
  @override
  Future<void> saveMeasurement(
    GrowthMetric metric,
    GrowthMeasurementDraft draft,
  ) async {
    await remote.save(_day(draft.measuredAt), switch (metric) {
      GrowthMetric.weight => {'weightKg': draft.value},
      GrowthMetric.headCircumference => {'headCircumferenceCm': draft.value},
      GrowthMetric.lengthHeight => {
        'height': {
          'value': draft.value,
          'measurePosition': draft.method == GrowthMeasurementMethod.recumbent
              ? 'lying'
              : 'standing',
        },
      },
    });
    _details.clear();
    _snapshots.clear();
    _velocity.clear();
  }

  Map<String, dynamic>? assessment(
    String metric,
    DateTime date,
    String indicator,
  ) {
    for (final sample
        in _snapshots[metric]?.list('samples') ?? <Map<String, dynamic>>[]) {
      if (sample['measuredOn'] != _day(date)) continue;
      for (final a in (sample['assessments'] as List)) {
        if (a['indicator'] == indicator &&
            a['status'] == 'READY' &&
            a['zScore'] is num) {
          return Map<String, dynamic>.from(a as Map);
        }
      }
    }
    return null;
  }

  @override
  double? indicatorZScore(String metric, DateTime date, String indicator) =>
      (assessment(metric, date, indicator)?['zScore'] as num?)?.toDouble();

  static const _classificationLabels = {
    'WITHIN_RANGE': 'Trong khoảng tham chiếu',
    'SEVERE_UNDERWEIGHT': 'Nhẹ cân mức độ nặng',
    'UNDERWEIGHT': 'Nhẹ cân',
    'HIGH_WFA': 'Cân nặng theo tuổi cao',
    'SEVERE_STUNTING': 'Thấp còi nặng',
    'STUNTING': 'Thấp còi',
    'VERY_TALL': 'Cao nổi bật so với tuổi',
    'SEVERE_WASTING': 'Gầy còm nặng',
    'WASTING': 'Gầy còm',
    'RISK_OVERWEIGHT': 'Nguy cơ thừa cân',
    'OVERWEIGHT': 'Thừa cân',
    'OBESITY': 'Béo phì theo chỉ số nhân trắc',
    'SEVERE_THINNESS': 'BMI rất thấp theo tuổi',
    'THINNESS': 'BMI thấp theo tuổi',
    'VERY_LOW_HC': 'Vòng đầu rất nhỏ so với tuổi',
    'LOW_HC': 'Vòng đầu nhỏ so với tuổi',
    'HIGH_HC': 'Vòng đầu lớn so với tuổi',
    'VERY_HIGH_HC': 'Vòng đầu rất lớn so với tuổi',
  };

  GrowthIndexAssessment? _index(Map<String, dynamic>? a) {
    if (a == null) return null;
    final content = a['content'] as Map?;
    final comment = content?['comment'] as Map?;
    return GrowthIndexAssessment(
      classification:
          _classificationLabels[a['classificationCode']] ??
          'C\u00f3 k\u1ebft qu\u1ea3 \u0111\u00e1nh gi\u00e1',
      zScore: (a['zScore'] as num).toDouble(),
      explanation: comment?['text']?.toString() ?? '',
    );
  }

  @override
  GrowthWeightAssessmentData? weightAssessmentFor(
    GrowthMeasurementDraft weight,
    GrowthMeasurementDraft? stature,
  ) => GrowthWeightAssessmentData(
    wfa: _index(assessment('weight', weight.measuredAt, 'wfa')),
    wflh: _index(
      assessment('weight', weight.measuredAt, 'wfl') ??
          assessment('weight', weight.measuredAt, 'wfh'),
    ),
  );

  Future<Map<String, dynamic>?> _reference(
    String metric,
    String indicator,
  ) async {
    final doc = await _detail(metric);
    for (final chart in doc.list('charts')) {
      if (chart['indicator'] == indicator) {
        return Map<String, dynamic>.from(chart['reference'] as Map);
      }
    }
    return null;
  }

  Future<GrowthWeightReference?> _ageReference(
    String metric,
    String indicator, [
    bool? length,
  ]) async {
    final ref = await _reference(metric, indicator);
    if (ref == null || ref['importStatus'] != 'VERIFIED' || _birth == null) {
      return null;
    }
    final rows = <GrowthWeightReferenceRow>[];
    for (final segment in ref['segments'] as List) {
      if (length != null &&
          segment['basis'] !=
              (length ? 'recumbent_length' : 'standing_height')) {
        continue;
      }
      final curves = segment['curves'] as List;
      final points = {
        for (final c in curves)
          (c['sd'] as num).toInt(): {
            for (final p in c['points'] as List)
              (p['x'] as num).toInt(): (p['y'] as num).toDouble(),
          },
      };
      for (var month = 0; month <= 60; month++) {
        final first = DateTime(_birth!.year, _birth!.month + month);
        final day = DateTime(
          first.year,
          first.month,
          _birth!.day.clamp(
            1,
            DateUtils.getDaysInMonth(first.year, first.month),
          ),
        );
        final days = DateTime.utc(day.year, day.month, day.day)
            .difference(DateTime.utc(_birth!.year, _birth!.month, _birth!.day))
            .inDays;
        if ([
          -3,
          -2,
          0,
          2,
          3,
        ].every((sd) => points[sd]?.containsKey(days) == true)) {
          rows.add(
            GrowthWeightReferenceRow(month, [
              for (final sd in [-3, -2, 0, 2, 3]) points[sd]![days]!,
            ]),
          );
        }
      }
    }
    if (rows.isEmpty) return null;
    final source = (ref['sources'] as List).first as Map;
    return GrowthWeightReference(
      sex: _sex,
      rows: rows,
      sourceUrl: source['sourceUrl'] as String,
      sourceHash: source['sha256'] as String,
    );
  }

  @override
  Future<GrowthWeightReference?> weightReference() =>
      _ageReference('weight', 'wfa');
  @override
  Future<GrowthWeightReference?> statureAgeReference(bool length) =>
      _ageReference('height', 'lhfa', length);
  @override
  Future<GrowthWeightReference?> headAgeReference() =>
      _ageReference('head_circumference', 'hcfa');
  @override
  Future<GrowthWeightReference?> bmiAgeReference(bool length) =>
      _ageReference('bmi', 'bmifa', length);
  @override
  Future<GrowthStatureReference?> statureReference(bool length) async {
    final doc = await remote.detail(
      'weight',
      query: {
        'weightForSizeIndicator': length ? 'wfl' : 'wfh',
        'statureView': 'all',
      },
    );
    final ref = Map<String, dynamic>.from(
      doc
              .list('charts')
              .firstWhere(
                (c) => c['indicator'] == (length ? 'wfl' : 'wfh'),
              )['reference']
          as Map,
    );
    if (ref['importStatus'] != 'VERIFIED' ||
        (ref['segments'] as List).isEmpty) {
      return null;
    }
    final curves = (ref['segments'] as List).first['curves'] as List;
    final points = {
      for (final c in curves)
        (c['sd'] as num).toInt(): {
          for (final p in c['points'] as List)
            (p['x'] as num).toDouble(): (p['y'] as num).toDouble(),
        },
    };
    final x =
        points[0]!.keys.where((x) => (x * 2).roundToDouble() == x * 2).toList()
          ..sort();
    return GrowthStatureReference([
      for (final size in x)
        [
          size,
          for (final sd in [-3, -2, 0, 2, 3]) points[sd]![size]!,
        ],
    ], (ref['sources'] as List).first['sourceUrl'] as String);
  }

  // Original bundled WHO display bands; no synthetic observations/assessments.
  MockGrowthRepository get _bands => MockGrowthRepository(referenceSex: _sex);
  @override
  Future<GrowthStatureVelocityReference?> statureVelocityReference() async {
    await _detail('height');
    return _bands.statureVelocityReference();
  }

  @override
  Future<GrowthStatureVelocityReference?> headVelocityReference() async {
    await _detail('head_circumference');
    return _bands.headVelocityReference();
  }

  @override
  Future<GrowthWeightVelocityReference?> weightVelocityReference() async {
    final doc = await remote.velocity('weight', mode: 'who', period: 1);
    _velocity
      ..clear()
      ..addAll(doc.list('whoIntervals'));
    return _bands.weightVelocityReference();
  }

  @override
  double? weightVelocityDisplayZScore(GrowthWeightVelocityPoint point) {
    for (final interval in _velocity) {
      if ((interval['from'] as Map)['measuredOn'] == _day(point.from) &&
          (interval['to'] as Map)['measuredOn'] == _day(point.to) &&
          interval['zScoreStatus'] == 'READY') {
        return (interval['zScore'] as num?)?.toDouble();
      }
    }
    return null;
  }
}
