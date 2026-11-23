import 'package:flutter/material.dart';

import '../../app_colors.dart';

export '../../app_colors.dart' show VaccinationColors;

/// Applies the Green Sprout theme across all vaccination routes, dialogs, and bottom sheets.
class VaccinationTheme extends StatelessWidget {
  const VaccinationTheme({required this.child, super.key});

  final Widget child;

  static ThemeData of(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      scaffoldBackgroundColor: VaccinationColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: VaccinationColors.primary,
        onPrimary: VaccinationColors.surface,
        primaryContainer: VaccinationColors.primarySoft,
        onPrimaryContainer: VaccinationColors.textPrimary,
        secondary: VaccinationColors.primary,
        onSecondary: VaccinationColors.surface,
        secondaryContainer: VaccinationColors.iconBackground,
        onSecondaryContainer: VaccinationColors.textPrimary,
        surface: VaccinationColors.surface,
        onSurface: VaccinationColors.textPrimary,
        onSurfaceVariant: VaccinationColors.textSecondary,
        outline: VaccinationColors.border,
        outlineVariant: VaccinationColors.border,
        surfaceTint: Colors.transparent,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: 'Nunito',
        bodyColor: VaccinationColors.textPrimary,
        displayColor: VaccinationColors.textPrimary,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: VaccinationColors.background,
        foregroundColor: VaccinationColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: VaccinationColors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Nunito',
          color: VaccinationColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Nunito',
          color: VaccinationColors.textSecondary,
          fontSize: 15,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: VaccinationColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: VaccinationColors.primary,
          side: const BorderSide(color: VaccinationColors.primary),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: VaccinationColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: of(context),
    child: child,
  );
}
