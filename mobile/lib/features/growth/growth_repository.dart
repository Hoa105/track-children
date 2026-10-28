import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:convert';

import 'growth_models.dart';
import 'growth_stature_velocity_reference.dart';
import 'growth_weight_velocity_data.dart';
export 'growth_models.dart';

abstract class GrowthRepository {
  Future<GrowthStatureVelocityReference?> headVelocityReference() async => null;
  Future<GrowthStatureVelocityReference?> statureVelocityReference() async =>
      null;
  Future<GrowthWeightReference?> bmiAgeReference(bool length) async => null;
  Future<List<GrowthMeasurementDraft>> bmiMeasurements() async {
    final weights = await weightMeasurements();
    final statures = await measurements(GrowthMetric.lengthHeight);
    final byDate = {
      for (final p in statures) DateUtils.dateOnly(p.measuredAt): p,
    };
    final bmi = <DateTime, GrowthMeasurementDraft>{};
    for (final weight in weights) {
      final date = DateUtils.dateOnly(weight.measuredAt);
      final stature = byDate[date];
      if (stature == null ||
          !weight.value.isFinite ||
          !stature.value.isFinite ||
          weight.value <= 0 ||
          stature.value <= 0) {
        continue;
      }
      final meters = stature.value / 100;
      final value = weight.value / (meters * meters);
      if (value.isFinite) {
        bmi[date] = GrowthMeasurementDraft(
          value: value,
          measuredAt: date,
          method: stature.method,
        );
      }
    }
    return bmi.values.toList()
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
  }

  Future<GrowthWeightReference?> headAgeReference() async => null;
  Future<GrowthWeightReference?> statureAgeReference(bool length) async => null;
  double? weightVelocityDisplayZScore(GrowthWeightVelocityPoint point) => null;
  Future<GrowthWeightVelocityReference?> weightVelocityReference() async =>
      null;
  GrowthWeightAssessmentData? weightAssessmentFor(
    GrowthMeasurementDraft weight,
    GrowthMeasurementDraft? stature,
  ) => null;
  DateTime? get dateOfBirth => null;
  Future<GrowthWeightReference?> weightReference() async => null;
  Future<GrowthStatureReference?> statureReference(bool length) async => null;
  Future<List<GrowthMetricViewData>> loadOverview();
  Future<List<GrowthMeasurementDraft>> weightMeasurements() async => const [];
  Future<GrowthMeasurementDraft?> weightBefore(DateTime date) async => null;
  Future<void> saveWeight(GrowthMeasurementDraft draft) async =>
      throw UnsupportedError('Saving is not available');
  Future<List<GrowthMeasurementDraft>> measurements(GrowthMetric metric) =>
      metric == GrowthMetric.weight
      ? weightMeasurements()
      : Future.value(const []);
  Future<GrowthMeasurementDraft?> measurementBefore(
    GrowthMetric metric,
    DateTime date,
  ) async {
    if (metric == GrowthMetric.weight) return weightBefore(date);
    final data =
        (await measurements(metric))
            .where((m) => m.measuredAt.isBefore(DateUtils.dateOnly(date)))
            .toList()
          ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    return data.lastOrNull;
  }

  Future<void> saveMeasurement(
    GrowthMetric metric,
    GrowthMeasurementDraft draft,
  ) => metric == GrowthMetric.weight
      ? saveWeight(draft)
      : Future.error(UnsupportedError('Saving is not available'));
}

/// Per-flow in-memory fixtures. No backend, persistence or WHO assessment.
class MockGrowthRepository extends GrowthRepository {
  @override
  Future<GrowthStatureVelocityReference?> headVelocityReference() async =>
      GrowthStatureVelocityReference.fromJson(
        jsonDecode(
          await rootBundle.loadString(
            'assets/data/who/head_velocity_2month.json',
          ),
        ) as Map<String, dynamic>,
        referenceSex.name,
        maxAgeMonths: 12,
      );
  @override
  Future<GrowthStatureVelocityReference?> statureVelocityReference() async =>
      GrowthStatureVelocityReference.fromJson(
        jsonDecode(
          await rootBundle.loadString(
            'assets/data/who/stature_velocity_2month.json',
          ),
        ) as Map<String, dynamic>,
        referenceSex.name,
      );
  @override
  Future<GrowthWeightReference?> bmiAgeReference(bool length) async {
    final json = jsonDecode(
      await rootBundle.loadString('assets/data/who_bmi.json'),
    ) as Map<String, dynamic>;
    final all = json[referenceSex.name] as List;
    final rows = length ? all.take(25) : all.skip(25);
    // Original bundled WHO display thresholds; no LMS or Z-score calculation.
    return GrowthWeightReference(
      sex: referenceSex,
      rows: [
        for (final r in rows)
          GrowthWeightReferenceRow((r[0] as num).toInt(), [
            for (final i in [4, 5, 7, 9, 10]) (r[i] as num).toDouble(),
          ]),
      ],
      sourceUrl: json['source'] as String,
      sourceHash: '',
    );
  }

