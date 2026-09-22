import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/card_container.dart';

class MilestoneReminderCard extends StatelessWidget {
  const MilestoneReminderCard({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CardContainer(
      onTap: onTap,
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded, color: AppColors.primaryDark),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mốc tiếp theo: 24 tháng', style: AppTextStyles.titleMedium),
                const SizedBox(height: 2),
                Text('Còn 45 ngày · sẽ nhắc mẹ tự động', style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
