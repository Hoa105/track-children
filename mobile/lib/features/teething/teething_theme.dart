import 'package:flutter/material.dart';

import '../../app_colors.dart';

/// Keeps implicit Material controls consistent across teething routes/dialogs.
class TeethingTheme extends StatelessWidget {
  const TeethingTheme({required this.builder, super.key});

  final WidgetBuilder builder;
  static ThemeData? _cachedTheme;
  static ThemeData? _lastBase;

  static ThemeData themeOf(ThemeData base) {
    if (identical(base, _lastBase) && _cachedTheme != null) {
      return _cachedTheme!;
    }
    _lastBase = base;
    _cachedTheme = base.copyWith(
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
    );
    return _cachedTheme!;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: themeOf(Theme.of(context)),
      child: Builder(builder: builder),
    );
  }
}