  @override
  Future<GrowthWeightReference?> headAgeReference() async {
    final json = jsonDecode(
      await rootBundle.loadString('assets/data/who/head_for_age_curves.json'),
    ) as Map<String, dynamic>;
    final rows = (json['tables'] as Map)[referenceSex.name] as List;
    final source = (json['sources'] as Map)[referenceSex.name] as Map;
    return GrowthWeightReference(
      sex: referenceSex,
      rows: [
        for (final r in rows)
          GrowthWeightReferenceRow((r[0] as num).toInt(), [
            for (final v in (r as List).skip(1)) (v as num).toDouble(),
          ]),
      ],
      sourceUrl: source['url'] as String,
      sourceHash: source['sha256'] as String,
    );
  }

  @override
  Future<GrowthWeightReference?> statureAgeReference(bool length) async {
    final json = jsonDecode(
      await rootBundle.loadString(
        'assets/data/who/stature_for_age_curves.json',
      ),
    ) as Map<String, dynamic>;
    final key = '${length ? 'length' : 'height'}_${referenceSex.name}';
    final raw = (json['tables'] as Map)[key] as List;
    final source = (json['sources'] as Map)[key] as Map;
    // Reuse the age-chart display row shape; numeric values here are cm.
    return GrowthWeightReference(
      sex: referenceSex,
      rows: [
        for (final row in raw)
          GrowthWeightReferenceRow((row[0] as num).toInt(), [
            for (final v in (row as List).skip(1)) (v as num).toDouble(),
          ]),
      ],
      sourceUrl: source['url'] as String,
      sourceHash: source['sha256'] as String,
    );
  }

  /// Explicit UI fixtures only; never used as a calculated WHO assessment.
  @override
  double? weightVelocityDisplayZScore(GrowthWeightVelocityPoint point) {
    if (referenceSex != GrowthReferenceSex.boys) return null;
    const samples = {
      7: (100, -1.10),
      8: (300, 0.20),
      9: (200, -0.15),
      10: (300, 0.60),
      11: (300, 0.65),
    };
    final sample = samples[point.startMonth];
    if (sample == null ||
        (point.grams - sample.$1).abs() > .001 ||
        !DateUtils.isSameDay(
          point.from,
          DateTime(2024, 5 + point.startMonth, 15),
        ) ||
        !DateUtils.isSameDay(
          point.to,
          DateTime(2024, 6 + point.startMonth, 15),
        )) {
      return null;
    }
    return sample.$2;
  }

