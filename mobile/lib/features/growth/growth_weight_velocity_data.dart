import 'growth_models.dart';

class GrowthWeightVelocityPoint {
  const GrowthWeightVelocityPoint(
    this.startMonth,
    this.grams,
    this.from,
    this.to,
  );
  final int startMonth;
  final double grams;
  final DateTime from, to;
}

/// Exact calendar-month pairs at birthday month anchors only. No normalization
/// of irregular intervals; the special WHO 0–4wk and 4wk–2mo rows are excluded.
List<GrowthWeightVelocityPoint> growthWeightMonthlyIncrements(
  List<GrowthMeasurementDraft> readings,
  DateTime? birth,
) {
  if (birth == null) return const [];
  final unique = <DateTime, GrowthMeasurementDraft>{};
  for (final reading in readings) {
    if (reading.value.isFinite && reading.value > 0) {
      unique[DateTime(
            reading.measuredAt.year,
            reading.measuredAt.month,
            reading.measuredAt.day,
          )] =
          reading;
    }
  }
  final dates = unique.keys.toList()..sort();
  final points = <GrowthWeightVelocityPoint>[];
  for (var i = 1; i < dates.length; i++) {
    final a = growthChartAgeMonths(birth, dates[i - 1]);
    final b = growthChartAgeMonths(birth, dates[i]);
    if (a == null ||
        b == null ||
        a < 2 ||
        b > 12 ||
        a != a.roundToDouble() ||
        b != a + 1) {
      continue;
    }
    points.add(
      GrowthWeightVelocityPoint(
        a.toInt(),
        (unique[dates[i]]!.value - unique[dates[i - 1]]!.value) * 1000,
        dates[i - 1],
        dates[i],
      ),
    );
  }
  return points;
}

class GrowthWeightVelocityReference {
  const GrowthWeightVelocityReference(this.rows, this.sourceUrl);
  final List<({String label, double low, double median, double high})> rows;
  final String sourceUrl;

  /// Each row is an interval-specific increment distribution, not a value to
  /// interpolate between interval midpoints. Clip only its horizontal extent.
  List<({double start, double end, double low, double high})> bands(
    double minAge,
    double maxAge,
    double? fourWeeksAge,
  ) {
    final bands = <({double start, double end, double low, double high})>[];
    for (var i = 0; i < rows.length; i++) {
      if (i < 2 && fourWeeksAge == null) continue;
      final start = i == 0
          ? 0.0
          : i == 1
          ? fourWeeksAge!
          : i.toDouble();
      final end = i == 0 ? fourWeeksAge! : i + 1.0;
      final left = start < minAge ? minAge : start;
      final right = end > maxAge ? maxAge : end;
      if (left < right) {
        bands.add((
          start: left,
          end: right,
          low: rows[i].low,
          high: rows[i].high,
        ));
      }
    }
    return bands;
  }

  factory GrowthWeightVelocityReference.fromJson(
    Map<String, dynamic> json,
    GrowthReferenceSex sex,
  ) {
    if (json['unit'] != 'g' || json['interval_months'] != 1) {
      throw const FormatException('Invalid velocity units/interval');
    }
    final data = (json['tables'] as Map)[sex.name] as List;
    if (data.length != 12) {
      throw const FormatException('Incomplete monthly velocity table');
    }
    final rows = <({String label, double low, double median, double high})>[];
    for (var i = 0; i < data.length; i++) {
      final r = data[i] as List;
      if (r.length != 5 || r[0] != i) {
        throw const FormatException('Invalid velocity row');
      }
      final low = (r[2] as num).toDouble(),
          median = (r[3] as num).toDouble(),
          high = (r[4] as num).toDouble();
      if (![low, median, high].every((v) => v.isFinite) ||
          !(low < median && median < high)) {
        throw const FormatException('Invalid velocity bounds');
      }
      rows.add((label: r[1] as String, low: low, median: median, high: high));
    }
    return GrowthWeightVelocityReference(
      List.unmodifiable(rows),
      ((json['sources'] as Map)[sex.name] as Map)['url'] as String,
    );
  }
}
