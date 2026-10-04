import 'package:flutter/material.dart';

/// Color tokens copied verbatim from the prototype's inline styles
/// (see prototype_reference.md § "Exact color palette").
abstract final class AppColors {
  // Primary green (buttons / accent)
  static const primary = Color(0xFF6FBE8F);
  static const primaryDark = Color(0xFF4E9E74);
  static const primaryDarker = Color(0xFF2F6B4C);

  // Light green surfaces
  static const surfaceGreen = Color(0xFFE4F3EA);
  static const surfaceGreenLighter = Color(0xFFF4FBF7);
  static const surfaceGreenLightest = Color(0xFFF2FAF5);

  // App-wide background / surface / border
  static const background = Color(0xFFF2F5F3);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE4EDE7);
  static const borderAlt = Color(0xFFE1E8E4);
  static const borderAlt2 = Color(0xFFDCE5DF);

  // Purple accent (assessment flow)
  static const purple = Color(0xFF8B7FD6);
  static const purpleHeading = Color(0xFF5B4FA8);
  static const purpleSurface = Color(0xFFEDEBFA);
  static const purpleSurfaceLight = Color(0xFFF7F6FE);
  static const purpleBody = Color(0xFF6E6A8C);
  static const purpleBorder = Color(0xFFDCD8F5);
  static const purpleBorder2 = Color(0xFFC9C1EE);

  // Amber / warning
  static const amber = Color(0xFFD9A13B);
  static const amberDark = Color(0xFFB98A2E);
  static const amberHeadline = Color(0xFF8A661F);
  static const amberSurface = Color(0xFFFDF0D8);
  static const amberSurfaceLight = Color(0xFFFFFBF2);
  static const amberBorder = Color(0xFFF0DFC0);

  // Red / danger
  static const danger = Color(0xFFC0483C);
  static const dangerDark = Color(0xFFA0524A);
  static const dangerSurfaceLight = Color(0xFFFFF6F5);
  static const dangerSurface = Color(0xFFF3D6D2);

  // Text
  static const textPrimary = Color(0xFF33453C);
  static const textSecondary = Color(0xFF5A6E63);
  static const textSecondaryAlt = Color(0xFF7B8C82);
  static const textMuted = Color(0xFF9AAAA1);
  static const textDisabled = Color(0xFFB3BFB8);

  // Bottom nav
  static const navInactiveIcon = Color(0xFFD8E3DC);
  static const navActiveLabel = primaryDark;
  static const navInactiveLabel = textMuted;
}
