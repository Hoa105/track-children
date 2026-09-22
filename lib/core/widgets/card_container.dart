import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class CardContainer extends StatelessWidget {
  const CardContainer({
    super.key,
    required this.child,
    this.color = AppColors.surface,
    this.borderColor = AppColors.border,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
  });

  final Widget child;
  final Color color;
  final Color borderColor;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final container = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.mediumRadius,
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
    if (onTap == null) return container;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mediumRadius,
      child: container,
    );
  }
}
