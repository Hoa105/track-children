import 'growth_models.dart';

class GrowthWeightVelocityPoint {
  const GrowthWeightVelocityPoint(
    this.startMonth,
    this.grams,
    this.from,
    this.to, {
    this.intervalMonths = 1,
    this.startAgeMonths,
    this.endAgeMonths,
    this.referenceStatus = 'REFERENCE_MATCHED',
    this.referenceReason,
    this.zScore,
    this.id,
    this.serverLabel,
    this.fromKg,
    this.toKg,
    this.elapsedDays,
    this.explanation,
    this.advice = const [],
    this.referenceValues = const {},
  });
  final int startMonth;
  final int intervalMonths;
  final String referenceStatus;
  final String? referenceReason, id;
  final String? serverLabel;
  final double? fromKg, toKg;
  final int? elapsedDays;
  final String? explanation;
  final List<String> advice;
  final Map<int, double> referenceValues;
  final double? zScore;
  bool get hasWhoReference => referenceStatus == 'REFERENCE_MATCHED';
  final double? startAgeMonths, endAgeMonths;
  double get startAge => startAgeMonths ?? startMonth.toDouble();
  double get endAge => endAgeMonths ?? (startMonth + intervalMonths).toDouble();
  double get midpointAge => (startAge + endAge) / 2;
  String get intervalLabel =>
      serverLabel ??
      (intervalMonths == 1 && startMonth == 0
          ? '0–4 tuần'
          : intervalMonths == 1 && startMonth == 1
          ? '4 tuần–2 tháng'
          : '$startMonth–${startMonth + intervalMonths} tháng');
  final double grams;
  final DateTime from, to;
}

/// Match both endpoints independently; intervening readings never break a pair.
/// Monthly WHO starts with birth--28 days and 28 days--2 calendar months.
List<GrowthWeightVelocityPoint> growthWeightMonthlyIncrements(
  List<GrowthMeasurementDraft> readings,
  DateTime? birth,
) => growthWeightPeriodIncrements(readings, birth, 1);

List<GrowthWeightVelocityPoint> growthWeightPeriodIncrements(
  List<GrowthMeasurementDraft> readings,
  DateTime? birth,
  int period,
) {
  if (birth == null) return const [];
  if (![1, 2, 3, 4, 6].contains(period)) {
    throw ArgumentError.value(
      period,
      'period',
      'Unsupported WHO weight period',
    );
  }
  DateTime day(DateTime date) => DateTime.utc(date.year, date.month, date.day);
  final origin = day(birth);
  DateTime anchor(int months) {
    final last = DateTime.utc(origin.year, origin.month + months + 1, 0).day;
    return DateTime.utc(
      origin.year,
      origin.month + months,
      origin.day > last ? last : origin.day,
    );
  }

  final unique = <DateTime, GrowthMeasurementDraft>{};
  for (final reading in readings) {
    if (reading.value.isFinite && reading.value > 0)
      unique[day(reading.measuredAt)] = reading;
  }
  final points = <GrowthWeightVelocityPoint>[];
  final limit = period == 1 ? 12 : 24;
  for (var start = 0; start + period <= limit; start++) {
    final from = period == 1 && start == 1
        ? origin.add(const Duration(days: 28))
        : anchor(start);
    final to = period == 1 && start == 0
        ? origin.add(const Duration(days: 28))
        : anchor(start + period);
    final a = unique[from], b = unique[to];
    if (a == null || b == null) continue;
    points.add(
      GrowthWeightVelocityPoint(
        start,
        (b.value - a.value) * 1000,
        a.measuredAt,
        b.measuredAt,
        fromKg: a.value,
        toKg: b.value,
        elapsedDays: to.difference(from).inDays,
        intervalMonths: period,
        startAgeMonths: period == 1 && start == 1
            ? 28 / (anchor(1).difference(origin).inDays)
            : start.toDouble(),
        endAgeMonths: period == 1 && start == 0
            ? 28 / (anchor(1).difference(origin).inDays)
            : (start + period).toDouble(),
      ),
    );
  }
  return points;
}

class GrowthWeightVelocityReference {
  const GrowthWeightVelocityReference(
    this.rows,
    this.sourceUrl, {
    this.explicitBands,
    this.standardValues = const {},
  });
  final Map<double, Map<int, double>> standardValues;
  final List<
    ({double start, double end, double low, double median, double high})
  >?
  explicitBands;
  factory GrowthWeightVelocityReference.fromIntervals(
    List<Map<String, dynamic>> intervals,
    DateTime? birth,
  ) {
    double age(num value, String unit) {
      if (unit == 'wks') return value * 7 / 30.4375;
      if (birth == null) return value.toDouble();
      final last = DateTime.utc(
        birth.year,
        birth.month + value.toInt() + 1,
        0,
      ).day;
      final end = DateTime.utc(
        birth.year,
        birth.month + value.toInt(),
        birth.day > last ? last : birth.day,
      );
      return end
              .difference(DateTime.utc(birth.year, birth.month, birth.day))
              .inDays /
          30.4375;
    }

    final bands =
        <
          ({double start, double end, double low, double median, double high})
        >[];
    final standards = <double, Map<int, double>>{};
    for (final row in intervals) {
      if (row['unit'] != 'g')
        throw const FormatException('Invalid velocity unit');
      final values = row['sdValues'] as List;
      double sd(int k) =>
          (values.singleWhere((v) => v['sd'] == k)['value'] as num).toDouble();
      final low = sd(-2), median = sd(0), high = sd(2);
      if (![low, median, high].every((v) => v.isFinite) ||
          !(low < median && median < high))
        throw const FormatException('Invalid SD bounds');
      bands.add((
        start: age(row['start'] as num, row['startUnit'] as String),
        end: age(row['end'] as num, row['endUnit'] as String),
        low: low,
        median: median,
        high: high,
      ));
      final band = bands.last;
      standards[(band.start + band.end) / 2] = {
        for (final value in values)
          (value['sd'] as num).toInt(): (value['value'] as num).toDouble(),
      };
    }
    return GrowthWeightVelocityReference(
      const [],
      'https://www.who.int/tools/child-growth-standards/standards/weight-velocity',
      explicitBands: List.unmodifiable(bands),
      standardValues: standards,
    );
  }
  final List<({String label, double low, double median, double high})> rows;
  final String sourceUrl;

  /// Each row is an interval-specific increment distribution, not a value to
  /// interpolate between interval midpoints. Clip only its horizontal extent.
  List<({double start, double end, double low, double median, double high})>
  bands(double minAge, double maxAge, double? fourWeeksAge) {
    final bands =
        <
          ({double start, double end, double low, double median, double high})
        >[];
    if (explicitBands != null) {
      return [
        for (final band in explicitBands!)
          if ((band.start + band.end) / 2 >= minAge &&
              (band.start + band.end) / 2 <= maxAge)
            (
              start: band.start,
              end: band.end,
              low: band.low,
              median: band.median,
              high: band.high,
            ),
      ];
    }
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
          median: rows[i].median,
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
