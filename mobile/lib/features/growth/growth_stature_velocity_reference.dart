class GrowthStatureVelocityReference {
  const GrowthStatureVelocityReference(
    this.rows,
    this.sourceUrl,
    this.sexLabel,
  );
  final List<({int start, double low, double median, double high})> rows;
  final String sourceUrl, sexLabel;
  factory GrowthStatureVelocityReference.fromJson(
    Map<String, dynamic> json,
    String sex, {
    int maxAgeMonths = 24,
  }) {
    if (json['unit'] != 'cm' ||
        json['interval_months'] != 2 ||
        !['boys', 'girls'].contains(sex)) {
      throw const FormatException('Invalid length velocity reference');
    }
    final rows = (json['tables'][sex] as List);
    if (rows.length != maxAgeMonths - 1) {
      throw const FormatException('Incomplete length velocity reference');
    }
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i] as List;
      if (r.length != 4 ||
          r[0] != i ||
          !r.every((v) => v is num && v.isFinite) ||
          !(r[1] < r[2] && r[2] < r[3])) {
        throw const FormatException('Invalid length velocity interval');
      }
    }
    return GrowthStatureVelocityReference(
      [
        for (final r in rows)
          (
            start: (r[0] as num).toInt(),
            low: (r[1] as num).toDouble(),
            median: (r[2] as num).toDouble(),
            high: (r[3] as num).toDouble(),
          ),
      ],
      json['sources'][sex]['url'],
      sex == 'boys' ? 'Bé trai' : 'Bé gái',
    );
  }
}
