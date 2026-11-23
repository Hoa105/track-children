import 'package:flutter/material.dart';

import '../../app_colors.dart';

/// Keeps implicit Material controls consistent across journal routes/dialogs.
class JournalTheme extends StatelessWidget {
  const JournalTheme({required this.builder, super.key});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: JournalColors.background,
        colorScheme: base.colorScheme.copyWith(
          primary: JournalColors.primary,
          onPrimary: JournalColors.surface,
          primaryContainer: JournalColors.primarySoft,
          onPrimaryContainer: JournalColors.textPrimary,
          secondary: JournalColors.primary,
          onSecondary: JournalColors.surface,
          secondaryContainer: JournalColors.iconBackground,
          onSecondaryContainer: JournalColors.textPrimary,
          surface: JournalColors.surface,
          onSurface: JournalColors.textPrimary,
          onSurfaceVariant: JournalColors.textSecondary,
          outline: JournalColors.border,
          outlineVariant: JournalColors.border,
          surfaceTint: JournalColors.surface,
        ),
        textTheme: base.textTheme.apply(
          bodyColor: JournalColors.textPrimary,
          displayColor: JournalColors.textPrimary,
        ),
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: JournalColors.background,
          foregroundColor: JournalColors.textPrimary,
          surfaceTintColor: JournalColors.background,
          scrolledUnderElevation: 0,
        ),
      ),
      child: Builder(builder: builder),
    );
  }
}
