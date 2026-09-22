import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

/// Mirrors the prototype's own placeholder pattern (e.g. "[ illustration: mẹ
/// bế con ]") instead of trying to source real illustration/photo assets.
class IllustrationPlaceholder extends StatelessWidget {
  const IllustrationPlaceholder({
    super.key,
    required this.label,
    this.height = 140,
    this.color = AppColors.surfaceGreen,
    this.icon = Icons.image_outlined,
    this.borderRadius,
  });

  final String label;
  final double height;
  final Color color;
  final IconData icon;
  final BorderRadius? borderRadius;

  /// Below this, the icon + caption text no longer fit vertically, so the
  /// caption is dropped and only the icon is shown (e.g. small list thumbnails).
  static const double _labelMinHeight = 96;

  @override
  Widget build(BuildContext context) {
    final showLabel = height >= _labelMinHeight;
    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius ?? AppRadius.largeRadius,
      ),
      child: showLabel
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.primaryDark, size: 28),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '[ minh họa: $label ]',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption,
                  ),
                ),
              ],
            )
          : Icon(icon, color: AppColors.primaryDark, size: 24),
    );
  }
}
