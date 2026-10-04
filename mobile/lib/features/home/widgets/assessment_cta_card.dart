import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';

/// "Mẹ cần chú ý" assessment CTA card.
class AssessmentCtaCard extends StatelessWidget {
  const AssessmentCtaCard({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.amberSurfaceLight,
        borderRadius: AppRadius.mediumRadius,
        border: Border.all(color: AppColors.amberBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mẹ cần chú ý',
              style: AppTextStyles.titleMedium.copyWith(color: AppColors.amberHeadline)),
          const SizedBox(height: 4),
          Text('24 câu hỏi · khoảng 8 phút',
              style: AppTextStyles.caption.copyWith(color: AppColors.amberDark)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Bé đã đến mốc 18 tháng.',
            style: AppTextStyles.caption.copyWith(color: AppColors.amberDark),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(label: 'Bắt đầu đánh giá →', color: AppColors.amber, onPressed: onStart),
        ],
      ),
    );
  }
}
