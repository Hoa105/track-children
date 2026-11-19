import '../../models/tooth.dart';

part 'teething_reference_stages.g.dart';

class TeethingReferenceStage {
  const TeethingReferenceStage({
    required this.id,
    required this.startMonth,
    required this.endMonth,
    required this.label,
    required this.count,
    required this.fdiCodes,
    required this.note,
    this.noteTitle,
  });

  final String id, label, note;
  final String? noteTitle;
  final int startMonth, endMonth, count;
  final Set<String> fdiCodes;
}

/// Stage-end illustrations from the approved JSON, never actual child records.
abstract final class TeethingReferenceData {
  static const stages = _referenceStages;
  static const countLabel = _referenceCountLabel;
  static const countUnit = _referenceCountUnit;
  static int clampMonth(int month) => month.clamp(0, 60);

  static TeethingReferenceStage stageForMonth(int month) {
    final safe = clampMonth(month);
    return stages.firstWhere(
      (stage) => safe >= stage.startMonth && safe <= stage.endMonth,
    );
  }

  static TeethingReferenceStage firstStageForTooth(PrimaryTooth tooth) =>
      stages.firstWhere((stage) => stage.fdiCodes.contains(tooth.fdiCode));

  static Set<int> pairCodesAt(int month) {
    final codes = stageForMonth(month).fdiCodes;
    return {
      for (final tooth in PrimaryTooth.all)
        if (codes.contains(tooth.fdiCode)) tooth.pairCode,
    };
  }

  static Set<String> toothIdsAt(int month) {
    final codes = stageForMonth(month).fdiCodes;
    return {
      for (final tooth in PrimaryTooth.all)
        if (codes.contains(tooth.fdiCode)) tooth.id,
    };
  }

  static int possibleTeethCountAt(int month) => stageForMonth(month).count;

  static List<PrimaryTooth> pair(int code) => PrimaryTooth.all
      .where((tooth) => tooth.pairCode == code)
      .toList(growable: false);
}
