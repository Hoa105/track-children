import 'package:flutter/material.dart';

import '../../app_colors.dart';

/// Keeps implicit Material controls consistent across teething routes/dialogs.
class TeethingTheme extends StatelessWidget {
  const TeethingTheme({required this.builder, super.key});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: TeethingColors.background,
        colorScheme: base.colorScheme.copyWith(
          primary: TeethingColors.primary,
          onPrimary: TeethingColors.surface,
          primaryContainer: TeethingColors.primarySoft,
          onPrimaryContainer: TeethingColors.textPrimary,
          secondary: TeethingColors.primary,
          onSecondary: TeethingColors.surface,
          secondaryContainer: TeethingColors.iconBackground,
          onSecondaryContainer: TeethingColors.textPrimary,
          surface: TeethingColors.surface,
          onSurface: TeethingColors.textPrimary,
          onSurfaceVariant: TeethingColors.textSecondary,
          outline: TeethingColors.border,
          outlineVariant: TeethingColors.border,
          surfaceTint: TeethingColors.surface,
        ),
        textTheme: base.textTheme.apply(
          bodyColor: TeethingColors.textPrimary,
          displayColor: TeethingColors.textPrimary,
        ),
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: TeethingColors.background,
          foregroundColor: TeethingColors.textPrimary,
          surfaceTintColor: TeethingColors.background,
          scrolledUnderElevation: 0,
        ),
      ),
      child: Builder(builder: builder),
    );
  }
}
