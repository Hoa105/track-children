import 'package:flutter/material.dart';

enum GrowthMetric { weight, lengthHeight, headCircumference }

String growthTooltipZScore(double? value) => value == null || !value.isFinite
    ? 'Z-score: Chưa có dữ liệu'
    : 'Z-score: ${value > 0 ? '+' : ''}${value.toStringAsFixed(2).replaceAll('.', ',')} SD';

class GrowthIndexAssessment {
  const GrowthIndexAssessment({
    required this.classification,
    required this.zScore,
    required this.explanation,
  });
  final String classification, explanation;
  final double zScore;
  bool get isValid =>
      zScore.isFinite && classification.isNotEmpty && explanation.isNotEmpty;
}

class GrowthWeightAssessmentData {
  const GrowthWeightAssessmentData({this.wfa, this.wflh, this.combinedSummary});
  final GrowthIndexAssessment? wfa, wflh;
  final String? combinedSummary;
}

class GrowthStatureReference {
  const GrowthStatureReference(this.rows, this.sourceUrl);
  final List<List<double>> rows;
  final String sourceUrl;
  factory GrowthStatureReference.fromJson(
    Map<String, dynamic> json,
    GrowthReferenceSex sex,
    bool length,
  ) {
    if (json['unit'] != 'kg' || json['x_unit'] != 'cm') {
      throw const FormatException('Invalid stature reference units');
    }
    final key = '${length ? 'length' : 'height'}_${sex.name}';
    final raw = (json['tables'] as Map)[key] as List;
    final low = length ? 45.0 : 65.0;
    if (raw.length != (length ? 131 : 111)) {
      throw const FormatException('Incomplete stature reference');
    }
    final rows = <List<double>>[];
    for (var i = 0; i < raw.length; i++) {
      final row = (raw[i] as List).map((v) => (v as num).toDouble()).toList();
      if (row.length != 6 ||
          row[0] != low + i * .5 ||
          row.any((v) => !v.isFinite || v <= 0)) {
        throw const FormatException('Invalid stature reference row');
      }
      for (var j = 2; j < row.length; j++) {
        if (row[j] <= row[j - 1]) {
          throw const FormatException('Unordered stature thresholds');
        }
      }
      rows.add(List.unmodifiable(row));
    }
    return GrowthStatureReference(
      List.unmodifiable(rows),
      ((json['sources'] as Map)[key] as Map)['url'] as String,
    );
  }
}

enum GrowthMeasurementMethod { recumbent, standing }

enum GrowthReferenceSex { boys, girls }

extension GrowthMetricPresentation on GrowthMetric {
  String get title => switch (this) {
    GrowthMetric.weight => 'Cân nặng',
    GrowthMetric.lengthHeight => 'Chiều dài/chiều cao',
    GrowthMetric.headCircumference => 'Vòng đầu',
  };
  String get lowerTitle => title.toLowerCase();
  String get unit => this == GrowthMetric.weight ? 'kg' : 'cm';
  String get routeKey => switch (this) {
    GrowthMetric.weight => 'weight',
    GrowthMetric.lengthHeight => 'length',
    GrowthMetric.headCircumference => 'head',
  };
  String get asset => switch (this) {
    GrowthMetric.weight => 'overview-weight',
    GrowthMetric.lengthHeight => 'overview-height',
    GrowthMetric.headCircumference => 'overview-head',
  };
  String get initialValue => switch (this) {
    GrowthMetric.weight => '8,8',
    GrowthMetric.lengthHeight => '76,5',
    GrowthMetric.headCircumference => '45,5',
  };
  String get measurementTip => switch (this) {
    GrowthMetric.weight => 'Nên cân bé vào buổi sáng, trước khi ăn, mặc quần áo mỏng để kết quả chính xác hơn.',
    GrowthMetric.lengthHeight => 'Ghi đúng cách đo: chiều dài nằm hoặc chiều cao đứng. Giữ cùng cách đo để dễ theo dõi các lần tiếp theo.',
    GrowthMetric.headCircumference => 'Dùng thước dây mềm, đặt ngang quanh phần rộng nhất của đầu và ghi lại số đo bằng cm.',
  };
}

