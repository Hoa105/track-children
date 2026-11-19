part 'teething_knowledge_rules.g.dart';

/// Educational content shown on demand, not an automatically triggered alert.
class TeethingKnowledgeRule {
  const TeethingKnowledgeRule({
    required this.id,
    required this.title,
    required this.text,
    this.minMonth = 0,
    this.maxMonth = 60,
    this.knowledgeGroup,
    this.displayMode = 'guide',
    this.priority = 0,
  });

  final String id, title, text;
  final int minMonth, maxMonth;
  final String? knowledgeGroup;
  final String displayMode;
  final int priority;

  String? get ageLabel {
    if (minMonth == 0 && maxMonth == 60) return null;
    if (maxMonth == 60) return 'Từ $minMonth tháng';
    return '$minMonth–$maxMonth tháng';
  }
}

abstract final class TeethingKnowledgeData {
  static const careTitle = _careTitle;
  static const safetyTitle = _safetyTitle;
  static const careRules = _careRules;
  static const safetyRules = _safetyRules;

  static List<TeethingKnowledgeRule> careForAge(int ageMonths) =>
      _forAge(careRules, ageMonths);

  static List<TeethingKnowledgeRule> safetyForAge(int ageMonths) =>
      _forAge(safetyRules, ageMonths);

  static List<TeethingKnowledgeRule> _forAge(
    List<TeethingKnowledgeRule> rules,
    int ageMonths,
  ) {
    final month = ageMonths.clamp(0, 60);
    final groups = <String, TeethingKnowledgeRule>{};
    for (final rule in rules) {
      if (month < rule.minMonth || month > rule.maxMonth) continue;
      final key = rule.knowledgeGroup ?? rule.id;
      final previous = groups[key];
      // Prefer the complete on-demand guide over an event reminder with the
      // same topic. Preserve every original event rule in the source JSON.
      if (previous == null ||
          (rule.displayMode == 'guide' && previous.displayMode != 'guide') ||
          (rule.displayMode == previous.displayMode &&
              rule.priority > previous.priority)) {
        groups[key] = rule;
      }
    }
    return groups.values.toList(growable: false);
  }

  static const generalRules = <TeethingKnowledgeRule>[
    TeethingKnowledgeRule(
      id: 'GENERAL_SIGNS',
      title: 'Dấu hiệu mọc răng là gì?',
      text: 'Bé có thể chảy nhiều nước dãi, quấy hoặc khó ngủ khi mọc răng.',
    ),
    TeethingKnowledgeRule(
      id: 'GENERAL_TIMING',
      title: 'Khi nào bé bắt đầu mọc răng?',
      text: 'Răng sữa thường bắt đầu mọc trong khoảng 6–12 tháng. Thời điểm mọc khác nhau ở mỗi bé; các mốc trên sơ đồ chỉ mang tính tham khảo.',
    ),
    TeethingKnowledgeRule(
      id: 'GENERAL_DOCTOR',
      title: 'Khi nào cần liên hệ bác sĩ?',
      text: 'Nếu bé sốt hoặc tiêu chảy, hãy liên hệ bác sĩ; không mặc định do mọc răng.',
    ),
  ];
}
