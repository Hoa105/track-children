import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

/// A pill-shaped selectable chip used for filters, tags and mood/domain
/// selectors across the app.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.color = AppColors.primary,
    this.lightColor = AppColors.surfaceGreen,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color color;
  final Color lightColor;
  final IconData? icon;

  /// When false the chip is greyed out and ignores taps.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: AppRadius.pillRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: !enabled ? AppColors.background : (selected ? lightColor : AppColors.surface),
          borderRadius: AppRadius.pillRadius,
          border: Border.all(color: enabled && selected ? color : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: enabled && selected ? color : AppColors.textMuted),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppTextStyles.bodySecondary.copyWith(
                color: !enabled ? AppColors.textMuted : (selected ? color : AppColors.textSecondary),
                fontWeight: enabled && selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
