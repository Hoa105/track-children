import '../models/assessment_domain.dart';
import '../models/assessment_result.dart';

abstract class AssessmentService {
  Future<AssessmentResult> getLatestResult(String childId);
  Future<List<AssessmentResult>> getHistory(String childId);
  Future<AssessmentResult> submitAnswers(String childId, Map<AssessmentDomain, int> answeredYes);
}

/// Seeded verbatim from prototype_reference.md's "Results per-domain
/// breakdown" and history copy (Vận động thô 6/6, Vận động tinh 6/7,
/// Ngôn ngữ 4/6, Xã hội 6/6).
class MockAssessmentService implements AssessmentService {
  AssessmentResult _buildLatest(String childId) => AssessmentResult(
        id: 'a-latest',
        childId: childId,
        date: DateTime(2026, 8, 17),
        domainScores: const {
          AssessmentDomain.grossMotor: DomainScore(achieved: 6, total: 6),
          AssessmentDomain.fineMotor: DomainScore(achieved: 6, total: 7),
          AssessmentDomain.language: DomainScore(achieved: 4, total: 6),
          AssessmentDomain.socialEmotional: DomainScore(achieved: 6, total: 6),
        },
        overallStatus: AssessmentStatus.needsWatching,
      );

  @override
  Future<AssessmentResult> getLatestResult(String childId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _buildLatest(childId);
  }

  @override
  Future<List<AssessmentResult>> getHistory(String childId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final latest = _buildLatest(childId);
    return [
      latest,
      AssessmentResult(
        id: 'a-2',
        childId: childId,
        date: DateTime(2026, 7, 18),
        domainScores: const {
          AssessmentDomain.grossMotor: DomainScore(achieved: 5, total: 6),
          AssessmentDomain.fineMotor: DomainScore(achieved: 5, total: 7),
          AssessmentDomain.language: DomainScore(achieved: 5, total: 6),
          AssessmentDomain.socialEmotional: DomainScore(achieved: 5, total: 6),
        },
        overallStatus: AssessmentStatus.good,
      ),
      AssessmentResult(
        id: 'a-3',
        childId: childId,
        date: DateTime(2026, 6, 18),
        domainScores: const {
          AssessmentDomain.grossMotor: DomainScore(achieved: 4, total: 6),
          AssessmentDomain.fineMotor: DomainScore(achieved: 4, total: 7),
          AssessmentDomain.language: DomainScore(achieved: 5, total: 6),
          AssessmentDomain.socialEmotional: DomainScore(achieved: 4, total: 6),
        },
        overallStatus: AssessmentStatus.good,
      ),
    ];
  }

  @override
  Future<AssessmentResult> submitAnswers(
      String childId, Map<AssessmentDomain, int> answeredYes) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _buildLatest(childId);
  }
}
