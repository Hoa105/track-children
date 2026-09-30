import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/child_share.dart';

/// Per-section permission picker (F23.2): one "Không xem / Xem / Xem & sửa"
/// selector per [ShareSection]. Shared by the invite screen and the
/// change-permission sheet.
class PermissionMatrix extends StatelessWidget {
  const PermissionMatrix({super.key, required this.value, required this.onChanged});

  final SharePermissions value;
  final ValueChanged<SharePermissions> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.mediumRadius,
          ),
          child: Column(
            children: [
              const _FixedSectionRow(),
              for (final section in ShareSection.values) ...[
                const Divider(height: 1, color: AppColors.border),
                _SectionRow(
                  section: section,
                  level: value.of(section),
                  onChanged: (level) => onChanged(value.withLevel(section, level)),
                ),
              ],
            ],
          ),
        ),
        if (!value.hasAnyAccess) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Cần cho xem ít nhất 1 mục.',
            style: AppTextStyles.caption.copyWith(color: AppColors.danger),
          ),
        ],
      ],
    );
  }
}

extension ShareSectionIcon on ShareSection {
  IconData get icon => switch (this) {
        ShareSection.growth => Icons.show_chart_rounded,
        ShareSection.assessment => Icons.fact_check_outlined,
        ShareSection.vaccination => Icons.vaccines_rounded,
        ShareSection.journal => Icons.menu_book_rounded,
        ShareSection.activities => Icons.extension_rounded,
      };
}

/// Basic info row — always viewable, never editable, so it's not a choice.
class _FixedSectionRow extends StatelessWidget {
  const _FixedSectionRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.child_care_rounded, size: 18, color: AppColors.textSecondaryAlt),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text('Thông tin cơ bản của bé', style: AppTextStyles.body)),
          const Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text('Luôn xem được', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.section, required this.level, required this.onChanged});

  final ShareSection section;
  final AccessLevel level;
  final ValueChanged<AccessLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(section.icon, size: 18, color: AppColors.primaryDark),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(section.label, style: AppTextStyles.titleMedium)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: AppRadius.smallRadius),
            child: Row(
              children: [
                for (final l in AccessLevel.values)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(l),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: level == l ? _activeColor(l) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          l.label,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: level == l ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (level == AccessLevel.edit) ...[
            const SizedBox(height: 6),
            Text('Được ${section.editDescription}', style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }

  static Color _activeColor(AccessLevel level) => switch (level) {
        AccessLevel.none => AppColors.textSecondaryAlt,
        AccessLevel.view => AppColors.primary,
        AccessLevel.edit => AppColors.primaryDark,
      };
}

/// Read-only list of what each section allows — for the invitee side
/// (accept dialog, shared profile) where the levels can't be changed.
class PermissionSummary extends StatelessWidget {
  const PermissionSummary({super.key, required this.permissions});

  final SharePermissions permissions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in ShareSection.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  switch (permissions.of(section)) {
                    AccessLevel.none => Icons.block_rounded,
                    AccessLevel.view => Icons.visibility_outlined,
                    AccessLevel.edit => Icons.edit_outlined,
                  },
                  size: 16,
                  color: permissions.canView(section) ? AppColors.primaryDark : AppColors.textMuted,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    section.label,
                    style: AppTextStyles.caption.copyWith(
                      color: permissions.canView(section) ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                  ),
                ),
                Text(
                  permissions.of(section).label,
                  style: AppTextStyles.captionBold.copyWith(
                    color: permissions.canView(section) ? AppColors.primaryDark : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
/// Small pill showing a permission level or pending state.
class SharePill extends StatelessWidget {
  const SharePill({super.key, required this.label, this.color = AppColors.primaryDark, this.background = AppColors.surfaceGreen});

  factory SharePill.permission(SharePermissions permissions) => SharePill(label: permissions.label);

  factory SharePill.pending() => const SharePill(
        label: 'Đang chờ',
        color: AppColors.amberDark,
        background: AppColors.amberSurface,
      );

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: AppRadius.pillRadius),
      child: Text(label, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

/// Grey note box used for the sharing rules (limit, expiry, owner-only).
class ShareInfoNote extends StatelessWidget {
  const ShareInfoNote({super.key, required this.text, this.icon = Icons.info_outline_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadius.smallRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondaryAlt),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary))),
        ],
      ),
    );
  }
}

/// Confirm dialog for destructive sharing actions (thu hồi, hủy lời mời,
/// rời hồ sơ). Resolves to true only when the parent confirms.
Future<bool> confirmShareAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Full-screen placeholder for a per-child screen the current user has no
/// access to for a shared child (e.g. opened from a notification).
class NoAccessView extends StatelessWidget {
  const NoAccessView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 40, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(message, style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