  @override
  Future<GrowthWeightVelocityReference?> weightVelocityReference() async =>
      GrowthWeightVelocityReference.fromJson(
        jsonDecode(
          await rootBundle.loadString(
            'assets/data/who/weight_velocity_1month.json',
          ),
        ) as Map<String, dynamic>,
        referenceSex,
      );
  // UI-only review fixture, never calculated from WHO display curves.
  @override
  GrowthWeightAssessmentData? weightAssessmentFor(
    GrowthMeasurementDraft weight,
    GrowthMeasurementDraft? stature,
  ) {
    if (referenceSex != GrowthReferenceSex.boys) return null;
    final april =
        DateUtils.isSameDay(weight.measuredAt, DateTime(2025, 4, 15)) &&
        weight.value == 8.5;
    final may =
        DateUtils.isSameDay(weight.measuredAt, DateTime(2025, 5, 15)) &&
        weight.value == 8.8;
    if (!april && !may) return null;
    final paired =
        stature != null &&
        DateUtils.isSameDay(weight.measuredAt, stature.measuredAt) &&
        stature.method == GrowthMeasurementMethod.recumbent &&
        stature.value == (april ? 75 : 76.5);
    return GrowthWeightAssessmentData(
      wfa: const GrowthIndexAssessment(
        classification: 'Phù hợp với tuổi',
        zScore: -0.40,
        explanation: 'Cân nặng của bé nằm trong khoảng phù hợp với trẻ cùng tuổi và giới tính.',
      ),
      wflh: paired
          ? const GrowthIndexAssessment(
              classification: 'Cân đối với chiều dài',
              zScore: 0.60,
              explanation: 'Cân nặng của bé cân đối với chiều dài hiện tại.',
            )
          : null,
      combinedSummary: paired
          ? 'Cân nặng của bé hiện phù hợp với tuổi và cân đối với chiều dài. Ba mẹ hãy tiếp tục theo dõi các lần đo tiếp theo nhé!'
          : null,
    );
  }

  MockGrowthRepository({this.referenceSex = GrowthReferenceSex.boys});
  final GrowthReferenceSex referenceSex;
  late final Future<GrowthWeightReference?> _reference = _loadReference();
  Future<GrowthWeightReference?> _loadReference() async =>
      GrowthWeightReference.fromJson(
        jsonDecode(
          await rootBundle.loadString(
            'assets/data/who/weight_for_age_curves.json',
          ),
        ) as Map<String, dynamic>,
        referenceSex,
      );
  @override
  Future<GrowthWeightReference?> weightReference() => _reference;
  late final Future<Map<String, dynamic>> _statureTables = rootBundle
      .loadString('assets/data/who/weight_for_stature_curves.json')
      .then((raw) => jsonDecode(raw) as Map<String, dynamic>);
  @override
  Future<GrowthStatureReference?> statureReference(bool length) async =>
      GrowthStatureReference.fromJson(
        await _statureTables,
        referenceSex,
        length,
      );

  /// Fictional chart context, consistent with these in-memory fixtures.
  @override
  DateTime get dateOfBirth => DateTime(2024, 5, 15);
  final List<GrowthMeasurementDraft> _weights = [
    GrowthMeasurementDraft(value: 3.2, measuredAt: DateTime(2024, 5, 15)),
    GrowthMeasurementDraft(value: 6.7, measuredAt: DateTime(2024, 9, 15)),
    GrowthMeasurementDraft(value: 7.6, measuredAt: DateTime(2024, 12, 15)),
    GrowthMeasurementDraft(value: 7.7, measuredAt: DateTime(2025, 1, 15)),
    GrowthMeasurementDraft(value: 8, measuredAt: DateTime(2025, 2, 15)),
    GrowthMeasurementDraft(value: 8.2, measuredAt: DateTime(2025, 3, 15)),
    GrowthMeasurementDraft(value: 8.5, measuredAt: DateTime(2025, 4, 15)),
  ];
  final List<GrowthMeasurementDraft> _lengths = [
    GrowthMeasurementDraft(
      value: 50,
      measuredAt: DateTime(2024, 5, 15),
      method: GrowthMeasurementMethod.recumbent,
    ),
    GrowthMeasurementDraft(
      value: 64,
      measuredAt: DateTime(2024, 9, 15),
      method: GrowthMeasurementMethod.recumbent,
    ),
    GrowthMeasurementDraft(
      value: 68.5,
      measuredAt: DateTime(2024, 12, 15),
      method: GrowthMeasurementMethod.recumbent,
    ),
    GrowthMeasurementDraft(
      value: 70,
      measuredAt: DateTime(2025, 1, 15),
      method: GrowthMeasurementMethod.recumbent,
    ),
    GrowthMeasurementDraft(
      value: 72,
      measuredAt: DateTime(2025, 2, 15),
      method: GrowthMeasurementMethod.recumbent,
    ),
    GrowthMeasurementDraft(
      value: 73.5,
      measuredAt: DateTime(2025, 3, 15),
      method: GrowthMeasurementMethod.recumbent,
    ),
    GrowthMeasurementDraft(
      value: 75,
      measuredAt: DateTime(2025, 4, 15),
      method: GrowthMeasurementMethod.recumbent,
    ),
  ];
  final List<GrowthMeasurementDraft> _heads = [
    GrowthMeasurementDraft(value: 43.5, measuredAt: DateTime(2025, 1, 15)),
    GrowthMeasurementDraft(value: 44, measuredAt: DateTime(2025, 2, 15)),
    GrowthMeasurementDraft(value: 44.2, measuredAt: DateTime(2025, 3, 15)),
    GrowthMeasurementDraft(value: 45, measuredAt: DateTime(2025, 4, 15)),
  ];

