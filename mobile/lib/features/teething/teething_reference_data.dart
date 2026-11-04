import '../../models/tooth.dart';

/// Reference schedule transcribed from docs/teeth/LICH-MOC-RANG-SUA-THAM-KHAO.md
/// and its 0–60 month CSV. A pair is highlighted from the first month of its
/// ADA reference window; this is guidance, never an observed eruption state.
abstract final class TeethingReferenceData {
  static int clampMonth(int month) => month.clamp(0, 60);

  static Set<int> pairCodesAt(int month) {
    final safeMonth = clampMonth(month);
    return {
      for (final tooth in PrimaryTooth.all)
        if (tooth.eruptionMonths.$1 <= safeMonth) tooth.pairCode,
    };
  }

  static Set<String> toothIdsAt(int month) => {
    for (final tooth in PrimaryTooth.all)
      if (tooth.eruptionMonths.$1 <= clampMonth(month)) tooth.id,
  };

  static int possibleTeethCountAt(int month) => pairCodesAt(month).length * 2;

  static List<PrimaryTooth> pair(int code) => PrimaryTooth.all
      .where((tooth) => tooth.pairCode == code)
      .toList(growable: false);
}
