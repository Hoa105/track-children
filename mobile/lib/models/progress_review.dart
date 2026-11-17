/// AI summary across several analysed diary videos of one activity
/// (backend/app/features/diary_ai, POST /diary/progress-reviews).
///
/// Describes changes over time — never a pass / fail score.
class ProgressReview {
  const ProgressReview({
    required this.id,
    required this.activityTitle,
    required this.insightIds,
    required this.periodFrom,
    required this.periodTo,
    required this.createdAt,
    required this.summary,
    this.activityRef,
    this.activities = const [],
    this.skillsDone = const [],
    this.skillsImproving = const [],
    this.stage = '',
    this.progress = const [],
    this.independence = '',
    this.pace = '',
    this.strengths = const [],
    this.challenges = const [],
    this.keepPracticing = const [],
    this.repeatedPatterns = const [],
    this.notYetSeen = const [],
    this.behaviorChanges = const [],
    this.seeSpecialist = false,
    this.specialistNote = '',
    this.nextSteps = const [],
    this.prioritySkills = const [],
    this.parentTips = const [],
    this.nextRecording = '',
    this.metrics = const [],
  });

  final String id;

  /// Activity id of the videos; null when several activities of one group.
  final String? activityRef;
  final String activityTitle;
  final List<String> insightIds;
  final DateTime periodFrom, periodTo, createdAt;
  final String summary, specialistNote;
  final bool seeSpecialist;

  // 1. Tổng quan
  final List<String> activities, skillsDone, skillsImproving;
  final String stage;
  // 2. Tiến bộ theo thời gian
  final List<String> progress;
  final String independence, pace;
  // 3. Điểm mạnh và kỹ năng cần hỗ trợ
  final List<String> strengths, challenges, keepPracticing;
  // 4. Dấu hiệu cần chú ý (+ seeSpecialist / specialistNote)
  final List<String> repeatedPatterns, notYetSeen, behaviorChanges;
  // 5. Kế hoạch chăm sóc và luyện tập
  final List<String> nextSteps, prioritySkills, parentTips;
  final String nextRecording;

  /// MediaPipe measurements per video, oldest first (motor activities only).
  final List<MetricTrend> metrics;

  static List<String> _strings(Object? value) => [
    for (final v in value as List? ?? const []) v.toString(),
  ];

  factory ProgressReview.fromJson(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>? ?? const {};
    return ProgressReview(
      id: json['id'] as String,
      activityRef: json['activityRef'] as String?,
      activityTitle: json['activityTitle'] as String? ?? '',
      insightIds: _strings(json['insightIds']),
      periodFrom: DateTime.parse(json['periodFrom'] as String).toLocal(),
      periodTo: DateTime.parse(json['periodTo'] as String).toLocal(),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      summary: result['summary'] as String? ?? '',
      activities: _strings(result['activities']),
      skillsDone: _strings(result['skillsDone']),
      skillsImproving: _strings(result['skillsImproving']),
      stage: result['stage'] as String? ?? '',
      progress: _strings(result['progress']),
      independence: result['independence'] as String? ?? '',
      pace: result['pace'] as String? ?? '',
      strengths: _strings(result['strengths']),
      challenges: _strings(result['challenges']),
      keepPracticing: _strings(result['keepPracticing']),
      repeatedPatterns: _strings(result['repeatedPatterns']),
      notYetSeen: _strings(result['notYetSeen']),
      behaviorChanges: _strings(result['behaviorChanges']),
      seeSpecialist: result['seeSpecialist'] as bool? ?? false,
      specialistNote: result['specialistNote'] as String? ?? '',
      nextSteps: _strings(result['nextSteps']),
      prioritySkills: _strings(result['prioritySkills']),
      parentTips: _strings(result['parentTips']),
      nextRecording: result['nextRecording'] as String? ?? '',
      metrics: [
        for (final m in json['metrics'] as List? ?? const [])
          MetricTrend.fromJson(m as Map<String, dynamic>),
      ],
    );
  }
}

class MetricTrend {
  const MetricTrend({
    required this.key,
    required this.label,
    required this.unit,
    required this.points,
    this.change,
  });

  final String key, label, unit;
  final List<MetricPoint> points;

  /// Last value − first value; null with a single measurement.
  final double? change;

  factory MetricTrend.fromJson(Map<String, dynamic> json) => MetricTrend(
    key: json['key'] as String,
    label: json['label'] as String,
    unit: json['unit'] as String,
    change: (json['change'] as num?)?.toDouble(),
    points: [
      for (final p in json['points'] as List? ?? const [])
        MetricPoint(
          DateTime.parse((p as Map)['at'] as String).toLocal(),
          (p['value'] as num).toDouble(),
        ),
    ],
  );
}

class MetricPoint {
  const MetricPoint(this.at, this.value);
  final DateTime at;
  final double value;
}