class GrowthMetricViewData {
  const GrowthMetricViewData(
    this.title,
    this.value,
    this.unit,
    this.asset,
    this.color,
    this.points, {
    this.averageZScoreText,
  });
  final String title, value, unit, asset;
  final Color color;
  final List<double> points;

  /// Formatted by the verified WHO/domain layer; null when unavailable.
  final String? averageZScoreText;
}

class GrowthMeasurementDraft {
  const GrowthMeasurementDraft({
    required this.value,
    required this.measuredAt,
    this.method,
  });
  final double value;
  final DateTime measuredAt;
  final GrowthMeasurementMethod? method;
}

/// Calendar age for chart positioning only, never a WHO calculation.
double? growthChartAgeMonths(DateTime birth, DateTime measuredAt) {
  DateTime anchor(int months) {
    final first = DateTime(birth.year, birth.month + months);
    final lastDay = DateTime(first.year, first.month + 1, 0).day;
    return DateTime.utc(first.year, first.month, birth.day.clamp(1, lastDay));
  }

  final date = DateTime.utc(measuredAt.year, measuredAt.month, measuredAt.day);
  if (date.isBefore(anchor(0)) || date.isAfter(anchor(60))) return null;
  var months =
      (measuredAt.year - birth.year) * 12 + measuredAt.month - birth.month;
  if (date.isBefore(anchor(months))) months--;
  final start = anchor(months);
  final end = anchor(months + 1);
  return months + date.difference(start).inDays / end.difference(start).inDays;
}

class GrowthWeightReferenceRow {
  const GrowthWeightReferenceRow(this.month, this.weights);
  final int month;

  /// WHO thresholds: -3 SD, -2 SD, median, +2 SD, +3 SD, kg.
  final List<double> weights;
}

class GrowthWeightReference {
  const GrowthWeightReference({
    required this.sex,
    required this.rows,
    required this.sourceUrl,
    required this.sourceHash,
  });
  final GrowthReferenceSex sex;
  final List<GrowthWeightReferenceRow> rows;
  final String sourceUrl, sourceHash;
  String get sexLabel => sex == GrowthReferenceSex.boys ? 'bé trai' : 'bé gái';

  factory GrowthWeightReference.fromJson(
    Map<String, dynamic> json,
    GrowthReferenceSex sex,
  ) {
    if (json['indicator'] != 'weight-for-age' ||
        json['unit'] != 'kg' ||
        json['age_unit'] != 'months') {
      throw const FormatException('Unexpected WHO indicator or units');
    }
    final raw = (json['tables'] as Map)[sex.name] as List;
    if (raw.length != 61) {
      throw const FormatException('Expected ages 0 through 60');
    }
    final rows = <GrowthWeightReferenceRow>[];
    for (var month = 0; month <= 60; month++) {
      final row = raw[month] as List;
      if (row.length != 6 || row[0] != month) {
        throw const FormatException('Unexpected month');
      }
      final weights = row.skip(1).map((v) => (v as num).toDouble()).toList();
      for (var i = 0; i < weights.length; i++) {
        if (!weights[i].isFinite ||
            weights[i] <= 0 ||
            (i > 0 && weights[i] <= weights[i - 1])) {
          throw const FormatException('Invalid reference thresholds');
        }
      }
      rows.add(GrowthWeightReferenceRow(month, List.unmodifiable(weights)));
    }
    final source = (json['sources'] as Map)[sex.name] as Map;
    return GrowthWeightReference(
      sex: sex,
      rows: List.unmodifiable(rows),
      sourceUrl: source['url'] as String,
      sourceHash: source['sha256'] as String,
    );
  }
}
