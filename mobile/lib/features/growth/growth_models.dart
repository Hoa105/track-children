enum GrowthMetric { weight, lengthHeight, headCircumference }

String formatGrowthValue(double value) => value
    .toStringAsFixed(3)
    .replaceFirst(RegExp(r'\.?0+$'), '')
    .replaceAll('.', ',');

enum GrowthMeasurementMethod { recumbent, standing }

extension GrowthMetricPresentation on GrowthMetric {
  String get title => switch (this) {
    GrowthMetric.weight => 'Cân nặng',
    GrowthMetric.lengthHeight => 'Chiều dài/chiều cao',
    GrowthMetric.headCircumference => 'Vòng đầu',
  };

  String get unit => this == GrowthMetric.weight ? 'kg' : 'cm';

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

class GrowthMeasurementDraft {
  const GrowthMeasurementDraft({
    required this.value,
    required this.measuredAt,
    this.method,
    this.id,
  });

  final double value;
  final DateTime measuredAt;
  final GrowthMeasurementMethod? method;
  final String? id;
}

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
