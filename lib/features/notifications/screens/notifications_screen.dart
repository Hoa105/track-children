import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/bottom_nav_bar.dart';
import '../../../core/widgets/card_container.dart';

class _NotificationItem {
  final String title;
  final String time;
  final IconData icon;
  final Color color;
  final String route;
  const _NotificationItem(this.title, this.time, this.icon, this.color, this.route);
}

/// Verbatim from prototype_reference.md § "Notifications list items".
final _items = [
  _NotificationItem('Cần theo dõi thêm', '2 giờ trước', Icons.warning_amber_rounded, AppColors.amberDark, AppRoutes.history),
  _NotificationItem('Đến hạn đo tăng trưởng', 'Hôm nay', Icons.show_chart_rounded, AppColors.primaryDark, AppRoutes.growth),
  _NotificationItem('Mốc đánh giá 18 tháng', 'Hôm qua', Icons.flag_rounded, AppColors.purple, AppRoutes.home),
  _NotificationItem('Hoạt động mới cho bé', '14/08', Icons.extension_rounded, AppColors.primaryDark, AppRoutes.activityGroups),
  _NotificationItem('Nhật ký tuần này', '11/08', Icons.menu_book_rounded, AppColors.amberDark, AppRoutes.journal),
];

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShellScaffold(
      tab: AppTab.home,
      appBar: AppBar(title: const Text('Thông báo / Nhắc nhở')),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) {
          final item = _items[i];
          return CardContainer(
            onTap: () => context.push(item.route),
            child: Row(
              children: [
                Icon(item.icon, color: item.color),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(item.title, style: AppTextStyles.body)),
                Text(item.time, style: AppTextStyles.caption),
              ],
            ),
          );
        },
      ),
    );
  }
}
