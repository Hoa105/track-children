import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/secondary_button.dart';

/// "Gợi ý cho mẹ lúc này" — copy verbatim from prototype_reference.md.
class AiSuggestionCard extends StatelessWidget {
  const AiSuggestionCard({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.purpleSurfaceLight,
        borderRadius: AppRadius.mediumRadius,
        border: Border.all(color: AppColors.purpleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.purple),
              const SizedBox(width: AppSpacing.sm),
              Text('Gợi ý cho mẹ lúc này',
                  style: AppTextStyles.titleMedium.copyWith(color: AppColors.purpleHeading)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Ưu tiên hoạt động nhóm Ngôn ngữ tại nhà trong 4 tuần tới.',
            style: AppTextStyles.bodySecondary.copyWith(color: AppColors.purpleBody),
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(label: 'Xem hoạt động gợi ý', color: AppColors.purpleHeading, onPressed: onTap),
        ],
      ),
    );
  }
}
