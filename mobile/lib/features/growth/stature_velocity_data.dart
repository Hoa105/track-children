import 'dart:math' as math;

import 'growth_models.dart';

class StatureVelocityRow {
  const StatureVelocityRow(
    this.start,
    this.end,
    this.l,
    this.m,
    this.s,
    this.sd,
  );
  final int start, end;
  final double l, m, s;
  final List<double> sd;
  double centile(double z) => l == 0
      ? m * math.exp(s * z)
      : m * math.pow(1 + l * s * z, 1 / l).toDouble();

  // WHO 2009, pp. 226–227: LMS within ±3, linear tail extension beyond.
  double? zScore(double gain) {
    if (!gain.isFinite || gain < 0) return null;
    final raw = l == 0
        ? (gain > 0 ? math.log(gain / m) / s : double.negativeInfinity)
        : (math.pow(gain / m, l) - 1) / (l * s);
    if (raw > 3) return 3 + (gain - centile(3)) / (centile(3) - centile(2));
    if (raw < -3) {
      return -3 + (gain - centile(-3)) / (centile(-2) - centile(-3));
    }
    return raw.isFinite ? raw.toDouble() : null;
  }
}

class StatureVelocityReference {
  const StatureVelocityReference(this.period, this.sexLabel, this.rows);
  final int period;
  final String sexLabel;
  final List<StatureVelocityRow> rows;
  factory StatureVelocityReference.fromJson(
    Map<String, dynamic> json,
    String sex,
    int period,
  ) {
    if (json['unit'] != 'cm' ||
        ![2, 3, 4, 6].contains(period) ||
        !['boys', 'girls'].contains(sex)) {
      throw const FormatException('Invalid WHO length velocity table');
    }
    final raw = json['tables'][sex]['$period']['rows'] as List;
    if (raw.length != 25 - period) {
      throw const FormatException('Incomplete WHO length velocity table');
    }
    final rows = <StatureVelocityRow>[];
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
          List.generate(6, (j) => sd[j] >= sd[j + 1]).any((v) => v)) {
        throw const FormatException('Invalid WHO length velocity row');
      }
      rows.add(StatureVelocityRow(i, i + period, l, m, s, sd));
    }
    return StatureVelocityReference(
      period,
      sex == 'boys' ? 'Bé trai' : 'Bé gái',
      rows,
    );
  }
}

class StatureVelocityInterval {
  const StatureVelocityInterval(
    this.from,
    this.to,
    this.start,
    this.end, {
    this.row,
  });
  final GrowthMeasurementDraft from, to;
  final double start, end;
  final StatureVelocityRow? row;
  double get gain => to.value - from.value;
  double? get z => row?.zScore(gain);
}

/// Match both visits independently using WHO's ±3/5/7-day tolerances.
/// Do not convert standing measurements into recumbent velocity observations.
List<StatureVelocityInterval> statureVelocityIntervals(
  List<GrowthMeasurementDraft> readings,
  DateTime? birth,
  int period,
  StatureVelocityReference? reference,
) {
  if (birth == null || ![2, 3, 4, 6].contains(period)) return [];
  DateTime day(DateTime d) => DateTime.utc(d.year, d.month, d.day);
  final origin = day(birth);
  DateTime anchor(int month) {
    final last = DateTime.utc(birth.year, birth.month + month + 1, 0).day;
    return DateTime.utc(
      birth.year,
      birth.month + month,
      math.min(birth.day, last),
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
                  p.method == GrowthMeasurementMethod.recumbent &&
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

  final result = <StatureVelocityInterval>[];
  for (var start = 0; start + period <= 24; start++) {
    final a = near(start), b = near(start + period);
    if (a == null || b == null || !b.measuredAt.isAfter(a.measuredAt)) continue;
    result.add(
      StatureVelocityInterval(
        a,
        b,
        start.toDouble(),
        (start + period).toDouble(),
        row: reference?.rows.where((r) => r.start == start).firstOrNull,
      ),
    );
  }
  // Same-method observations outside the WHO domain are kept as recordings.
  for (var i = 0; i < sorted.length; i++) {
    final a = sorted[i];
    final start = growthChartAgeMonths(birth, a.measuredAt);
    if (start == null) continue;
    final b = sorted
        .skip(i + 1)
        .where(
          (p) =>
              p.method != null &&
              p.method == a.method &&
              ((growthChartAgeMonths(birth, p.measuredAt) ?? -100) -
                          start -
                          period)
                      .abs() <
                  .00001,
        )
        .firstOrNull;
    if (b == null || result.any((p) => p.from == a && p.to == b)) continue;
    final end = start + period;
    if (start >= 24 &&
        end <= 60 &&
        a.method == GrowthMeasurementMethod.standing) {
      result.add(StatureVelocityInterval(a, b, start, end));
    }
  }
  return result..sort((a, b) => a.to.measuredAt.compareTo(b.to.measuredAt));
}
