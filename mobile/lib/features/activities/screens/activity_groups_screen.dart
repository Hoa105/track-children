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
import '../../../models/child_share.dart';
import '../../../services/active_child.dart';
import '../../../services/service_locator.dart';
import '../widgets/active_child_banner.dart';

class ActivityGroupsScreen extends StatefulWidget {
  const ActivityGroupsScreen({super.key});

  @override
  State<ActivityGroupsScreen> createState() => _ActivityGroupsScreenState();
}

class _ActivityGroupsScreenState extends State<ActivityGroupsScreen> {
  final ActiveChildController _active = ServiceLocator.activeChild;
  List<ActivityGroup>? _groups;

  @override
  void initState() {
    super.initState();
    _active.addListener(_onActiveChanged);
    _active.ensure().then((_) => _load());
  }

  @override
  void dispose() {
    _active.removeListener(_onActiveChanged);
    super.dispose();
  }

  /// Drop the previous child's ✓ marks right away so they never show up
  /// under the new child's name while reloading.
  void _onActiveChanged() {
    setState(() => _groups = null);
    _load();
  }

  Future<void> _load() async {
    final active = _active.value;
    final showProgress = active != null && active.canView(ShareSection.activities);
    final groups = await ServiceLocator.activityService.getGroups(childId: showProgress ? active.child.id : null);
    if (mounted) setState(() => _groups = groups);
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    final active = _active.value;
    final showProgress = active != null && active.canView(ShareSection.activities);
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
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (active != null) ...[
                  ActiveChildBanner(
                    active: active,
                    progressText: showProgress
                        ? 'Đã làm ${groups.fold(0, (n, g) => n + g.doneCount)}/'
                            '${groups.fold(0, (n, g) => n + g.items.length)} hoạt động'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                for (final group in groups) ...[
                  _GroupCard(
                    group: group,
                    showProgress: showProgress,
                    onTap: () async {
                      await context.push('${AppRoutes.activityGroupDetail}/${group.id}');
                      await _load();
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.showProgress, required this.onTap});

  final ActivityGroup group;
  final bool showProgress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CardContainer(
      onTap: onTap,
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
            child: Text(
              showProgress ? '${group.doneCount}/${group.items.length}' : '${group.items.length}',
              style: AppTextStyles.caption.copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
