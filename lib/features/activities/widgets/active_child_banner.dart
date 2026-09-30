import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_avatar.dart';
import '../../../models/child_share.dart';
import '../../../services/active_child.dart';

/// "Hoạt động của bé Minh" strip at the top of the activity screens, so the
/// parent always knows whose progress the ✓ marks belong to. For a shared
/// child it also states what the current user may do with the progress.
class ActiveChildBanner extends StatelessWidget {
  const ActiveChildBanner({super.key, required this.active, this.progressText});

  final ActiveChild active;

  /// e.g. "Đã làm 12/60 hoạt động"; null hides the progress line.
  final String? progressText;

  @override
  Widget build(BuildContext context) {
    final section = ShareSection.activities;
    final note = active.isOwner
        ? null
        : !active.canView(section)
            ? 'Bạn không có quyền xem tiến độ hoạt động của ${active.shortName}'
            : !active.canEdit(section)
                ? 'Bạn chỉ được xem tiến độ, không đánh dấu được'
                : 'Được chia sẻ bởi ${active.sharedAccess!.ownerLabel}';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: active.isOwner ? AppColors.surfaceGreenLighter : AppColors.purpleSurfaceLight,
        border: Border.all(color: active.isOwner ? AppColors.border : AppColors.purpleBorder),
        borderRadius: AppRadius.mediumRadius,
      ),
      child: Row(
        children: [
          EmptyAvatar(
            label: active.child.name,
            size: 40,
            color: active.isOwner ? AppColors.surfaceGreen : AppColors.purpleSurface,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hoạt động của ${active.shortName}', style: AppTextStyles.titleMedium),
                if (progressText != null) ...[
                  const SizedBox(height: 2),
                  Text(progressText!, style: AppTextStyles.caption.copyWith(color: AppColors.primaryDark)),
                ],
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(note, style: AppTextStyles.caption.copyWith(color: AppColors.purpleBody)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
