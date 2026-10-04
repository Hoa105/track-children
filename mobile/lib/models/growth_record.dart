enum GrowthMetricType { weight, height, headCircumference }

extension GrowthMetricTypeX on GrowthMetricType {
  String get label => switch (this) {
        GrowthMetricType.weight => 'Cân nặng',
        GrowthMetricType.height => 'Chiều cao',
        GrowthMetricType.headCircumference => 'Vòng đầu',
      };

  String get unit => switch (this) {
        GrowthMetricType.weight => 'kg',
        GrowthMetricType.height => 'cm',
        GrowthMetricType.headCircumference => 'cm',
      };

  String get inputLabel => switch (this) {
        GrowthMetricType.weight => 'Cân nặng (kg)',
        GrowthMetricType.height => 'Chiều dài / cao (cm)',
        GrowthMetricType.headCircumference => 'Vòng đầu (cm)',
      };
}

class GrowthRecord {
  final String childId;
  final GrowthMetricType metricType;
  final double value;
  final DateTime date;
  final int percentile;

  const GrowthRecord({
    required this.childId,
    required this.metricType,
    required this.value,
    required this.date,
    required this.percentile,
  });
}

/// A metric series for one tab of the Growth tracking screen — mirrors the
/// prototype's `metrics` array (label/unit/current value/percentile + a
/// rising point series for the chart).
class GrowthMetricSeries {
  final GrowthMetricType type;
  final String currentValueLabel;
  final int percentile;
  final List<String> axisLabels; // top/mid/bottom axis labels, high→low
  final List<double> points; // relative series, rising left→right

  const GrowthMetricSeries({
    required this.type,
    required this.currentValueLabel,
    required this.percentile,
    required this.axisLabels,
    required this.points,
  });
}
