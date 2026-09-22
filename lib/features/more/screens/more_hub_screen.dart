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
import '../../../core/widgets/empty_avatar.dart';
import '../../../services/service_locator.dart';

/// Documented interpretation: the prototype has no single dedicated "Thêm"
/// screen body of its own — see prototype_reference.md's navigation-graph
/// note. This hub links to the 3 screens that logically belong under it
/// (Cài đặt, Góc đồng hành, Thông báo) instead of guessing at a hidden
/// prototype screen.
class MoreHubScreen extends StatelessWidget {
  const MoreHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = ServiceLocator.authService.currentUser;
    return AppShellScaffold(
      tab: AppTab.more,
      appBar: AppBar(title: const Text('Thêm')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          CardContainer(
            padding: const EdgeInsets.all(AppSpacing.md),
            onTap: () => context.push(AppRoutes.accountSettings),
            child: Row(
              children: [
                EmptyAvatar(label: user.name, size: 52),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.username, style: AppTextStyles.titleMedium),
                      const SizedBox(height: 2),
                      Text(user.email, style: AppTextStyles.caption),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Khám phá thêm', style: AppTextStyles.h2),
          const SizedBox(height: 4),
          Text(
            'Kiến thức, thông báo và cài đặt cho hành trình của bé',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.lg),
          _HubTile(
            title: 'Góc đồng hành',
            subtitle: 'Bài viết, FAQ và câu chuyện từ mentor',
            icon: Icons.diversity_3_rounded,
            tint: AppColors.surfaceGreen,
            iconColor: AppColors.primaryDark,
            onTap: () => context.push(AppRoutes.companion),
          ),
          const SizedBox(height: AppSpacing.md),
          _HubTile(
            title: 'Thông báo / Nhắc nhở',
            subtitle: 'Xem toàn bộ thông báo và nhắc nhở',
            icon: Icons.notifications_none_rounded,
            tint: AppColors.amberSurface,
            iconColor: AppColors.amberDark,
            onTap: () => context.push(AppRoutes.notifications),
          ),
          const SizedBox(height: AppSpacing.md),
          _HubTile(
            title: 'Cài đặt & Quyền riêng tư',
            subtitle: 'Hồ sơ trẻ, ứng dụng, bảo mật',
            icon: Icons.settings_outlined,
            tint: AppColors.purpleSurface,
            iconColor: AppColors.purpleHeading,
            onTap: () => context.push(AppRoutes.settings),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Bé Lớn Khôn · phiên bản 1.0.0', textAlign: TextAlign.center, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CardContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tint, borderRadius: AppRadius.smallRadius),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleMedium),
                const SizedBox(height: 3),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
