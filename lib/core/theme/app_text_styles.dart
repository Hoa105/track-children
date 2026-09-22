import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Text styles built on Quicksand (Google Font), matching the prototype's
/// 'Quicksand' font family at weights 400/500/600/700.
abstract final class AppTextStyles {
  static TextStyle _base({
    required double size,
    required FontWeight weight,
    Color color = AppColors.textPrimary,
    double? height,
  }) =>
      GoogleFonts.quicksand(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  static TextStyle h1 = _base(size: 24, weight: FontWeight.w700);
  static TextStyle h2 = _base(size: 20, weight: FontWeight.w700);
  static TextStyle h3 = _base(size: 17, weight: FontWeight.w600);
  static TextStyle titleMedium = _base(size: 15, weight: FontWeight.w600);
  static TextStyle body = _base(size: 14, weight: FontWeight.w500);
  static TextStyle bodyRegular = _base(size: 14, weight: FontWeight.w400);
  static TextStyle bodySecondary =
      _base(size: 13, weight: FontWeight.w500, color: AppColors.textSecondary);
  static TextStyle caption =
      _base(size: 12, weight: FontWeight.w500, color: AppColors.textMuted);
  static TextStyle captionBold =
      _base(size: 12, weight: FontWeight.w700, color: AppColors.textSecondary);
  static TextStyle button = _base(size: 14, weight: FontWeight.w700, color: Colors.white);
  static TextStyle navLabel = _base(size: 11, weight: FontWeight.w700);
}
