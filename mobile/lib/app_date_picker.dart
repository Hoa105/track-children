import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Theme chuẩn cho hộp thoại chọn ngày tháng trong toàn bộ ứng dụng.
/// Đồng bộ với giao diện chọn ngày đo tăng trưởng (Green Sprout).
DatePickerThemeData buildAppDatePickerTheme() => DatePickerThemeData(
  backgroundColor: SettingsColors.surface,
  surfaceTintColor: Colors.transparent,
  headerBackgroundColor: SettingsColors.primary,
  headerForegroundColor: SettingsColors.surface,
  headerHeadlineStyle: const TextStyle(
    fontFamily: 'Nunito',
    color: SettingsColors.surface,
    fontSize: 26,
    fontWeight: FontWeight.w800,
  ),
  headerHelpStyle: const TextStyle(
    fontFamily: 'Nunito',
    color: SettingsColors.surface,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  ),
  weekdayStyle: const TextStyle(
    fontFamily: 'Nunito',
    color: SettingsColors.textSecondary,
    fontWeight: FontWeight.w700,
  ),
  dayStyle: const TextStyle(
    fontFamily: 'Nunito',
    color: SettingsColors.textPrimary,
    fontWeight: FontWeight.w600,
  ),
  todayForegroundColor: const WidgetStatePropertyAll(SettingsColors.primary),
  todayBackgroundColor: const WidgetStatePropertyAll(Colors.transparent),
  dayForegroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.selected)) {
      return SettingsColors.surface;
    }
    if (states.contains(WidgetState.disabled)) {
      return SettingsColors.textSecondary.withValues(alpha: 0.38);
    }
    return SettingsColors.textPrimary;
  }),
  dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.selected)) {
      return SettingsColors.primary;
    }
    return Colors.transparent;
  }),
  todayBorder: const BorderSide(color: SettingsColors.primary, width: 1.5),
  rangeSelectionBackgroundColor: SettingsColors.primarySoft,
  cancelButtonStyle: TextButton.styleFrom(
    foregroundColor: SettingsColors.textSecondary,
    textStyle: const TextStyle(
      fontFamily: 'Nunito',
      fontWeight: FontWeight.w700,
    ),
  ),
  confirmButtonStyle: TextButton.styleFrom(
    foregroundColor: SettingsColors.primary,
    textStyle: const TextStyle(
      fontFamily: 'Nunito',
      fontWeight: FontWeight.w800,
    ),
  ),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(28)),
    side: BorderSide(color: SettingsColors.border),
  ),
);

/// Hàm hiển thị popup chọn ngày dùng chung cho toàn bộ hệ thống.
Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String helpText = 'Chọn ngày',
  String cancelText = 'Hủy',
  String confirmText = 'Chọn',
  DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
}) => showDatePicker(
  context: context,
  initialDate: initialDate,
  firstDate: firstDate,
  lastDate: lastDate,
  helpText: helpText,
  cancelText: cancelText,
  confirmText: confirmText,
  initialEntryMode: initialEntryMode,
  builder: (context, child) => Theme(
    data: Theme.of(context).copyWith(
      datePickerTheme: buildAppDatePickerTheme(),
    ),
    child: child!,
  ),
);
