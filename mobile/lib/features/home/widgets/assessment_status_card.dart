import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// Verbatim copy from prototype_reference.md: "Cần theo dõi thêm" warning
/// card with last-assessment metadata.
class AssessmentStatusCard extends StatelessWidget {
  const AssessmentStatusCard({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mediumRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.amberSurfaceLight,
          borderRadius: AppRadius.mediumRadius,
          border: Border.all(color: AppColors.amberBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.amberDark),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cần theo dõi thêm',
                      style: AppTextStyles.titleMedium.copyWith(color: AppColors.amberHeadline)),
                  const SizedBox(height: 4),
                  Text('Lần gần nhất · 02/08/2026', style: AppTextStyles.caption),
                  const SizedBox(height: 2),
                  Text(
                    'Cách lần trước 30 ngày · đã đánh giá 5 lần từ khi tạo hồ sơ',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.amberDark),
          ],
        ),
      ),
    );
  }
}
