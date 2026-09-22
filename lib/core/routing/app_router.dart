import 'package:go_router/go_router.dart';
import '../../features/activities/screens/activity_detail_screen.dart';
import '../../features/activities/screens/activity_favorites_screen.dart';
import '../../features/activities/screens/activity_group_detail_screen.dart';
import '../../features/activities/screens/activity_groups_screen.dart';
import '../../features/assessment/screens/assessment_question_screen.dart';
import '../../features/assessment/screens/assessment_result_screen.dart';
import '../../features/assessment/screens/history_screen.dart';
import '../../features/auth/screens/child_picker_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/child/screens/child_profile_screen.dart';
import '../../features/companion/screens/chat_stub_screen.dart';
import '../../features/companion/screens/community_create_post_screen.dart';
import '../../features/companion/screens/companion_saved_screen.dart';
import '../../features/companion/screens/companion_screen.dart';
import '../../features/growth/screens/growth_history_screen.dart';
import '../../features/growth/screens/growth_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/journal/screens/journal_add_screen.dart';
import '../../features/journal/screens/journal_detail_screen.dart';
import '../../features/journal/screens/journal_screen.dart';
import '../../features/more/screens/more_hub_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/settings/screens/account_settings_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/splash/screens/splash_screen.dart';
import '../../models/assessment_domain.dart';
import '../../models/growth_record.dart';
import 'app_routes.dart';

/// Wires every route in prototype_reference.md's navigation graph. The 5
/// bottom-nav screens (home/growth/activityGroups/journal/moreHub) each
/// build their own [AppShellScaffold] rather than using go_router's
/// StatefulShellRoute — simpler for this app's size while still keeping the
/// nav bar visually persistent, at the cost of not preserving each tab's
/// scroll offset across tab switches (an acceptable trade-off called out
/// in the task's own "don't over-engineer" guidance).
final appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
    GoRoute(path: AppRoutes.onboarding, builder: (context, state) => const OnboardingScreen()),
    GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
    GoRoute(path: AppRoutes.childPicker, builder: (context, state) => const ChildPickerScreen()),
    GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeScreen()),
    GoRoute(path: AppRoutes.childProfile, builder: (context, state) => const ChildProfileScreen()),
    GoRoute(path: AppRoutes.childProfileNew, builder: (context, state) => const ChildProfileScreen(isNew: true)),
    GoRoute(path: AppRoutes.growth, builder: (context, state) => const GrowthScreen()),
    GoRoute(
      path: AppRoutes.growthHistory,
      builder: (context, state) => GrowthHistoryScreen(
        initialType: state.extra is GrowthMetricType ? state.extra as GrowthMetricType : GrowthMetricType.weight,
      ),
    ),
    GoRoute(
      path: AppRoutes.assessmentQuestion,
      builder: (context, state) => AssessmentQuestionScreen(
        startDomain: state.extra is AssessmentDomain
            ? state.extra as AssessmentDomain
            : AssessmentDomain.grossMotor,
      ),
    ),
    GoRoute(path: AppRoutes.assessmentResult, builder: (context, state) => const AssessmentResultScreen()),
    GoRoute(path: AppRoutes.history, builder: (context, state) => const HistoryScreen()),
    GoRoute(path: AppRoutes.activityGroups, builder: (context, state) => const ActivityGroupsScreen()),
    GoRoute(
      path: '${AppRoutes.activityGroupDetail}/:groupId',
      builder: (context, state) => ActivityGroupDetailScreen(groupId: state.pathParameters['groupId']!),
    ),
    GoRoute(
      path: '${AppRoutes.activityDetail}/:activityId',
      builder: (context, state) => ActivityDetailScreen(activityId: state.pathParameters['activityId']!),
    ),
    GoRoute(path: AppRoutes.activityFavorites, builder: (context, state) => const ActivityFavoritesScreen()),
    GoRoute(path: AppRoutes.journal, builder: (context, state) => const JournalScreen()),
    GoRoute(path: AppRoutes.journalAdd, builder: (context, state) => const JournalAddScreen()),
    GoRoute(
      path: '${AppRoutes.journalDetail}/:entryId',
      builder: (context, state) => JournalDetailScreen(entryId: state.pathParameters['entryId']!),
    ),
    GoRoute(path: AppRoutes.companion, builder: (context, state) => const CompanionScreen()),
    GoRoute(path: AppRoutes.companionSaved, builder: (context, state) => const CompanionSavedScreen()),
    GoRoute(path: AppRoutes.chatStub, builder: (context, state) => const ChatStubScreen()),
    GoRoute(path: AppRoutes.communityCreatePost, builder: (context, state) => const CommunityCreatePostScreen()),
    GoRoute(path: AppRoutes.notifications, builder: (context, state) => const NotificationsScreen()),
    GoRoute(path: AppRoutes.settings, builder: (context, state) => const SettingsScreen()),
    GoRoute(path: AppRoutes.accountSettings, builder: (context, state) => const AccountSettingsScreen()),
    GoRoute(path: AppRoutes.moreHub, builder: (context, state) => const MoreHubScreen()),
  ],
);
