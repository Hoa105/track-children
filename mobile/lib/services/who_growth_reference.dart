import 'dart:convert';

import 'package:flutter/services.dart';

import 'who_bmi_reference.dart';

class WhoGrowthReference {
  WhoGrowthReference(this.data);
  final Map<String, dynamic> data;
  static Future<WhoGrowthReference> load() async => WhoGrowthReference(
    jsonDecode(await rootBundle.loadString('assets/data/who_growth.json'))
        as Map<String, dynamic>,
  );

  /// Linear interpolation of WHO's rounded monthly thresholds for display.
  /// At 24 months length/BMI switch to standing-height references.
  List<double>? at(String metric, String sex, DateTime birth, DateTime date) {
    final months = WhoBmiReference.ageMonths(birth, date);
    if (date.isBefore(birth) || months < 0 || months > 60) return null;
    DateTime anchor(int m) {
      final first = DateTime(birth.year, birth.month + m);
      final last = DateTime(first.year, first.month + 1, 0).day;
      return DateTime(first.year, first.month, birth.day.clamp(1, last));
    }

    if (date.isAfter(anchor(60))) return null;
    final rows = ((data[metric] as Map)[sex] as List).cast<List>();
    final current = rows.where((r) => r[0] == months).last;
    if (months == 60) {
      return current.skip(1).map((v) => (v as num).toDouble()).toList();
    }
    final next = rows.where((r) => r[0] == months + 1).first;
    final fraction =
        date.difference(anchor(months)).inMilliseconds /
        anchor(months + 1).difference(anchor(months)).inMilliseconds;
    return List.generate(
      3,
      (i) =>
          (current[i + 1] as num).toDouble() +
          ((next[i + 1] as num) - (current[i + 1] as num)) * fraction,
    );
  }
}
