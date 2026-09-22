import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color = AppColors.primaryDark,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mediumRadius),
      ),
      child: Text(label, style: AppTextStyles.body.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
