import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

/// WHO monthly BMI-for-age tables, 0–60 months. At 24 months use the
/// height-based (2–5 years) row rather than the length-based row.
class WhoBmiReference {
  WhoBmiReference(this.data);
  final Map<String, dynamic> data;
  static Future<WhoBmiReference> load() async => WhoBmiReference(
    jsonDecode(await rootBundle.loadString('assets/data/who_bmi.json'))
        as Map<String, dynamic>,
  );

  List<double>? row(String sex, int months) {
    if (months < 0 || months > 60 || !['boys', 'girls'].contains(sex)) {
      return null;
    }
    final matches = (data[sex] as List).where(
      (r) => (r as List).first == months,
    );
    return matches.isEmpty
        ? null
        : (matches.last as List).map((v) => (v as num).toDouble()).toList();
  }

  static int ageMonths(DateTime birth, DateTime measured) {
    var months =
        (measured.year - birth.year) * 12 + measured.month - birth.month;
    final last = DateTime(measured.year, measured.month + 1, 0).day;
    if (measured.day < math.min(birth.day, last)) months--;
    return months;
  }
}
