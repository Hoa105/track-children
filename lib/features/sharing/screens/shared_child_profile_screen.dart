import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/card_container.dart';
import '../../../core/widgets/empty_avatar.dart';
import '../../../models/child.dart';
import '../../../models/child_share.dart';
import '../../../services/service_locator.dart';
import '../widgets/sharing_widgets.dart';

/// Read-only view of a child's profile someone else shared with the current
/// user (F23.6), with "Rời khỏi hồ sơ" (F23.7). Basic info is never editable
/// here — only the owner can change it.
class SharedChildProfileScreen extends StatefulWidget {
  const SharedChildProfileScreen({super.key, required this.accessId});

  final String accessId;

  @override
  State<SharedChildProfileScreen> createState() => _SharedChildProfileScreenState();
}

class _SharedChildProfileScreenState extends State<SharedChildProfileScreen> {
  SharedChildAccess? _access;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ServiceLocator.sharingService.getSharedWithMe().then((items) {
      if (!mounted) return;
      setState(() {
        _access = items.where((a) => a.id == widget.accessId && a.status == ShareStatus.accepted).firstOrNull;
        _loading = false;
      });
    });
  }

  Future<void> _leave(SharedChildAccess access) async {
    final ok = await confirmShareAction(
      context,
      title: 'Rời khỏi hồ sơ?',
      message: 'Bạn sẽ không xem được hồ sơ bé ${access.child.name} nữa. '
          'Muốn tham gia lại, ${access.ownerLabel} cần gửi lời mời mới.',
      confirmLabel: 'Rời khỏi',
    );
    if (!ok || !mounted) return;
    await ServiceLocator.sharingService.leave(access.id);
    await ServiceLocator.activeChild.forget(access.child.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã rời khỏi hồ sơ bé ${access.child.name}')),
    );
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final access = _access;
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ bé')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : access == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Text(
                      'Bạn không còn quyền xem hồ sơ này.',
                      style: AppTextStyles.bodySecondary,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _body(access),
    );
  }

  Widget _body(SharedChildAccess access) {
    final child = access.child;
    final permissions = access.permissions;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.purpleSurfaceLight,
            border: Border.all(color: AppColors.purpleBorder),
            borderRadius: AppRadius.mediumRadius,
          ),
          child: Row(
            children: [
              const Icon(Icons.group_outlined, color: AppColors.purpleHeading),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Được chia sẻ bởi ${access.ownerLabel}',
                      style: AppTextStyles.titleMedium.copyWith(color: AppColors.purpleHeading),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Vai trò của bạn: ${access.myRole.label}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.purpleBody),
                    ),
                  ],
                ),
              ),
              SharePill.permission(access.permissions),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Center(child: EmptyAvatar(label: child.name, size: 88, color: AppColors.purpleSurface)),
        const SizedBox(height: AppSpacing.md),
        Center(child: Text(child.name, style: AppTextStyles.h2)),
        const SizedBox(height: 2),
        Center(
          child: Text('${child.ageLabel(DateTime.now())} · ${child.gender.label}', style: AppTextStyles.bodySecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        CardContainer(
          child: Column(
            children: [
              _infoRow('Ngày sinh', DateFormat('dd/MM/yyyy').format(child.dob)),
              _infoRow('Giới tính', child.gender.label),
              _infoRow('Sinh non', child.isPremature ? 'Có' : 'Không'),
              if (child.gestationalWeeks != null) _infoRow('Tuổi thai khi sinh', '${child.gestationalWeeks} tuần'),
              if (child.birthWeightKg != null) _infoRow('Cân nặng sơ sinh', '${child.birthWeightKg} kg', last: true),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const ShareInfoNote(
          icon: Icons.lock_outline_rounded,
          text: 'Chỉ chủ hồ sơ mới được sửa thông tin cơ bản của bé.',
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Quyền của bạn', style: AppTextStyles.h3),
        const SizedBox(height: AppSpacing.sm),
        CardContainer(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 6),
          child: PermissionSummary(permissions: permissions),
        ),
        const SizedBox(height: AppSpacing.xl),
        OutlinedButton.icon(
          onPressed: () => _leave(access),
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text('Rời khỏi hồ sơ'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.dangerSurface),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _infoRow(String label, String value, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.md),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.bodySecondary)),
          Text(value, style: AppTextStyles.body),
        ],
      ),
    );
  }
}
