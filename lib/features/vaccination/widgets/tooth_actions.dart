import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../models/child.dart';
import '../../../models/tooth.dart';
import '../../../services/service_locator.dart';
import 'vaccine_widgets.dart';

enum ToothAction { markErupted, changeDate, remove }

/// Bottom sheet to mark / re-date / un-mark one tooth, then persists the choice.
/// Returns true when the child's records changed.
Future<bool> showToothActions(
  BuildContext context, {
  required Child child,
  required PrimaryTooth tooth,
  ToothRecord? record,
}) async {
  final action = await showModalBottomSheet<ToothAction>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tooth.label, style: AppTextStyles.h3),
            const SizedBox(height: 4),
            Text('Thường mọc lúc ${tooth.eruptionLabel}', style: AppTextStyles.bodySecondary),
            if (record != null) ...[
              const SizedBox(height: 4),
              Text(
                'Đã mọc ngày ${vaccineDateFormat.format(record.eruptedDate)}',
                style: AppTextStyles.body.copyWith(color: AppColors.primaryDark),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (record == null)
              PrimaryButton(
                label: 'Đánh dấu đã mọc',
                onPressed: () => Navigator.pop(sheetContext, ToothAction.markErupted),
              )
            else ...[
              PrimaryButton(
                label: 'Sửa ngày mọc',
                onPressed: () => Navigator.pop(sheetContext, ToothAction.changeDate),
              ),
              const SizedBox(height: AppSpacing.sm),
              SecondaryButton(
                label: 'Bỏ đánh dấu',
                color: AppColors.danger,
                onPressed: () => Navigator.pop(sheetContext, ToothAction.remove),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  if (action == null || !context.mounted) return false;

  if (action == ToothAction.remove) {
    await ServiceLocator.teethingService.removeRecord(child.id, tooth.id);
  } else {
    final picked = await showDatePicker(
      context: context,
      initialDate: record?.eruptedDate ?? DateTime.now(),
      firstDate: child.dob,
      lastDate: DateTime.now(),
      helpText: 'Ngày mọc răng',
    );
    if (picked == null) return false;
    await ServiceLocator.teethingService.saveRecord(
      ToothRecord(childId: child.id, toothId: tooth.id, eruptedDate: picked),
    );
  }
  return true;
}
