import '../services/who_bmi_for_age.dart';
import 'child.dart';
import 'growth_record.dart';

/// WHO BMI-for-age classification bands (docs/tieu_chuan_tham_khao.md § 1.3).
enum BmiCategory { severeWasting, wasting, normal, overweight, obese }

extension BmiCategoryX on BmiCategory {
  String get label => switch (this) {
        BmiCategory.severeWasting => 'Gầy còm nặng',
        BmiCategory.wasting => 'Gầy còm',
        BmiCategory.normal => 'Bình thường',
        BmiCategory.overweight => 'Thừa cân',
        BmiCategory.obese => 'Béo phì',
      };

  String get zScoreRange => switch (this) {
        BmiCategory.severeWasting => 'Z < -3',
        BmiCategory.wasting => '-3 đến -2',
        BmiCategory.normal => '-2 đến +2',
        BmiCategory.overweight => '+2 đến +3',
        BmiCategory.obese => 'Z > +3',
      };

  static BmiCategory fromZScore(double z) {
    if (z < -3) return BmiCategory.severeWasting;
    if (z < -2) return BmiCategory.wasting;
    if (z <= 2) return BmiCategory.normal;
    if (z <= 3) return BmiCategory.overweight;
    return BmiCategory.obese;
  }
}

/// BMI from one weight record and one height record.
/// [bmi] is null when the two measurement dates are too far apart for the
/// child's age — the pair is then not accurate enough to compute from.
/// [zScore]/[category] are null until the WHO LMS table has data for the
/// child's sex and age (see [WhoBmiForAge]).
class BmiResult {
  final GrowthRecord weight;
  final GrowthRecord height;
  final int ageMonths;
  final int dayGap;
  final int maxDayGap;
  final double? bmi;
  final double? zScore;

  const BmiResult._({
    required this.weight,
    required this.height,
    required this.ageMonths,
    required this.dayGap,
    required this.maxDayGap,
    required this.bmi,
    required this.zScore,
  });

  factory BmiResult.calculate({
    required GrowthRecord weight,
    required GrowthRecord height,
    required Child child,
  }) {
    final laterDate = weight.date.isAfter(height.date) ? weight.date : height.date;
    // WHO tables are indexed by completed months (average month length).
    final ageMonths = (laterDate.difference(child.dob).inDays / 30.4375).floor();
    final dayGap = weight.date.difference(height.date).inDays.abs();
    final maxDayGap = maxDayGapForAge(ageMonths);
    final heightM = height.value / 100;
    final bmi = dayGap <= maxDayGap && heightM > 0 ? weight.value / (heightM * heightM) : null;
    return BmiResult._(
      weight: weight,
      height: height,
      ageMonths: ageMonths,
      dayGap: dayGap,
      maxDayGap: maxDayGap,
      bmi: bmi,
      zScore: bmi == null ? null : WhoBmiForAge.zScore(bmi, child.gender, ageMonths),
    );
  }

  /// Pairs every weight record with the height record measured closest to it
  /// — used by the history list, where the parent doesn't pick the pair.
  static List<BmiResult> pairNearest({
    required List<GrowthRecord> weights,
    required List<GrowthRecord> heights,
    required Child child,
  }) {
    if (heights.isEmpty) return const [];
    return [
      for (final w in weights)
        BmiResult.calculate(
          weight: w,
          height: heights.reduce((a, b) =>
              a.date.difference(w.date).abs() <= b.date.difference(w.date).abs() ? a : b),
          child: child,
        ),
    ];
  }

  /// Children grow fast, so the younger the child the closer together the
  /// weight and height measurements must be.
  static int maxDayGapForAge(int ageMonths) {
    if (ageMonths < 6) return 3;
    if (ageMonths <= 24) return 7;
    return 30;
  }

  bool get isTooFarApart => bmi == null;

  BmiCategory? get category => zScore == null ? null : BmiCategoryX.fromZScore(zScore!);

  /// The later of the two measurement dates — the date the BMI applies to.
  DateTime get date => weight.date.isAfter(height.date) ? weight.date : height.date;
}
