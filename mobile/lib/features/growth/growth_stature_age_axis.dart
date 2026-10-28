import 'dart:math' as math;

({double min, double max, double step}) growthStatureAgeAxis(
  Iterable<double> values,
) {
  final valid = values.where((v) => v.isFinite && v > 0).toList();
  if (valid.isEmpty) return (min: 40, max: 120, step: 20);
  final low = valid.reduce(math.min) - 2;
  final high = valid.reduce(math.max) + 2;
  final target = (high - low) / 5;
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
  return (
    min: math.max(0, (low / step).floor() * step),
    max: (high / step).ceil() * step,
    step: step,
  );
}
