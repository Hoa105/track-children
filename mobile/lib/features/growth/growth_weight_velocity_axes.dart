import 'dart:math' as math;

class GrowthVelocityValueAxis {
  const GrowthVelocityValueAxis(this.min, this.max, this.step);
  final double min, max, step;
  List<double> get ticks => [
    for (var i = 0; i <= ((max - min) / step).round(); i++) min + i * step,
  ];
}

GrowthVelocityValueAxis growthVelocityValueAxis(Iterable<double> values) {
  final valid = values.where((v) => v.isFinite);
  final low = valid.fold(0.0, math.min);
  final high = valid.fold(0.0, math.max);
  final range = high == low ? 400.0 : high - low;
  final target = range / 4;
  final power = math.pow(10, (math.log(target) / math.ln10).floor()).toDouble();
  final ratio = target / power;
  final step =
      (ratio <= 1
          ? 1
          : ratio <= 2
          ? 2
          : ratio <= 5
          ? 5
          : 10) *
      power;
  return GrowthVelocityValueAxis(
    (low / step).floor() * step,
    high == low ? step * 4 : (high / step).ceil() * step,
    step,
  );
}

List<int> growthVelocityAgeTicks(int start, int end, {bool largeText = false}) {
  final target = (end - start) / (largeText ? 3 : 6);
  final step = [1, 2, 3, 6, 12, 24, 60].firstWhere((s) => s >= target);
  return [for (var value = start; value < end; value += step) value, end];
}
