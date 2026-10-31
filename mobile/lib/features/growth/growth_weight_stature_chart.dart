import 'weight_chart_view.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'growth_models.dart';

({double min, double max}) growthStatureDisplayRange(
  double? current,
  double? radius,
  double domainMin,
  double domainMax,
) {
  if (current == null ||
      radius == null ||
      current < domainMin ||
      current > domainMax) {
    return (min: domainMin, max: domainMax);
  }
  return (
    min: math.max(domainMin, current - radius),
    max: math.min(domainMax, current + radius),
  );
}

class GrowthWeightStatureChart extends StatefulWidget {
  const GrowthWeightStatureChart({
    required this.weights,
    required this.statures,
    required this.dateOfBirth,
    required this.useLength,
    required this.statureLabel,
    this.reference,
    this.zScoreForDate,
    this.classificationForDate,
    this.easyReadMode = false,
    super.key,
  });
  final List<GrowthMeasurementDraft> weights, statures;
  final DateTime? dateOfBirth;
  final bool? useLength;
  final String statureLabel;
  final GrowthStatureReference? reference;
  final double? Function(DateTime)? zScoreForDate;
  final String? Function(DateTime)? classificationForDate;
  final bool easyReadMode;

  @override
  State<GrowthWeightStatureChart> createState() =>
      _GrowthWeightStatureChartState();
}

class _GrowthWeightStatureChartState extends State<GrowthWeightStatureChart> {
  @override
  Widget build(BuildContext context) {
    final birth = widget.dateOfBirth;
    final points = <WeightDatum>[];
    if (birth != null && widget.useLength != null) {
      for (final w in widget.weights) {
        final days = DateTime.utc(
          w.measuredAt.year,
          w.measuredAt.month,
          w.measuredAt.day,
        ).difference(DateTime.utc(birth.year, birth.month, birth.day)).inDays;
        if (days < 0 || (days < 731) != widget.useLength) continue;
        for (final h in widget.statures) {
          if (!DateUtils.isSameDay(w.measuredAt, h.measuredAt) ||
              h.method == null) {
            continue;
          }
          if (days / 30.4375 < 9 &&
              h.method == GrowthMeasurementMethod.standing) {
            continue;
          }
          final cm =
              h.value +
              (days < 731 && h.method == GrowthMeasurementMethod.standing
                  ? .7
                  : days >= 731 && h.method == GrowthMeasurementMethod.recumbent
                  ? -.7
                  : 0);
          final low = widget.useLength! ? 45 : 65,
              high = widget.useLength! ? 110 : 120;
          if (cm < low || cm > high) continue;
          points.add((
            x: cm,
            kg: w.value,
            date: w.measuredAt,
            z: widget.zScoreForDate?.call(w.measuredAt),
          ));
          break;
        }
      }
    }
    return WeightChartView(
      birth: birth,
      classificationForDate: widget.classificationForDate,
      title: 'Cân nặng theo ${widget.statureLabel}',
      age: false,
      start: widget.useLength == false ? 65 : 45,
      end: widget.useLength == false ? 120 : 110,
      points: points,
      curves: [
        for (final r in widget.reference?.rows ?? <List<double>>[])
          (x: r.first, kg: r.sublist(1)),
      ],
    );
  }
}
