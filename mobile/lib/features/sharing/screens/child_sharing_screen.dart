import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/card_container.dart';
import '../../../core/widgets/empty_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../models/child.dart';
import '../../../models/child_share.dart';
import '../../../services/service_locator.dart';
import '../../../services/sharing_service.dart';
import '../widgets/sharing_widgets.dart';

/// "Người cùng theo dõi" — the owner's list of who can see a child's
/// profile (F23.4), with change-permission / revoke / resend (F23.5).
class ChildSharingScreen extends StatefulWidget {
  const ChildSharingScreen({super.key, required this.childId});

  final String childId;

  @override
  State<ChildSharingScreen> createState() => _ChildSharingScreenState();
}

class _ChildSharingScreenState extends State<ChildSharingScreen> {
  final SharingService _service = ServiceLocator.sharingService;
  Child? _child;
  List<ChildShare>? _shares;

  @override
  void initState() {
    super.initState();
    ServiceLocator.childService.getChildren().then((children) {
      if (!mounted) return;
      setState(() => _child = children.where((c) => c.id == widget.childId).firstOrNull);
    });
    _load();
  }

  Future<void> _load() async {
    final shares = await _service.getShares(widget.childId);
    if (mounted) setState(() => _shares = shares);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _invite() async {
    final invited = await context.push<bool>('${AppRoutes.childShareInvite}/${widget.childId}');
    if (invited == true) await _load();
  }

  Future<void> _openMember(ChildShare share) async {
    final result = await showModalBottomSheet<_MemberAction>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _MemberSheet(
        share: share,
        // One open ownership offer per child at a time.
        canOfferOwnership: !(_shares ?? const <ChildShare>[]).any((s) => s.transferPending && s.id != share.id),
      ),
    );
    if (result == null || !mounted) return;
    switch (result) {
      case _ChangePermission(:final permissions):
        await _service.updatePermissions(share.id, permissions);
        _toast('Đã đổi quyền của ${share.displayName} thành "${permissions.label}"');
      case _Revoke():
        final ok = await confirmShareAction(
          context,
          title: 'Thu hồi quyền truy cập?',
          message: '${share.displayName} sẽ không xem được hồ sơ của bé nữa. '
              'Dữ liệu người này đã ghi nhận vẫn được giữ lại.',
          confirmLabel: 'Thu hồi',
        );
        if (!ok) return;
        await _service.revoke(share.id);
        _toast('Đã thu hồi quyền của ${share.displayName}');
      case _OfferOwnership():
        final ok = await _confirmOwnershipTransfer(share);
        if (!ok) return;
        await _service.requestOwnershipTransfer(share.id);
        _toast('Đã gửi yêu cầu chuyển quyền chủ hồ sơ cho ${share.displayName}');
      case _CancelOwnership():
        await _service.cancelOwnershipTransfer(share.id);
        _toast('Đã hủy yêu cầu chuyển quyền chủ hồ sơ');
    }
    await _load();
  }

