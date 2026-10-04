import 'assessment_domain.dart';

enum AssessmentStatus { good, needsWatching, concerning }

extension AssessmentStatusX on AssessmentStatus {
  String get label => switch (this) {
        AssessmentStatus.good => 'Bé đang phát triển tốt',
        AssessmentStatus.needsWatching => 'Cần theo dõi thêm',
        AssessmentStatus.concerning => 'Cần tư vấn chuyên gia',
      };
}

class DomainScore {
  final int achieved;
  final int total;
  const DomainScore({required this.achieved, required this.total});

  String get label => '$achieved/$total';
}

class AssessmentResult {
  final String id;
  final String childId;
  final DateTime date;
  final Map<AssessmentDomain, DomainScore> domainScores;
  final AssessmentStatus overallStatus;

  const AssessmentResult({
    required this.id,
    required this.childId,
    required this.date,
    required this.domainScores,
    required this.overallStatus,
  });

  int get totalAchieved => domainScores.values.fold(0, (a, b) => a + b.achieved);
  int get totalPossible => domainScores.values.fold(0, (a, b) => a + b.total);
}
