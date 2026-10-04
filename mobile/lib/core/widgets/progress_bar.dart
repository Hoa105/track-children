import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Thin rounded progress bar used for assessment-step progress and
/// domain-completion bars.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.primary,
    this.backgroundColor = AppColors.border,
    this.height = 8,
  });

  final double value; // 0..1
  final Color color;
  final Color backgroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        color: color,
        backgroundColor: backgroundColor,
      ),
    );
  }
}
