import 'growth_classification_labels.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final _velocityDocuments = <int, Future<GrowthDocument>>{};
  Future<GrowthDocument> _velocityDocument(int period) => _velocityDocuments
      .putIfAbsent(period, () => _loadVelocityDocument(period));
  Future<GrowthDocument> _loadVelocityDocument(int period) async {
    try {
      return await remote.velocity('weight', mode: 'who', period: period);
    } catch (_) {
      _velocityDocuments.remove(period);
      rethrow;
    }
  }

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
    _velocityDocuments.clear();
  }

  String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<List<GrowthMetricViewData>> loadOverview() async {
    _details.clear();
    _snapshots.clear();
    _velocity.clear();
    _velocityDocuments.clear();
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
    _velocityDocuments.clear();
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

  GrowthIndexAssessment? _index(Map<String, dynamic>? a) {
    if (a == null) return null;
    final content = a['content'] as Map?;
    final comment = content?['comment'] as Map?;
    final overview = content?['overview'] as Map?;
    final explanationText = comment != null && comment['status'] == 'READY'
        ? (comment['text']?.toString() ?? '')
        : 'Nội dung giải thích hiện chưa sẵn có.';
    final overviewText = overview != null && overview['status'] == 'READY'
        ? overview['text']?.toString()
        : null;
    return GrowthIndexAssessment(
      classification:
          growthClassificationLabel(
            a['indicator']?.toString(),
            a['classificationCode']?.toString(),
          ) ??
          'C\u00f3 k\u1ebft qu\u1ea3 \u0111\u00e1nh gi\u00e1',
      zScore: (a['zScore'] as num).toDouble(),
      explanation: explanationText,
      overview: overviewText,
      advice: [
        for (final item in (content?['advice'] as List? ?? []))
          if (item is Map &&
              item['status'] == 'READY' &&
              item['text'] is String)
            item['text'] as String,
      ],
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
      if (indicator == 'wfa' || indicator == 'lhfa') {
        final days = points[0]!.keys.toList()..sort();
        for (final day in days) {
          if ([
            -3,
            -2,
            0,
            2,
            3,
          ].every((sd) => points[sd]?.containsKey(day) == true)) {
            rows.add(
              GrowthWeightReferenceRow((day / 30.4375).floor(), [
                for (final sd in [-3, -2, 0, 2, 3]) points[sd]![day]!,
              ], ageDays: day.toDouble()),
            );
          }
        }
        continue;
      }
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
  Future<GrowthWeightReference?> weightReference() async {
    final reference = await _ageReference('weight', 'wfa');
    if (reference == null)
      return null; // Keep missing/unverified references explicit.
    final days = reference.rows.map((r) => r.ageDays).toSet();
    if (days.length == 1827 &&
        List.generate(1827, (i) => i.toDouble()).every(days.contains)) {
      return reference;
    }
    // Older/cached API snapshots may contain only the child's elapsed ages.
    // Use the complete official bundled display table, never extrapolate a curve.
    return GrowthWeightReference.fromJson(
      jsonDecode(
        await rootBundle.loadString(
          'assets/data/who/weight_for_age_curves.json',
        ),
      ) as Map<String, dynamic>,
      _sex,
    );
  }

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
  Future<List<GrowthWeightVelocityPoint>?> weightVelocityIntervals({
    int period = 1,
  }) async {
    final doc = await _velocityDocument(period);
    _velocity
      ..clear()
      ..addAll(doc.list('whoIntervals'));
    final intervals = <String, Map<String, dynamic>>{};
    for (final item in doc.list('actualIntervals')) {
      intervals[item['intervalId'].toString()] = {
        ...item,
        if (item['referenceStatus'] == 'REFERENCE_MATCHED')
          'referenceStatus': 'NO_EXACT_REFERENCE',
      };
    }
    for (final item in doc.list('whoIntervals')) {
      intervals[item['intervalId'].toString()] = item;
    }
    final result = <GrowthWeightVelocityPoint>[];
    for (final item in intervals.values) {
      if (item['calculationStatus'] != 'READY' ||
          item['deltaUnit'] != 'g' ||
          item['deltaValue'] is! num)
        continue;
      final from = item['from'] as Map, to = item['to'] as Map;
      final a = DateTime.parse(from['measuredOn'].toString());
      final b = DateTime.parse(to['measuredOn'].toString());
      final start = (from['ageDays'] as num).toDouble() / 30.4375;
      final end = (to['ageDays'] as num).toDouble() / 30.4375;
      final matched = item['matchedReference'] as Map?;
      final content = item['content'] as Map?;
      final comment = content?['comment'] as Map?;
      result.add(
        GrowthWeightVelocityPoint(
          matched != null && item['referenceStatus'] == 'REFERENCE_MATCHED'
              ? matched['startAgeUnit'] == 'weeks'
                    ? 1
                    : (matched['startAgeValue'] as num?)?.toInt() ??
                          start.floor()
              : start.floor(),
          (item['deltaValue'] as num).toDouble(),
          a,
          b,
          id: item['intervalId'].toString(),
          startAgeMonths: start,
          endAgeMonths: end,
          serverLabel: item['referenceStatus'] == 'REFERENCE_MATCHED'
              ? (matched == null ? null : matched['intervalLabel']?.toString())
              : '${a.day}/${a.month}/${a.year}–${b.day}/${b.month}/${b.year} · Chỉ ghi nhận',
          fromKg: (from['rawValue'] as num?)?.toDouble(),
          toKg: (to['rawValue'] as num?)?.toDouble(),
          elapsedDays: (item['elapsedDays'] as num?)?.toInt(),
          referenceValues: {
            for (final value in matched?['sdValues'] as List? ?? const [])
              (value['sd'] as num).toInt(): (value['value'] as num).toDouble(),
          },
          explanation: comment != null && comment['status'] == 'READY'
              ? comment['text']?.toString()
              : null,
          advice: [
            for (final advice in content?['advice'] as List? ?? const [])
              if (advice is Map &&
                  advice['status'] == 'READY' &&
                  advice['text'] is String)
                advice['text'] as String,
          ],
          intervalMonths: item['referenceStatus'] == 'REFERENCE_MATCHED'
              ? (matched?['tableIntervalMonths'] as num?)?.toInt() ?? 1
              : 0,
          referenceStatus:
              item['referenceStatus']?.toString() ?? 'NOT_REQUESTED',
          referenceReason: item['referenceReason']?.toString(),
          zScore:
              item['referenceStatus'] == 'REFERENCE_MATCHED' &&
                  item['zScoreStatus'] == 'READY'
              ? (item['zScore'] as num?)?.toDouble()
              : null,
        ),
      );
    }
    result.sort((a, b) {
      final order = a.to.compareTo(b.to);
      return order == 0 ? a.from.compareTo(b.from) : order;
    });
    return result;
  }

  @override
  Future<GrowthWeightVelocityReference?> weightVelocityPeriodReference(
    int period,
  ) async {
    final doc = await _velocityDocument(period);
    final rows = doc.list('referenceIntervals');
    if (rows.isEmpty) return null;
    return GrowthWeightVelocityReference.fromIntervals(
      rows,
      DateTime.tryParse(doc.child['dateOfBirth']?.toString() ?? ''),
    );
  }

  @override
  Future<GrowthWeightVelocityReference?> weightVelocityReference() async {
    final doc = await _velocityDocument(1);
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