  @override
  Future<List<GrowthMeasurementDraft>> measurements(
    GrowthMetric metric,
  ) async => metric == GrowthMetric.weight
      ? weightMeasurements()
      : List.unmodifiable(
          metric == GrowthMetric.lengthHeight ? _lengths : _heads,
        );

  @override
  Future<List<GrowthMeasurementDraft>> weightMeasurements() async =>
      List.unmodifiable(_weights);

  @override
  Future<List<GrowthMetricViewData>> loadOverview() async {
    final bmiPoints = <double>[];
    for (final weight in _weights) {
      final stature = _lengths
          .where(
            (entry) => DateUtils.isSameDay(entry.measuredAt, weight.measuredAt),
          )
          .firstOrNull;
      if (stature == null || stature.value <= 0) continue;
      final metres = stature.value / 100;
      final bmi = weight.value / (metres * metres);
      if (bmi.isFinite && bmi > 0) bmiPoints.add(bmi);
    }
    return [
      GrowthMetricViewData(
        'Cân nặng',
        formatGrowthValue(_weights.last.value),
        'kg',
        'weight',
        const Color(0xFFE58A42),
        _weights
            .skip(_weights.length > 4 ? _weights.length - 4 : 0)
            .map((m) => m.value)
            .toList(),
      ),
      GrowthMetricViewData(
        'Chiều dài',
        formatGrowthValue(_lengths.last.value),
        'cm',
        'height',
        const Color(0xFF4B92C6),
        _lengths.map((m) => m.value).toList(),
      ),
      GrowthMetricViewData(
        'Vòng đầu',
        formatGrowthValue(_heads.last.value),
        'cm',
        'head',
        const Color(0xFF9B7AC2),
        _heads.map((m) => m.value).toList(),
      ),
      GrowthMetricViewData(
        'BMI',
        bmiPoints.isEmpty
            ? '__'
            : bmiPoints.last.toStringAsFixed(1).replaceAll('.', ','),
        'kg/m²',
        'bmi',
        const Color(0xFF277B58),
        bmiPoints,
      ),
    ];
  }

  @override
  Future<GrowthMeasurementDraft?> weightBefore(DateTime date) async {
    final before = _weights.where(
      (m) => m.measuredAt.isBefore(DateUtils.dateOnly(date)),
    );
    return before.isEmpty ? null : before.last;
  }

  @override
  Future<void> saveWeight(GrowthMeasurementDraft draft) async {
    _save(_weights, draft);
  }

  @override
  Future<void> saveMeasurement(
    GrowthMetric metric,
    GrowthMeasurementDraft draft,
  ) async {
    if (metric == GrowthMetric.weight) return saveWeight(draft);
    if (metric == GrowthMetric.lengthHeight && draft.method == null) {
      throw ArgumentError('Measurement method is required');
    }
    _save(metric == GrowthMetric.lengthHeight ? _lengths : _heads, draft);
  }

  void _save(
    List<GrowthMeasurementDraft> entries,
    GrowthMeasurementDraft draft,
  ) {
    final day = DateUtils.dateOnly(draft.measuredAt);
    if (!draft.value.isFinite ||
        draft.value <= 0 ||
        day.isAfter(DateUtils.dateOnly(DateTime.now()))) {
      throw ArgumentError('Invalid measurement');
    }
    entries.removeWhere((m) => DateUtils.isSameDay(m.measuredAt, day));
    entries.add(
      GrowthMeasurementDraft(
        value: draft.value,
        measuredAt: day,
        method: draft.method,
      ),
    );
    entries.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
  }
}

String formatGrowthValue(double value) => value
    .toStringAsFixed(3)
    .replaceFirst(RegExp(r'\.?0+$'), '')
    .replaceAll('.', ',');
