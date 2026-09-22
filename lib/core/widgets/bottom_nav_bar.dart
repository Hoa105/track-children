import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// The 5 bottom-nav tabs, in prototype order.
///
/// Deviation note: the prototype has no single dedicated "Thêm" screen body
/// — its bottom nav icon set only visibly targets Trang chủ / Theo dõi /
/// Hoạt động / Nhật ký directly, while Settings/Companion/Notifications are
/// reached from other entry points. We interpret "Thêm" as a small in-app
/// hub screen linking to Cài đặt, Góc đồng hành and Thông báo (see
/// lib/features/more/screens/more_hub_screen.dart) — a documented
/// interpretation, not a silent guess.
enum AppTab { home, tracking, activities, journal, more }

extension AppTabX on AppTab {
  String get label => switch (this) {
        AppTab.home => 'Trang chủ',
        AppTab.tracking => 'Theo dõi',
        AppTab.activities => 'Hoạt động',
        AppTab.journal => 'Nhật ký',
        AppTab.more => 'Thêm',
      };

  IconData get icon => switch (this) {
        AppTab.home => Icons.home_rounded,
        AppTab.tracking => Icons.show_chart_rounded,
        AppTab.activities => Icons.extension_rounded,
        AppTab.journal => Icons.menu_book_rounded,
        AppTab.more => Icons.grid_view_rounded,
      };
}

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({super.key, required this.current, required this.onTap});

  final AppTab current;
  final ValueChanged<AppTab> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: AppTab.values.map((tab) {
            final active = tab == current;
            return Expanded(
              child: InkWell(
                onTap: () => onTap(tab),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : AppColors.navInactiveIcon,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(tab.icon, size: 12, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tab.label,
                      style: AppTextStyles.navLabel.copyWith(
                        color: active ? AppColors.navActiveLabel : AppColors.navInactiveLabel,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
