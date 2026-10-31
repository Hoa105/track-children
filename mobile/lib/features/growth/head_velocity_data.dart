import 'dart:math' as math;

import 'growth_models.dart';

class HeadVelocityRow {
  const HeadVelocityRow(this.start, this.end, this.l, this.m, this.s, this.sd);
  final int start, end;
  final double l, m, s;
  final List<double> sd;
  double centile(double z) => l == 0
      ? m * math.exp(s * z)
      : m * math.pow(1 + l * s * z, 1 / l).toDouble();

  // Personal velocity Z-scores require separately verified method fixtures.
  // Keep published SD thresholds available without inferring an LMS algorithm.
  double? zScore(double gain) => null;
}

class HeadVelocityReference {
  const HeadVelocityReference(this.period, this.sexLabel, this.rows);
  final int period;
  final String sexLabel;
  final List<HeadVelocityRow> rows;
  factory HeadVelocityReference.fromJson(
    Map<String, dynamic> json,
    String sex,
    int period,
  ) {
    if (json['unit'] != 'cm' ||
        ![2, 3, 4, 6].contains(period) ||
        !['boys', 'girls'].contains(sex)) {
      throw const FormatException(
        'Invalid WHO head circumference velocity table',
      );
    }
    final raw = json['tables'][sex]['$period']['rows'] as List;
    if (raw.length != (period <= 3 ? 13 : 25) - period) {
      throw const FormatException(
        'Incomplete WHO head circumference velocity table',
      );
    }
    final rows = <HeadVelocityRow>[];
    for (var i = 0; i < raw.length; i++) {
      final r = raw[i];
      final sd = [for (final n in r['sd']) (n as num).toDouble()];
      final l = (r['l'] as num).toDouble(),
          m = (r['m'] as num).toDouble(),
          s = (r['s'] as num).toDouble();
      if (r['start'] != i ||
          r['end'] != i + period ||
          sd.length != 7 ||
          ![l, m, s, ...sd].every((n) => n.isFinite) ||
          m <= 0 ||
          s <= 0 ||
          sd.any((n) => n < 0) ||
          List.generate(6, (j) => sd[j] > sd[j + 1]).any((v) => v)) {
        throw const FormatException(
          'Invalid WHO head circumference velocity row',
        );
      }
      rows.add(HeadVelocityRow(i, i + period, l, m, s, sd));
    }
    return HeadVelocityReference(
      period,
      sex == 'boys' ? 'Bé trai' : 'Bé gái',
      rows,
    );
  }
}

class HeadVelocityInterval {
  const HeadVelocityInterval(
    this.from,
    this.to,
    this.start,
    this.end, {
    this.row,
  });
  final GrowthMeasurementDraft from, to;
  final double start, end;
  final HeadVelocityRow? row;
  double get gain => to.value - from.value;
  double? get z => row?.zScore(gain);
  String get referenceLabel => gain < 0
      ? 'Cần kiểm tra lại số đo'
      : row == null
      ? 'Chỉ ghi nhận'
      : gain < row!.sd[1]
      ? 'Dưới mốc −2 SD'
      : gain > row!.sd[5]
      ? 'Trên mốc +2 SD'
      : 'Trong khoảng −2 đến +2 SD';
}

/// Match both visits independently using WHO's ±3/5/7-day tolerances.
/// Head circumference does not use recumbent/standing measurement methods.
List<HeadVelocityInterval> headVelocityIntervals(
  List<GrowthMeasurementDraft> readings,
  DateTime? birth,
  int period,
  HeadVelocityReference? reference,
) {
  if (birth == null || ![2, 3, 4, 6].contains(period)) return [];
  DateTime day(DateTime d) => DateTime.utc(d.year, d.month, d.day);
  final origin = day(birth);
  DateTime anchor(int month) {
    // WHO 2009 Table 1: 4 weeks at the first visit, average months thereafter.
    return origin.add(
      Duration(days: month == 1 ? 28 : (month * 30.4375).round()),
    );
  }

  final unique = <DateTime, GrowthMeasurementDraft>{};
  for (final p in readings) {
    if (p.value.isFinite &&
        p.value > 0 &&
        !day(p.measuredAt).isBefore(origin)) {
      unique[day(p.measuredAt)] = p;
    }
  }
  final sorted = unique.values.toList()
    ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
  GrowthMeasurementDraft? near(int month) {
    final tolerance = month < 6
        ? 3
        : month < 12
        ? 5
        : 7;
    final candidates =
        sorted
            .where(
              (p) =>
                  day(p.measuredAt).difference(anchor(month)).inDays.abs() <=
                  tolerance,
            )
            .toList()
          ..sort(
            (a, b) => day(a.measuredAt)
                .difference(anchor(month))
                .inDays
                .abs()
                .compareTo(
                  day(b.measuredAt).difference(anchor(month)).inDays.abs(),
                ),
          );
    return candidates.firstOrNull;
  }

  final result = <HeadVelocityInterval>[];
  for (var start = 0; start + period <= (period <= 3 ? 12 : 24); start++) {
    final a = near(start), b = near(start + period);
    if (a == null || b == null || !b.measuredAt.isAfter(a.measuredAt)) continue;
    result.add(
      HeadVelocityInterval(
        a,
        b,
        start.toDouble(),
        (start + period).toDouble(),
        row: start + period >= 24
            ? null
            : reference?.rows.where((r) => r.start == start).firstOrNull,
      ),
    );
  }
  // Observations outside the WHO domain are kept as recordings.
  for (var i = 0; i < sorted.length; i++) {
    final a = sorted[i];
    final start = growthChartAgeMonths(birth, a.measuredAt);
    if (start == null) continue;
    final b = sorted
        .skip(i + 1)
        .where(
          (p) =>
              ((growthChartAgeMonths(birth, p.measuredAt) ?? -100) -
                      start -
                      period)
                  .abs() <
              .00001,
        )
        .firstOrNull;
    if (b == null || result.any((p) => p.from == a && p.to == b)) continue;
    final end = start + period;
    if (end > (period <= 3 ? 12 : 24) && end <= 60) {
      result.add(HeadVelocityInterval(a, b, start, end));
    }
  }
  return result..sort((a, b) => a.to.measuredAt.compareTo(b.to.measuredAt));
}
