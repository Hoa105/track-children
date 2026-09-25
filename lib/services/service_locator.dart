import 'activity_service.dart';
import 'ai_chat_service.dart';
import 'assessment_service.dart';
import 'auth_service.dart';
import 'child_service.dart';
import 'community_service.dart';
import 'growth_service.dart';
import 'journal_service.dart';
import 'teething_service.dart';
import 'vaccination_service.dart';

/// Simple manual service-locator (no DI package needed for this app's size).
abstract final class ServiceLocator {
  static final AuthService authService = MockAuthService();
  static final ChildService childService = MockChildService();
  static final GrowthService growthService = MockGrowthService();
  static final AssessmentService assessmentService = MockAssessmentService();
  static final ActivityService activityService = MockActivityService();
  static final JournalService journalService = MockJournalService();
  static final AIChatService aiChatService = MockAIChatService();
  static final CommunityService communityService = MockCommunityService();
  static final VaccinationService vaccinationService = MockVaccinationService();
  static final TeethingService teethingService = MockTeethingService();
}
