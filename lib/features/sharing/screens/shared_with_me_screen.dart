import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/card_container.dart';
import '../../../core/widgets/empty_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../models/child.dart';
import '../../../models/child_share.dart';
import '../../../services/service_locator.dart';
import '../widgets/sharing_widgets.dart';

/// "Hồ sơ được chia sẻ với tôi" — the invitee side: pending invitations to
/// accept/decline (F23.3), join by code, and the profiles already joined
/// (entry to F23.6).
class SharedWithMeScreen extends StatefulWidget {
  const SharedWithMeScreen({super.key});

  @override
  State<SharedWithMeScreen> createState() => _SharedWithMeScreenState();
}

class _SharedWithMeScreenState extends State<SharedWithMeScreen> {
  final _codeCtrl = TextEditingController();
  List<SharedChildAccess>? _items;
  bool _checkingCode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await ServiceLocator.sharingService.getSharedWithMe();
    if (mounted) setState(() => _items = items);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _accept(SharedChildAccess access) async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => _AcceptInviteDialog(access: access),
    );
    if (agreed != true || !mounted) return;
    await ServiceLocator.sharingService.respondToInvite(access.id, accept: true);
    _toast('Đã tham gia hồ sơ bé ${access.child.name}');
    await _load();
  }

  Future<void> _decline(SharedChildAccess access) async {
    final ok = await confirmShareAction(
      context,
      title: 'Từ chối lời mời?',
      message: '${access.ownerLabel} sẽ nhận được thông báo bạn đã từ chối.',
      confirmLabel: 'Từ chối',
    );
    if (!ok) return;
    await ServiceLocator.sharingService.respondToInvite(access.id, accept: false);
    _toast('Đã từ chối lời mời');
    await _load();
  }

  Future<void> _respondOwnership(SharedChildAccess access, {required bool accept}) async {
    final ok = await confirmShareAction(
      context,
      title: accept ? 'Nhận quyền chủ hồ sơ?' : 'Từ chối nhận quyền chủ?',
      message: accept
          ? 'Bạn sẽ là chủ hồ sơ bé ${access.child.name}: sửa thông tin bé, mời người, đổi quyền và xóa hồ sơ. '
              '${access.ownerLabel} vẫn tiếp tục theo dõi bé với quyền "Xem & sửa tất cả".'
          : '${access.ownerLabel} vẫn là chủ hồ sơ, quyền của bạn giữ nguyên.',
      confirmLabel: accept ? 'Nhận quyền chủ' : 'Từ chối',
    );
    if (!ok) return;
    final child = await ServiceLocator.sharingService.respondToOwnershipOffer(access.id, accept: accept);
    if (child != null) {
      await ServiceLocator.childService.adoptChild(child);
      final active = ServiceLocator.activeChild;
      if (active.value?.child.id == child.id) active.selectOwn(child);
    }
    if (!mounted) return;
    _toast(accept ? 'Bạn đã là chủ hồ sơ bé ${access.child.name}' : 'Đã từ chối nhận quyền chủ hồ sơ');
    await _load();
  }

  Future<void> _joinByCode() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      _toast('Vui lòng nhập mã mời');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _checkingCode = true);
    final access = await ServiceLocator.sharingService.findInviteByCode(code);
    if (!mounted) return;
    setState(() => _checkingCode = false);
    if (access == null) {
      _toast('Mã mời không đúng hoặc đã hết hạn');
      return;
    }
    _codeCtrl.clear();
    await _accept(access);
  }

  /// Opens Trang chủ for the shared child, the same dashboard as own
  /// children (cards the owner didn't grant are hidden there).
  void _openHome(SharedChildAccess access) {
    ServiceLocator.activeChild.selectShared(access);
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final pending = items?.where((a) => a.status == ShareStatus.pending).toList() ?? const [];
    final joined = items?.where((a) => a.status == ShareStatus.accepted).toList() ?? const [];
    final offers = joined.where((a) => a.ownershipOffered).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ được chia sẻ với tôi')),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (offers.isNotEmpty) ...[
                    _sectionLabel('YÊU CẦU NHẬN QUYỀN CHỦ HỒ SƠ (${offers.length})'),
                    for (final access in offers) ...[
                      _OwnershipOfferCard(
                        access: access,
                        onAccept: () => _respondOwnership(access, accept: true),
                        onDecline: () => _respondOwnership(access, accept: false),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  _sectionLabel('LỜI MỜI ĐANG CHỜ (${pending.length})'),
                  if (pending.isEmpty)
                    _emptyText('Bạn không có lời mời nào.')
                  else
                    for (final access in pending) ...[
                      _InviteCard(
                        access: access,
                        onAccept: () => _accept(access),
                        onDecline: () => _decline(access),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  const SizedBox(height: AppSpacing.lg),
                  _sectionLabel('THAM GIA BẰNG MÃ MỜI'),
                  CardContainer(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeCtrl,
                            textCapitalization: TextCapitalization.characters,
                            style: AppTextStyles.body.copyWith(letterSpacing: 1.5),
                            decoration: const InputDecoration(hintText: 'VD: BLK-8Q2MX'),
                            onSubmitted: (_) => _joinByCode(),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        PrimaryButton(
                          label: _checkingCode ? '…' : 'Tham gia',
                          fullWidth: false,
                          onPressed: _checkingCode ? null : _joinByCode,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _sectionLabel('HỒ SƠ ĐANG THEO DÕI (${joined.length})'),
                  if (joined.isEmpty)
                    _emptyText('Chưa có hồ sơ bé nào được chia sẻ với bạn.')
                  else
                    for (final access in joined) ...[
                      SharedChildTile(access: access, onTap: () => _openHome(access)),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(label, style: AppTextStyles.captionBold),
      );

  Widget _emptyText(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(text, style: AppTextStyles.caption),
      );
}

/// Row for a joined shared profile — reused by the child pickers so shared
/// children look the same everywhere.
class SharedChildTile extends StatelessWidget {
  const SharedChildTile({super.key, required this.access, required this.onTap, this.selected = false});

  final SharedChildAccess access;
  final VoidCallback onTap;

  /// Currently the app-wide selected child (shows a check instead of ›).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final child = access.child;
    return CardContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          EmptyAvatar(label: child.name, size: 48, color: AppColors.purpleSurface),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(child.name, style: AppTextStyles.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '${child.ageLabel(DateTime.now())} · ${child.gender.label}',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 2),
                Text(
                  'Được chia sẻ bởi ${access.ownerLabel}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.purpleHeading),
                ),
              ],
            ),
          ),
          SharePill.permission(access.permissions),
          selected
              ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
              : const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

/// F23.11 invitee side: the owner wants to hand this profile over.
class _OwnershipOfferCard extends StatelessWidget {
  const _OwnershipOfferCard({required this.access, required this.onAccept, required this.onDecline});

  final SharedChildAccess access;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return CardContainer(
      color: AppColors.purpleSurfaceLight,
      borderColor: AppColors.purpleBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EmptyAvatar(label: access.child.name, size: 48, color: AppColors.purpleSurface),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: AppTextStyles.body,
                    children: [
                      TextSpan(text: access.ownerLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const TextSpan(text: ' muốn chuyển quyền chủ hồ sơ bé '),
                      TextSpan(text: access.child.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const TextSpan(text: ' cho bạn'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const ShareInfoNote(
            icon: Icons.swap_horiz_rounded,
            text: 'Chủ hồ sơ được sửa thông tin bé, mời người, đổi quyền, thu hồi và xóa hồ sơ.',
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: SecondaryButton(label: 'Từ chối', color: AppColors.danger, onPressed: onDecline)),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: PrimaryButton(label: 'Nhận quyền', color: AppColors.purple, onPressed: onAccept)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.access, required this.onAccept, required this.onDecline});

  final SharedChildAccess access;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final child = access.child;
    return CardContainer(
      color: AppColors.amberSurfaceLight,
      borderColor: AppColors.amberBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EmptyAvatar(label: child.name, size: 48, color: AppColors.amberSurface),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: AppTextStyles.body,
                        children: [
                          TextSpan(text: access.ownerLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const TextSpan(text: ' mời bạn cùng theo dõi bé '),
                          TextSpan(text: child.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${child.ageLabel(DateTime.now())} · ${child.gender.label}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 6,
            children: [
              SharePill.permission(access.permissions),
              SharePill(
                label: 'Vai trò: ${access.myRole.label}',
                color: AppColors.textSecondary,
                background: AppColors.background,
              ),
              SharePill(
                label: inviteExpiryText(access.expiresAt, DateTime.now()),
                color: AppColors.amberDark,
                background: AppColors.amberSurface,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: SecondaryButton(label: 'Từ chối', color: AppColors.danger, onPressed: onDecline)),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: PrimaryButton(label: 'Chấp nhận', onPressed: onAccept)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Invitees must accept the data policy before seeing a child's data
/// (rule tied to F01.5), so accepting goes through this checkbox dialog.
class _AcceptInviteDialog extends StatefulWidget {
  const _AcceptInviteDialog({required this.access});
  final SharedChildAccess access;

  @override
  State<_AcceptInviteDialog> createState() => _AcceptInviteDialogState();
}

class _AcceptInviteDialogState extends State<_AcceptInviteDialog> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final access = widget.access;
    return AlertDialog(
      title: Text('Tham gia hồ sơ bé ${access.child.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${access.ownerLabel} cho bạn quyền:', style: AppTextStyles.bodySecondary),
          const SizedBox(height: AppSpacing.sm),
          PermissionSummary(permissions: access.permissions),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            onTap: () => setState(() => _agreed = !_agreed),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(value: _agreed, onChanged: (v) => setState(() => _agreed = v ?? false)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tôi đồng ý Điều khoản sử dụng & Chính sách dữ liệu, và cam kết bảo mật thông tin của bé.',
                    style: AppTextStyles.caption,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Để sau')),
        TextButton(
          onPressed: _agreed ? () => Navigator.pop(context, true) : null,
          child: const Text('Tham gia'),
        ),
      ],
    );
  }
}
