/// AI comments on a diary video (backend/app/features/diary_ai).
///
/// Observations and suggestions only — never a pass / fail score.
class VideoInsight {
  const VideoInsight({
    required this.id,
    required this.status,
    this.message,
    this.result,
    this.evidence = const [],
  });

  final String id;

  /// pending | running | done | rejected | failed
  final String status;

  /// Why the video was rejected / failed, shown to parents.
  final String? message;
  final InsightResult? result;

  /// Phase 2: MediaPipe measurements for motor activities.
  final List<EvidenceMetric> evidence;

  bool get finished => status != 'pending' && status != 'running';

  factory VideoInsight.fromJson(Map<String, dynamic> json) {
    final evidence = json['evidence'] as Map<String, dynamic>?;
    return VideoInsight(
      id: json['id'] as String,
      status: json['status'] as String,
      message: json['message'] as String?,
      result: json['result'] == null
          ? null
          : InsightResult.fromJson(json['result'] as Map<String, dynamic>),
      evidence: evidence == null || evidence['available'] != true
          ? const []
          : [
              for (final m in evidence['metrics'] as List? ?? [])
                EvidenceMetric.fromJson(m as Map<String, dynamic>),
            ],
    );
  }

  /// Shape stored in a DemoStore journal entry (`insight`).
  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status,
    if (message != null) 'message': message,
    if (result != null) 'result': result!.toJson(),
    if (evidence.isNotEmpty)
      'evidence': {
        'available': true,
        'metrics': [for (final m in evidence) m.toJson()],
      },
  };
}

class InsightResult {
  const InsightResult({
    required this.canAssess,
    this.videoIssue = '',
    this.observations = const [],
    this.comment = '',
    this.positives = const [],
    this.nextSteps = const [],
    this.seeSpecialist = false,
    this.specialistNote = '',
  });

  final bool canAssess;
  final String videoIssue, comment, specialistNote;
  final List<String> observations, positives, nextSteps;
  final bool seeSpecialist;

  static List<String> _strings(Object? value) => [
    for (final v in value as List? ?? const []) v.toString(),
  ];

  factory InsightResult.fromJson(Map<String, dynamic> json) => InsightResult(
    canAssess: json['canAssess'] as bool? ?? false,
    videoIssue: json['videoIssue'] as String? ?? '',
    observations: _strings(json['observations']),
    comment: json['comment'] as String? ?? '',
    positives: _strings(json['positives']),
    nextSteps: _strings(json['nextSteps']),
    seeSpecialist: json['seeSpecialist'] as bool? ?? false,
    specialistNote: json['specialistNote'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'canAssess': canAssess,
    'videoIssue': videoIssue,
    'observations': observations,
    'comment': comment,
    'positives': positives,
    'nextSteps': nextSteps,
    'seeSpecialist': seeSpecialist,
    'specialistNote': specialistNote,
  };
}

class EvidenceMetric {
  const EvidenceMetric(this.key, this.label, this.value, this.unit);
  final String key, label, unit;
  final double value;

  String get valueLabel =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  factory EvidenceMetric.fromJson(Map<String, dynamic> json) => EvidenceMetric(
    json['key'] as String,
    json['label'] as String,
    (json['value'] as num).toDouble(),
    json['unit'] as String,
  );

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'value': value,
    'unit': unit,
  };
}
