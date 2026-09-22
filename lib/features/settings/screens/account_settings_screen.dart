import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_avatar.dart';
import '../../../core/widgets/otp_dialog.dart';
import '../../../services/service_locator.dart';
import '../../auth/screens/login_screen.dart' show ParentRole;

/// Dedicated "Cài đặt tài khoản" screen: the mother's own account info
/// (previously just a static header inside [SettingsScreen]) now lives here
/// as an editable form (họ tên, email, số điện thoại, vai trò với bé).
/// Account-level actions (đổi mật khẩu, ngôn ngữ, chính sách quyền riêng tư)
/// stay in [SettingsScreen] instead.
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _editing = false;
  ParentRole _role = ParentRole.mother;

  late final _nameCtrl = TextEditingController(text: ServiceLocator.authService.currentUser.name);
  late final _usernameCtrl = TextEditingController(text: ServiceLocator.authService.currentUser.username);
  late final _emailCtrl = TextEditingController(text: ServiceLocator.authService.currentUser.email);
  final _phoneCtrl = TextEditingController();
  late String _savedPhone;

  @override
  void initState() {
    super.initState();
    _savedPhone = _phoneCtrl.text;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _onEditIconTap() async {
    if (!_editing) {
      setState(() => _editing = true);
      return;
    }
    await _save();
  }

  Future<void> _save() async {
    final phoneChanged = _phoneCtrl.text.trim() != _savedPhone;
    if (phoneChanged) {
      final verified = await showOtpVerificationDialog(context, phone: _phoneCtrl.text.trim());
      if (!mounted) return;
      if (!verified) return; // keep editing, don't apply the phone change
    }

    await ServiceLocator.authService.updateProfile(
      name: _nameCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
    );
    if (!mounted) return;

    setState(() {
      _savedPhone = _phoneCtrl.text.trim();
      _editing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu thông tin tài khoản')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt tài khoản'),
        actions: [
          IconButton(
            onPressed: _onEditIconTap,
            icon: Icon(_editing ? Icons.check_rounded : Icons.edit_outlined),
            tooltip: _editing ? 'Lưu' : 'Sửa thông tin',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(child: EmptyAvatar(label: _nameCtrl.text, size: 72)),
          const SizedBox(height: AppSpacing.xxl),
          AppTextField(
            label: 'Họ và tên',
            controller: _nameCtrl,
            keyboardType: TextInputType.name,
            enabled: _editing,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Tên đăng nhập',
            controller: _usernameCtrl,
            enabled: _editing,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Email',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            enabled: _editing,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Số điện thoại',
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            enabled: _editing,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Vai trò với bé', style: AppTextStyles.bodySecondary),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final role in ParentRole.values) ...[
                Expanded(
                  child: _RoleChip(
                    role: role,
                    selected: _role == role,
                    enabled: _editing,
                    onTap: () => setState(() => _role = role),
                  ),
                ),
                if (role != ParentRole.values.last) const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role, required this.selected, required this.enabled, required this.onTap});

  final ParentRole role;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          borderRadius: AppRadius.smallRadius,
        ),
        child: Text(
          role.label,
          style: AppTextStyles.caption.copyWith(
            color: selected ? Colors.white : AppColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
