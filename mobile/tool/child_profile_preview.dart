import 'package:flutter/material.dart';
import 'package:track_children/app_colors.dart';
import 'package:track_children/features/child/child_profile_screen.dart';

// Development entry point for verifying the profile on a physical device.
void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    ),
    home: const ChildProfileScreen(
      initialFields: {
        'full_name': 'Nguyễn Minh An',
        'gender': 'male',
        'date_of_birth': '2025-04-02',
        'gestational_weeks': 36,
        'birth_weight_kg': 2.8,
      },
    ),
  ),
);
