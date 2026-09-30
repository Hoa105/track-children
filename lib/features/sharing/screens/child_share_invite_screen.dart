import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../models/child.dart';
import '../../../models/child_share.dart';
import '../../../models/parent_role.dart';
import '../../../services/service_locator.dart';
import '../widgets/sharing_widgets.dart';

enum _InviteMethod { contact, code }

/// "Mời người chăm sóc" — invite by email/SĐT or by a shareable code
/// (F23.1) and pick the access level up front (F23.2). Pops `true` once an
/// invite was created so the member list can refresh.
class ChildShareInviteScreen extends StatefulWidget {
  const ChildShareInviteScreen({super.key, required this.childId});

  final String childId;

  @override
  State<ChildShareInviteScreen> createState() => _ChildShareInviteScreenState();
}

class _ChildShareInviteScreenState extends State<ChildShareInviteScreen> {
  final _contactCtrl = TextEditingController();
  _InviteMethod _method = _InviteMethod.contact;
  ParentRole _role = ParentRole.father;
  SharePermissions _permissions = SharePermissions.viewOnly;
  Child? _child;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    ServiceLocator.childService.getChildren().then((children) {
      if (!mounted) return;
      setState(() => _child = children.where((c) => c.id == widget.childId).firstOrNull);
    });
  }

  @override
  void dispose() {
    _contactCtrl.dispose();
    super.dispose();
  }

  String? _validateContact(String value) {
    if (value.isEmpty) return 'Vui lòng nhập email hoặc số điện thoại';
    final isEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
    final isPhone = RegExp(r'^0\d{9,10}$').hasMatch(value.replaceAll(' ', ''));
    if (!isEmail && !isPhone) return 'Email hoặc số điện thoại chưa đúng định dạng';
    if (value.toLowerCase() == ServiceLocator.authService.currentUser.email.toLowerCase()) {
      return 'Không thể tự mời chính mình';
    }
    return null;
  }

  Future<void> _submit() async {
    final contact = _contactCtrl.text.trim();
    if (_method == _InviteMethod.contact) {
      final error = _validateContact(contact);
      if (error != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error)));
        return;
      }
    }
    setState(() => _sending = true);
    final share = await ServiceLocator.sharingService.invite(
      childId: widget.childId,
      contact: _method == _InviteMethod.contact ? contact : null,
      role: _role,
      permissions: _permissions,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _InviteSentDialog(share: share, childName: _child?.name ?? 'bé'),
    );
    if (mounted) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final childName = _child?.name ?? 'bé';
    return Scaffold(
      appBar: AppBar(title: const Text('Mời người chăm sóc')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Mời người thân cùng theo dõi $childName', style: AppTextStyles.h2),
            const SizedBox(height: 4),
            Text(
              'Người được mời cần có tài khoản Bé Lớn Khôn. Nếu chưa có, họ sẽ được hướng dẫn đăng ký khi mở lời mời.',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Cách mời', style: AppTextStyles.bodySecondary),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AppColors.surfaceGreenLighter, borderRadius: AppRadius.mediumRadius),
              child: Row(
                children: [
                  Expanded(
                    child: _MethodTab(
                      label: 'Email / SĐT',
                      icon: Icons.alternate_email_rounded,
                      active: _method == _InviteMethod.contact,
                      onTap: () => setState(() => _method = _InviteMethod.contact),
                    ),
                  ),
                  Expanded(
                    child: _MethodTab(
                      label: 'Mã mời',
                      icon: Icons.qr_code_2_rounded,
                      active: _method == _InviteMethod.code,
                      onTap: () => setState(() => _method = _InviteMethod.code),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_method == _InviteMethod.contact)
              AppTextField(
                label: 'Email hoặc số điện thoại của người được mời',
                hint: 'bo.nam@gmail.com hoặc 09xxxxxxxx',
                controller: _contactCtrl,
                keyboardType: TextInputType.emailAddress,
              )
            else
              const ShareInfoNote(
                icon: Icons.qr_code_2_rounded,
                text: 'Ứng dụng sẽ tạo một mã mời. Bạn gửi mã này cho người thân qua Zalo, tin nhắn…, '
                    'họ nhập mã ở mục "Hồ sơ được chia sẻ với tôi" để tham gia.',
              ),
            const SizedBox(height: AppSpacing.xl),
            Text('Vai trò của người được mời với bé', style: AppTextStyles.bodySecondary),
            const SizedBox(height: 6),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final role in ParentRole.values)
                  AppChip(label: role.label, selected: _role == role, onTap: () => setState(() => _role = role)),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Quyền truy cập theo từng mục', style: AppTextStyles.bodySecondary),
            const SizedBox(height: 6),
            PermissionMatrix(
              value: _permissions,
              onChanged: (p) => setState(() => _permissions = p),
            ),
            const SizedBox(height: AppSpacing.md),
            const ShareInfoNote(
              text: 'Lời mời có hiệu lực 7 ngày. Bạn có thể đổi quyền hoặc thu hồi bất cứ lúc nào '
                  'trong mục "Người cùng theo dõi".',
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: _sending
                  ? 'Đang gửi…'
                  : (_method == _InviteMethod.contact ? 'Gửi lời mời' : 'Tạo mã mời'),
              icon: _method == _InviteMethod.contact ? Icons.send_rounded : Icons.qr_code_2_rounded,
              onPressed: _sending || !_permissions.hasAnyAccess ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodTab extends StatelessWidget {
  const _MethodTab({required this.label, required this.icon, required this.active, required this.onTap});

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primaryDark : AppColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.surface : Colors.transparent,
          borderRadius: AppRadius.smallRadius,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteSentDialog extends StatelessWidget {
  const _InviteSentDialog({required this.share, required this.childName});

  final ChildShare share;
  final String childName;

  @override
  Widget build(BuildContext context) {
    final byContact = share.contact != null;
    return AlertDialog(
      icon: const Icon(Icons.mark_email_read_outlined, color: AppColors.primary, size: 40),
      title: Text(byContact ? 'Đã gửi lời mời' : 'Đã tạo mã mời', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            byContact
                ? 'Lời mời theo dõi $childName đã được gửi tới ${share.contact}. '
                    'Người nhận cũng có thể tham gia bằng mã dưới đây.'
                : 'Gửi mã này cho người thân để họ tham gia hồ sơ của $childName.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceGreenLighter,
              border: Border.all(color: AppColors.primary),
              borderRadius: AppRadius.mediumRadius,
            ),
            child: Text(
              share.inviteCode,
              textAlign: TextAlign.center,
              style: AppTextStyles.h2.copyWith(color: AppColors.primaryDark, letterSpacing: 3),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${share.role.label} · ${share.permissions.label} · hiệu lực đến ${DateFormat('dd/MM/yyyy').format(share.expiresAt)}',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: share.inviteCode));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Đã sao chép mã ${share.inviteCode}')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Sao chép mã'),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Xong')),
      ],
    );
  }
}
