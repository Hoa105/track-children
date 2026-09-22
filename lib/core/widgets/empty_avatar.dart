import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Circular placeholder avatar (initials on a tinted background) used
/// wherever the prototype shows a child/parent photo we don't have.
class EmptyAvatar extends StatelessWidget {
  const EmptyAvatar({super.key, required this.label, this.size = 48, this.color = AppColors.surfaceGreen});

  final String label;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final initial = label.trim().isNotEmpty ? label.trim().substring(0, 1).toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}
