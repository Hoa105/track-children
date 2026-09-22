import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/bottom_nav_bar.dart';
import '../../../core/widgets/card_container.dart';
import '../../../models/activity_group.dart';
import '../../../services/service_locator.dart';

class ActivityGroupsScreen extends StatefulWidget {
  const ActivityGroupsScreen({super.key});

  @override
  State<ActivityGroupsScreen> createState() => _ActivityGroupsScreenState();
}

class _ActivityGroupsScreenState extends State<ActivityGroupsScreen> {
  List<ActivityGroup>? _groups;

  @override
  void initState() {
    super.initState();
    ServiceLocator.activityService.getGroups().then((g) => setState(() => _groups = g));
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    return AppShellScaffold(
      tab: AppTab.activities,
      appBar: AppBar(
        title: const Text('Hoạt động'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border_rounded),
            tooltip: 'Hoạt động yêu thích',
            onPressed: () => context.push(AppRoutes.activityFavorites),
          ),
        ],
      ),
      body: groups == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) {
                final group = groups[i];
                return CardContainer(
                  onTap: () => context.push('${AppRoutes.activityGroupDetail}/${group.id}'),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: group.tint, borderRadius: AppRadius.smallRadius),
                        alignment: Alignment.center,
                        child: Text(group.emoji, style: const TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(group.name, style: AppTextStyles.titleMedium),
                            const SizedBox(height: 2),
                            Text(group.description, style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceGreen,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('${group.items.length}',
                            style: AppTextStyles.caption.copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
