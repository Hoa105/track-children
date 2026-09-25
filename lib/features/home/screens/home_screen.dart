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
import '../../../services/service_locator.dart';
import '../widgets/ai_chat_fab.dart';
import '../widgets/ai_suggestion_card.dart';
import '../widgets/assessment_cta_card.dart';
import '../widgets/milestone_reminder_card.dart';
import '../widgets/upcoming_vaccine_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Child> _children = const [];
  Child? _child;
  AssessmentResult? _result;

  @override
  void initState() {
    super.initState();
    _refreshChildren();
    ServiceLocator.assessmentService.getLatestResult('c1').then((r) {
      setState(() => _result = r);
    });
  }

  Future<void> _refreshChildren() async {
    final c = await ServiceLocator.childService.getChildren();
    if (!mounted || c.isEmpty) return;
    setState(() {
      _children = c;
      // Keep the currently-selected child if it still exists, otherwise
      // fall back to the first one — relevant right after adding a new
      // child from the picker sheet.
      _child = c.firstWhere((x) => x.id == _child?.id, orElse: () => c.first);
    });
  }

  Future<void> _pickChild() async {
    final picked = await showModalBottomSheet<Child>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
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
                  trailing: c.id == _child?.id
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, c),
                ),
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
    if (picked != null && picked.id != _child?.id) {
      setState(() => _child = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = _child;
    final result = _result;
    return AppShellScaffold(
      tab: AppTab.home,
      appBar: AppBar(
        title: Text(
          'Xin chào, ${ServiceLocator.authService.currentUser.name}!',
        ),
        actions: [
          if (child != null && _children.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: InkWell(
                onTap: _pickChild,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGreen,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      EmptyAvatar(label: child.name, size: 22),
                      const SizedBox(width: 6),
                      Text(
                        child.name.split(' ').last,
                        style: AppTextStyles.captionBold.copyWith(
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const Icon(
                        Icons.expand_more_rounded,
                        size: 16,
                        color: AppColors.primaryDark,
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
      body: child == null || result == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CardContainer(
                        onTap: () => context.push(AppRoutes.childProfile),
                        color: AppColors.surfaceGreenLighter,
                        borderColor: AppColors.border,
                        child: Row(
                          children: [
                            EmptyAvatar(label: child.name, size: 52),
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
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AssessmentCtaCard(
                        onStart: () => context.push(
                          AppRoutes.assessmentQuestion,
                          extra: AssessmentDomain.grossMotor,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
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
                                statusLabel:
                                    entry.value.achieved == entry.value.total ||
                                        entry.value.achieved >=
                                            entry.value.total - 1
                                    ? 'Tạm ổn'
                                    : 'Cần theo dõi',
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AiSuggestionCard(
                        onTap: () => context.push(AppRoutes.activityGroups),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      UpcomingVaccineCard(
                        child: child,
                        onTap: () => context.push(AppRoutes.vaccination, extra: child.id),
                      ),
                      MilestoneReminderCard(
                        onTap: () => context.push(AppRoutes.notifications),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
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
}
