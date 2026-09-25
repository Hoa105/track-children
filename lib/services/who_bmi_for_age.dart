import 'dart:math' as math;

import '../models/child.dart';

typedef Lms = ({double l, double m, double s});

/// WHO Child Growth Standards — BMI-for-age LMS coefficients, 0–60 months
/// (docs/tieu_chuan_tham_khao.md § 1.2).
///
/// TODO: fill [boys] and [girls] from the WHO tables "bfa-boys-0-5-zscores"
/// and "bfa-girls-0-5-zscores" (columns Month, L, M, S). Key = age in
/// completed months, e.g. `18: (l: <L>, m: <M>, s: <S>)` copied from the
/// row "Month 18" of the WHO table.
/// Until then [zScore] returns null and the UI shows "Chưa phân loại".
abstract final class WhoBmiForAge {
  static const Map<int, Lms> boys = {};
  static const Map<int, Lms> girls = {};

  static Lms? lmsFor(ChildGender gender, int ageMonths) =>
      (gender == ChildGender.boy ? boys : girls)[ageMonths];

  /// Z = ((value / M)^L - 1) / (L * S), or ln(value / M) / S when L = 0.
  static double? zScore(double bmi, ChildGender gender, int ageMonths) {
    final lms = lmsFor(gender, ageMonths);
    if (lms == null) return null;
    if (lms.l == 0) return math.log(bmi / lms.m) / lms.s;
    return (math.pow(bmi / lms.m, lms.l) - 1) / (lms.l * lms.s);
  }
}
