import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/card_container.dart';
import '../../../models/activity.dart';
import '../../../services/service_locator.dart';

/// Flat list of every favorited [Activity] across all groups, opened from
/// the bookmark icon on [ActivityGroupsScreen]'s app bar.
class ActivityFavoritesScreen extends StatefulWidget {
  const ActivityFavoritesScreen({super.key});

  @override
  State<ActivityFavoritesScreen> createState() => _ActivityFavoritesScreenState();
}

class _ActivityFavoritesScreenState extends State<ActivityFavoritesScreen> {
  List<Activity>? _favorites;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final favorites = await ServiceLocator.activityService.getFavorites();
    if (mounted) setState(() => _favorites = favorites);
  }

  @override
  Widget build(BuildContext context) {
    final favorites = _favorites;
    return Scaffold(
      appBar: AppBar(title: const Text('Hoạt động yêu thích')),
      body: favorites == null
          ? const Center(child: CircularProgressIndicator())
          : favorites.isEmpty
              ? Center(child: Text('Chưa có hoạt động yêu thích nào.', style: AppTextStyles.bodySecondary))
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: favorites.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) {
                    final activity = favorites[i];
                    return CardContainer(
                      onTap: () async {
                        await context.push('${AppRoutes.activityDetail}/${activity.id}');
                        _load();
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.favorite_rounded, color: AppColors.danger, size: 20),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(activity.name, style: AppTextStyles.titleMedium),
                                const SizedBox(height: 2),
                                Text(
                                  '${activity.ageRangeLabel} · ${activity.durationLabel}',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
