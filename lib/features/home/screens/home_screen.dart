import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/bottom_nav_bar.dart';
import '../../../core/widgets/card_container.dart';
import '../../../core/widgets/domain_progress_row.dart';
import '../../../core/widgets/empty_avatar.dart';
import '../../../core/widgets/section_header.dart';
import '../../../models/assessment_domain.dart';
import '../../../models/assessment_result.dart';
import '../../../models/child.dart';
import '../../../models/child_share.dart';
import '../../../services/active_child.dart';
import '../../../services/service_locator.dart';
import '../../sharing/screens/shared_with_me_screen.dart';
import '../widgets/ai_chat_fab.dart';
import '../widgets/ai_suggestion_card.dart';
import '../widgets/assessment_cta_card.dart';
import '../widgets/milestone_reminder_card.dart';
import '../widgets/upcoming_vaccine_card.dart';

/// Dashboard for the app-wide [ActiveChild] — an own child or one shared
/// with the current user. For a shared child, every card whose section the
/// owner didn't grant is hidden.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ActiveChildController _active = ServiceLocator.activeChild;
  List<Child> _children = const [];
  List<SharedChildAccess> _shared = const [];
  AssessmentResult? _result;

  @override
  void initState() {
    super.initState();
    _active.addListener(_onActiveChanged);
    _refreshChildren();
    ServiceLocator.assessmentService.getLatestResult('c1').then((r) {
      if (mounted) setState(() => _result = r);
    });
  }

  @override
  void dispose() {
    _active.removeListener(_onActiveChanged);
    super.dispose();
  }

  void _onActiveChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshChildren() async {
    final own = await ServiceLocator.childService.getChildren();
    final shared = (await ServiceLocator.sharingService.getSharedWithMe())
        .where((a) => a.status == ShareStatus.accepted)
        .toList();
    if (!mounted) return;
    setState(() {
      _children = own;
      _shared = shared;
    });

    // Keep the current selection while it's still reachable (refreshing a
    // shared child's permissions), otherwise fall back to the first child.
    final currentId = _active.value?.child.id;
    final ownMatch = own.where((c) => c.id == currentId).firstOrNull;
    final sharedMatch = shared.where((a) => a.child.id == currentId).firstOrNull;
    if (ownMatch != null) {
      _active.selectOwn(ownMatch);
    } else if (sharedMatch != null) {
      _active.selectShared(sharedMatch);
    } else if (own.isNotEmpty) {
      _active.selectOwn(own.first);
    } else if (shared.isNotEmpty) {
      _active.selectShared(shared.first);
    }
  }

  Future<void> _pickChild() async {
    final currentId = _active.value?.child.id;
    final picked = await showModalBottomSheet<ActiveChild>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Chọn bé để theo dõi'),
              const SizedBox(height: AppSpacing.sm),
              for (final c in _children)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: EmptyAvatar(label: c.name, size: 44),
                  title: Text(c.name, style: AppTextStyles.h3),
                  subtitle: Text(
                    '${c.ageLabel(DateTime.now())} · ${c.gender.label}',
                    style: AppTextStyles.caption,
                  ),
                  trailing: c.id == currentId
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, ActiveChild(c)),
                ),
              if (_shared.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('ĐƯỢC CHIA SẺ VỚI BẠN', style: AppTextStyles.captionBold),
                const SizedBox(height: AppSpacing.sm),
                for (final access in _shared) ...[
                  SharedChildTile(
                    access: access,
                    selected: access.child.id == currentId,
                    onTap: () => Navigator.pop(context, ActiveChild(access.child, sharedAccess: access)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final added = await context.push<bool>(
                    AppRoutes.childProfileNew,
                  );
                  if (added == true) await _refreshChildren();
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('+ Thêm hồ sơ bé mới'),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || picked.child.id == currentId) return;
    final access = picked.sharedAccess;
    access == null ? _active.selectOwn(picked.child) : _active.selectShared(access);
  }

  Future<void> _openProfile(ActiveChild active) async {
    final access = active.sharedAccess;
    if (access == null) {
      await context.push(AppRoutes.childProfile, extra: active.child.id);
    } else {
      // Info + "Rời khỏi hồ sơ" for a shared child live on its own screen.
      await context.push('${AppRoutes.sharedChildProfile}/${access.id}');
    }
    await _refreshChildren();
  }

  @override
  Widget build(BuildContext context) {
    final active = _active.value;
    final result = _result;
    return AppShellScaffold(
      tab: AppTab.home,
      appBar: AppBar(
        title: Text(
          'Xin chào, ${ServiceLocator.authService.currentUser.name}!',
        ),
        actions: [
          if (active != null && _children.length + _shared.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: InkWell(
                onTap: _pickChild,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                  decoration: BoxDecoration(
                    color: active.isOwner ? AppColors.surfaceGreen : AppColors.purpleSurface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: (active.isOwner ? AppColors.primary : AppColors.purple).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      EmptyAvatar(label: active.child.name, size: 22),
                      const SizedBox(width: 6),
                      Text(
                        active.child.name.split(' ').last,
                        style: AppTextStyles.captionBold.copyWith(
                          color: active.isOwner ? AppColors.primaryDark : AppColors.purpleHeading,
                        ),
                      ),
                      Icon(
                        Icons.expand_more_rounded,
                        size: 16,
                        color: active.isOwner ? AppColors.primaryDark : AppColors.purpleHeading,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => context.push(AppRoutes.notifications),
          ),
        ],
      ),
      body: active == null || result == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _cards(active, result),
                  ),
                ),
                Positioned(
                  top: 70,
                  right: 4,
                  child: AiChatFab(
                    onTap: () => context.push(AppRoutes.chatStub),
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _cards(ActiveChild active, AssessmentResult result) {
    final child = active.child;
    final canViewAssessment = active.canView(ShareSection.assessment);
    // Starting an assessment records a new result, so it needs edit rights.
    final canStartAssessment = active.canEdit(ShareSection.assessment);
    final canViewActivities = active.canView(ShareSection.activities);
    final canViewVaccination = active.canView(ShareSection.vaccination);
    final nothingVisible = !canViewAssessment && !canViewActivities && !canViewVaccination;

    return [
      _ChildHeaderCard(active: active, onTap: () => _openProfile(active)),
      const SizedBox(height: AppSpacing.lg),
      if (canStartAssessment) ...[
        AssessmentCtaCard(
          onStart: () => context.push(
            AppRoutes.assessmentQuestion,
            extra: AssessmentDomain.grossMotor,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      if (canViewAssessment) ...[
        CardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Tiến độ theo lĩnh vực'),
              const SizedBox(height: AppSpacing.sm),
              for (final entry in result.domainScores.entries)
                DomainProgressRow(
                  domain: entry.key,
                  achieved: entry.value.achieved,
                  total: entry.value.total,
                  statusLabel: entry.value.achieved == entry.value.total ||
                          entry.value.achieved >= entry.value.total - 1
                      ? 'Tạm ổn'
                      : 'Cần theo dõi',
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      if (canViewActivities) ...[
        AiSuggestionCard(
          onTap: () => context.push(AppRoutes.activityGroups),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      if (canViewVaccination)
        UpcomingVaccineCard(
          child: child,
          onTap: () => context.push(AppRoutes.vaccination, extra: child.id),
        ),
      if (canViewAssessment)
        MilestoneReminderCard(
          onTap: () => context.push(AppRoutes.notifications),
        ),
      if (nothingVisible)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Text(
            '${active.sharedAccess!.ownerLabel} chưa chia sẻ mục nào hiển thị ở Trang chủ. '
            'Bấm vào thẻ của bé để xem những gì bạn được xem.',
            style: AppTextStyles.bodySecondary,
            textAlign: TextAlign.center,
          ),
        ),
      const SizedBox(height: AppSpacing.lg),
    ];
  }
}

class _ChildHeaderCard extends StatelessWidget {
  const _ChildHeaderCard({required this.active, required this.onTap});

  final ActiveChild active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final child = active.child;
    final access = active.sharedAccess;
    return CardContainer(
      onTap: onTap,
      color: access == null ? AppColors.surfaceGreenLighter : AppColors.purpleSurfaceLight,
      borderColor: access == null ? AppColors.border : AppColors.purpleBorder,
      child: Row(
        children: [
          EmptyAvatar(
            label: child.name,
            size: 52,
            color: access == null ? AppColors.surfaceGreen : AppColors.purpleSurface,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(child.name, style: AppTextStyles.h3),
                const SizedBox(height: 2),
                Text(
                  '${child.ageLabel(DateTime.now())} · ${child.gender.label}',
                  style: AppTextStyles.caption,
                ),
                if (access != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Được chia sẻ bởi ${access.ownerLabel} · ${access.permissions.label}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.purpleHeading),
                  ),
                ],
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}
