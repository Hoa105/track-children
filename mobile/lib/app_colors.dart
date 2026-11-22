import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF286B52);
  static const primaryDark = Color(0xFF194C3C);
  static const primarySoft = Color(0xFFE5EFE3);
  static const background = Color(0xFFFAF7F0);
  static const heroPanel = Color(0xFFF0DFC3);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF23332E);
  static const textSecondary = Color(0xFF718078);
  static const border = Color(0xFFEAE8DF);
  static const purpleSurfaceLight = Color(0xFFF0EAF8);
  static const purpleText = Color(0xFF655080);
}

abstract final class WeightChartColors {
  static const heroInk = Color(0xFF173B68);
  static const positive = Color(0xFF287A45);
  static const attention = Color(0xFF9A651D);
  static const critical = Color(0xFFB44B42);
  static const unknown = Color(0xFF64748B);
  static const axis = Color(0xFF315B87);
  static const frame = Color(0xFFE5ECF3);
  static const data = Color(0xFFE58C45);
  static const ink = Color(0xFF182B34);
  static const muted = Color(0xFF526573);
  static const median = Color(0xFF25B96C);
  static const sd2 = Color(0xFFF3B44F);
  static const sd3 = Color(0xFFFF885C);
  static const center = Color(0xFFDDF5DF);
  static const outer = Color(0xFFFFEDCC);
  static const grid = Color(0xFFE8EEEB);
}

abstract final class StatureChartColors {
  static const data = Color(0xFF4B92C6);
}

/// Green Sprout palette scoped to Home.
abstract final class HomeColors {
  static const headerStart = Color(0xFFB8DF8A);
  static const headerEnd = Color(0xFFD9EFA9);
  static const background = Color(0xFFF0F5E7);
  static const surface = Color(0xFFFFFFFF);
  static const iconBackground = Color(0xFFD9EFA9);
  static const milestoneAccent = Color(0xFFB6E34E);
  static const primary = Color(0xFF538B29);
  static const ink = Color(0xFF29451E);
  static const reminderBackground = Color(0xFFEAF5C9);
  static const reminderCta = Color(0xFF477921);
}

/// Green Sprout colors scoped to the Start presentation.
abstract final class StartColors {
  static const background = HomeColors.background;
  static const ink = HomeColors.ink;
  static const slogan = HomeColors.reminderCta;
}

/// Green Sprout palette scoped to teething; shared app colors stay unchanged.
abstract final class TeethingColors {
  static const background = HomeColors.background;
  static const surface = HomeColors.surface;
  static const primary = HomeColors.primary;
  static const primaryDark = HomeColors.ink;
  static const primarySoft = HomeColors.reminderBackground;
  static const textPrimary = HomeColors.ink;
  static const textSecondary = HomeColors.reminderCta;
  static const border = HomeColors.iconBackground;
  static const accent = HomeColors.milestoneAccent;
  static const iconBackground = HomeColors.iconBackground;
}

/// Green Sprout palette scoped to child profile selection.
abstract final class ChildProfileSelectionColors {
  static const background = HomeColors.background;
  static const surface = HomeColors.surface;
  static const ink = HomeColors.ink;
  static const secondary = HomeColors.reminderCta;
  static const primary = HomeColors.primary;
  static const avatar = HomeColors.iconBackground;
  static const border = HomeColors.iconBackground;
  static const pressed = HomeColors.reminderBackground;
}

/// Green Sprout palette scoped to notifications and reminder settings.
abstract final class NotificationColors {
  static const background = HomeColors.background;
  static const surface = HomeColors.surface;
  static const primary = HomeColors.primary;
  static const ink = HomeColors.ink;
  static const reminderCta = HomeColors.reminderCta;
  static const iconBackground = HomeColors.iconBackground;
  static const accent = HomeColors.milestoneAccent;
  static const reminderBackground = HomeColors.reminderBackground;
  static const border = HomeColors.iconBackground;
  static const unreadIndicator = HomeColors.primary;
  static const cardUnread = HomeColors.surface;
  static const cardRead = Color(0xFFF7FAF2);
}

/// Green Sprout palette scoped to Settings & Privacy.
abstract final class SettingsColors {
  static const background = HomeColors.background;
  static const surface = HomeColors.surface;
  static const primary = HomeColors.primary;
  static const primaryDark = HomeColors.ink;
  static const primarySoft = HomeColors.reminderBackground;
  static const textPrimary = HomeColors.ink;
  static const textSecondary = HomeColors.reminderCta;
  static const border = HomeColors.iconBackground;
  static const accent = HomeColors.milestoneAccent;
  static const iconBackground = HomeColors.iconBackground;
}

/// Green Sprout palette scoped to Growth Tracking.
abstract final class GrowthColors {
  static const background = HomeColors.background;
  static const surface = HomeColors.surface;
  static const primary = HomeColors.primary;
  static const primaryDark = HomeColors.ink;
  static const primarySoft = HomeColors.reminderBackground;
  static const textPrimary = HomeColors.ink;
  static const textSecondary = HomeColors.reminderCta;
  static const border = HomeColors.iconBackground;
  static const accent = HomeColors.milestoneAccent;
  static const iconBackground = HomeColors.iconBackground;
}
