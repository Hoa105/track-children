import 'dart:math' as math;

import 'growth_models.dart';

class GrowthChartValueScale {
  const GrowthChartValueScale(this.low, this.high, this.step);
  final double low, high, step;

  factory GrowthChartValueScale.forRows(
    List<GrowthMeasurementDraft> rows,
    GrowthMetric metric,
  ) {
    final minimum = rows.map((r) => r.value).reduce(math.min);
    final maximum = rows.map((r) => r.value).reduce(math.max);
    final minimumStep = metric == GrowthMetric.weight ? .5 : 1.0;
    final raw = math.max(minimumStep, (maximum - minimum) / 4);
    final magnitude = math
        .pow(10, (math.log(raw) / math.ln10).floor())
        .toDouble();
    final factor = [
      1.0,
      2.0,
      2.5,
      5.0,
      10.0,
    ].firstWhere((value) => value * magnitude >= raw - 1e-9);
    final step = factor * magnitude;
    var low = (minimum / step).floor() * step;
    var high = (maximum / step).ceil() * step;
    if ((minimum - low).abs() < 1e-9) low -= step;
    if ((high - maximum).abs() < 1e-9) high += step;
    low = math.max(0, low);
    high = math.max(high, low + step * 2);
    return GrowthChartValueScale(low, high, step);
  }
}
