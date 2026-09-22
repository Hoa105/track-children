import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Recurring "not a medical diagnosis" disclaimer shown on Home and Results.
class MedicalDisclaimerBanner extends StatelessWidget {
  const MedicalDisclaimerBanner({super.key, this.text = _defaultText});

  static const _defaultText =
      'Đánh giá chỉ mang tính sàng lọc, không phải chẩn đoán y khoa và không thay thế bác sĩ hoặc chuyên gia phát triển trẻ.';

  static const resultsText =
      'Kết quả chỉ mang tính hỗ trợ theo dõi, không phải chẩn đoán và không thay thế tư vấn của bác sĩ / chuyên gia phát triển trẻ.';

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.amberSurfaceLight,
        borderRadius: AppRadius.smallRadius,
        border: Border.all(color: AppColors.amberBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.amberDark),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: AppTextStyles.caption.copyWith(color: AppColors.amberHeadline)),
          ),
        ],
      ),
    );
  }
}