  /// Explains what changes and re-asks for the password — handing a child's
  /// profile over is hard to undo (F23.11).
  Future<bool> _confirmOwnershipTransfer(ChildShare share) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => _OwnershipTransferDialog(share: share),
    );
    return ok ?? false;
  }

  Future<void> _resend(ChildShare share) async {
    await _service.resendInvite(share.id);
    _toast('Đã gửi lại lời mời, hiệu lực thêm 7 ngày');
    await _load();
  }

  Future<void> _cancelInvite(ChildShare share) async {
    final ok = await confirmShareAction(
      context,
      title: 'Hủy lời mời?',
      message: 'Mã mời ${share.inviteCode} sẽ không dùng được nữa.',
      confirmLabel: 'Hủy lời mời',
    );
    if (!ok) return;
    await _service.revoke(share.id);
    _toast('Đã hủy lời mời');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final shares = _shares;
    final user = ServiceLocator.authService.currentUser;
    final joined = shares?.where((s) => s.status == ShareStatus.accepted).toList() ?? const [];
    final pending = shares?.where((s) => s.status == ShareStatus.pending).toList() ?? const [];
    final atLimit = (shares?.length ?? 0) >= SharingService.maxMembersPerChild;

    return Scaffold(
      appBar: AppBar(title: const Text('Người cùng theo dõi')),
      body: shares == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (_child != null) ...[
                    Text('Hồ sơ bé ${_child!.name}', style: AppTextStyles.h2),
                    const SizedBox(height: 4),
                    Text(
                      'Mời bố hoặc người thân cùng theo dõi sự phát triển của bé.',
                      style: AppTextStyles.bodySecondary,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  CardContainer(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        EmptyAvatar(label: user.name, size: 44),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${user.name} (Bạn)', style: AppTextStyles.titleMedium),
                              const SizedBox(height: 2),
                              Text(user.email, style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                        const SharePill(
                          label: 'Chủ hồ sơ',
                          color: AppColors.purpleHeading,
                          background: AppColors.purpleSurface,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _sectionLabel('ĐÃ THAM GIA (${joined.length})'),
                  if (joined.isEmpty)
                    _emptyText('Chưa có ai tham gia hồ sơ của bé.')
                  else
                    for (final share in joined) ...[
                      _MemberTile(share: share, onTap: () => _openMember(share)),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  const SizedBox(height: AppSpacing.lg),
                  _sectionLabel('ĐANG CHỜ CHẤP NHẬN (${pending.length})'),
                  if (pending.isEmpty)
                    _emptyText('Không có lời mời nào đang chờ.')
                  else
                    for (final share in pending) ...[
                      _PendingTile(
                        share: share,
                        onResend: () => _resend(share),
                        onCancel: () => _cancelInvite(share),
                        onCopyCode: () {
                          Clipboard.setData(ClipboardData(text: share.inviteCode));
                          _toast('Đã sao chép mã ${share.inviteCode}');
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Mời người chăm sóc',
                    icon: Icons.person_add_alt_1_rounded,
                    onPressed: atLimit ? null : _invite,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ShareInfoNote(
                    text: atLimit
                        ? 'Hồ sơ đã chia sẻ tối đa ${SharingService.maxMembersPerChild} người. '
                            'Thu hồi quyền hoặc hủy một lời mời để mời người khác.'
                        : 'Mỗi hồ sơ bé chia sẻ được tối đa ${SharingService.maxMembersPerChild} người. '
                            'Chỉ chủ hồ sơ mới được sửa thông tin bé, xóa hồ sơ và mời thêm người.',
                  ),
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

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.share, required this.onTap});

  final ChildShare share;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CardContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          EmptyAvatar(label: share.displayName, size: 44),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(share.displayName, style: AppTextStyles.titleMedium),
                const SizedBox(height: 2),
                Text(
                  [share.role.label, if (share.contact != null) share.contact!].join(' · '),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          if (share.transferPending)
            const SharePill(label: 'Chờ nhận quyền chủ', color: AppColors.amberDark, background: AppColors.amberSurface)
          else
            SharePill.permission(share.permissions),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({
    required this.share,
    required this.onResend,
    required this.onCancel,
    required this.onCopyCode,
  });

  final ChildShare share;
  final VoidCallback onResend;
  final VoidCallback onCancel;
  final VoidCallback onCopyCode;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final expired = share.isExpired(now);
    return CardContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: AppColors.amberSurfaceLight,
      borderColor: AppColors.amberBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const EmptyAvatar(label: '?', size: 44, color: AppColors.amberSurface),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(share.contact ?? 'Mời qua mã', style: AppTextStyles.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${share.role.label} · ${share.permissions.label} · ${inviteExpiryText(share.expiresAt, now)}',
                      style: AppTextStyles.caption.copyWith(color: expired ? AppColors.danger : AppColors.amberDark),
                    ),
                  ],
                ),
              ),
              SharePill.pending(),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: onCopyCode,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Mã mời: ', style: AppTextStyles.caption),
                  Flexible(
                    child: Text(share.inviteCode, style: AppTextStyles.captionBold.copyWith(letterSpacing: 1)),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy_rounded, size: 14, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              children: [
                TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  child: const Text('Hủy lời mời'),
                ),
                TextButton(onPressed: onResend, child: const Text('Gửi lại')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnershipTransferDialog extends StatefulWidget {
  const _OwnershipTransferDialog({required this.share});
  final ChildShare share;

  @override
  State<_OwnershipTransferDialog> createState() => _OwnershipTransferDialogState();
}

class _OwnershipTransferDialogState extends State<_OwnershipTransferDialog> {
  final _passwordCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.share.displayName;
    return AlertDialog(
      title: const Text('Chuyển quyền chủ hồ sơ?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Khi $name chấp nhận:', style: AppTextStyles.bodySecondary),
            const SizedBox(height: AppSpacing.sm),
            for (final line in [
              '$name trở thành chủ hồ sơ: sửa thông tin bé, mời người, đổi quyền, thu hồi, xóa hồ sơ.',
              'Bạn trở thành người cùng theo dõi với quyền "Xem & sửa tất cả". Chủ mới có thể đổi quyền của bạn.',
              'Bạn không thể tự lấy lại quyền chủ, trừ khi chủ mới chuyển lại.',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(line, style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary))),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: InputDecoration(hintText: 'Nhập mật khẩu để xác nhận', errorText: _error),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
        TextButton(
          onPressed: () {
            // Mock check — the backend verifies the real password.
            if (_passwordCtrl.text.length < 6) {
              setState(() => _error = 'Mật khẩu không đúng');
              return;
            }
            Navigator.pop(context, true);
          },
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Gửi yêu cầu'),
        ),
      ],
    );
  }
}

sealed class _MemberAction {}

class _ChangePermission extends _MemberAction {
  _ChangePermission(this.permissions);
  final SharePermissions permissions;
}

class _Revoke extends _MemberAction {}

class _OfferOwnership extends _MemberAction {}

class _CancelOwnership extends _MemberAction {}

class _MemberSheet extends StatefulWidget {
  const _MemberSheet({required this.share, required this.canOfferOwnership});
  final ChildShare share;
  final bool canOfferOwnership;

  @override
  State<_MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends State<_MemberSheet> {
  late SharePermissions _permissions = widget.share.permissions;

  @override
  Widget build(BuildContext context) {
    final share = widget.share;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                EmptyAvatar(label: share.displayName, size: 48),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(share.displayName, style: AppTextStyles.h3),
                      Text(
                        [share.role.label, if (share.contact != null) share.contact!].join(' · '),
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Quyền truy cập theo từng mục', style: AppTextStyles.bodySecondary),
            const SizedBox(height: AppSpacing.sm),
            PermissionMatrix(
              value: _permissions,
              onChanged: (p) => setState(() => _permissions = p),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Lưu thay đổi',
              onPressed: _permissions == share.permissions || !_permissions.hasAnyAccess
                  ? null
                  : () => Navigator.pop(context, _ChangePermission(_permissions)),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.sm),
            if (share.transferPending) ...[
              ShareInfoNote(
                icon: Icons.hourglass_top_rounded,
                text: 'Đang chờ ${share.displayName} chấp nhận nhận quyền chủ hồ sơ.',
              ),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context, _CancelOwnership()),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Hủy yêu cầu chuyển quyền'),
                ),
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: widget.canOfferOwnership ? () => Navigator.pop(context, _OfferOwnership()) : null,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: Text(
                    widget.canOfferOwnership
                        ? 'Chuyển quyền chủ hồ sơ'
                        : 'Chuyển quyền chủ hồ sơ (đang có yêu cầu khác)',
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context, _Revoke()),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.person_remove_outlined, size: 18),
                label: const Text('Thu hồi quyền truy cập'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
