import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/bottom_nav_bar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_avatar.dart';
import '../../../services/service_locator.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _biometric = false;

  // Deviation: the prototype leaves "Chính sách quyền riêng tư" and "Xóa
  // toàn bộ dữ liệu" as static/no-op rows. A settings screen with dead rows
  // would look broken in a real app, so each shows a minimal confirmation
  // dialog/snackbar instead of navigating anywhere real.
  void _showStub(String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text('Nội dung này sẽ được bổ sung trong bản cập nhật tiếp theo.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Đóng')),
        ],
      ),
    );
  }

  void _changePassword() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi mật khẩu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(label: 'Mật khẩu hiện tại', obscureText: true, controller: currentCtrl),
            const SizedBox(height: AppSpacing.md),
            AppTextField(label: 'Mật khẩu mới', obscureText: true, controller: newCtrl),
            const SizedBox(height: AppSpacing.md),
            AppTextField(label: 'Xác nhận mật khẩu mới', obscureText: true, controller: confirmCtrl),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Hủy')),
          TextButton(
            onPressed: () {
              if (newCtrl.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mật khẩu mới cần tối thiểu 6 ký tự')),
                );
                return;
              }
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mật khẩu xác nhận không khớp')),
                );
                return;
              }
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã đổi mật khẩu')),
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ServiceLocator.authService.currentUser;
    return AppShellScaffold(
      tab: AppTab.more,
      appBar: AppBar(title: const Text('Cài đặt & Quyền riêng tư')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          InkWell(
            onTap: () => context.push(AppRoutes.accountSettings),
            borderRadius: AppRadius.smallRadius,
            child: Row(
              children: [
                EmptyAvatar(label: user.name, size: 56),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.username, style: AppTextStyles.titleMedium),
                      const SizedBox(height: 2),
                      Text(user.email, style: AppTextStyles.caption),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _sectionLabel('TÀI KHOẢN'),
          _row('Đổi mật khẩu', Icons.lock_outline_rounded, _changePassword),
          _row('Ngôn ngữ: Tiếng Việt', Icons.language_rounded, () => _showStub('Ngôn ngữ')),
          _row('Chính sách quyền riêng tư', Icons.privacy_tip_outlined, () => _showStub('Chính sách quyền riêng tư')),
          const SizedBox(height: AppSpacing.xl),
          _sectionLabel('HỒ SƠ TRẺ'),
          _row('Quản lý hồ sơ trẻ', Icons.child_care_rounded, () => context.push(AppRoutes.childProfile)),
          _row('Thêm bé mới', Icons.person_add_alt_rounded, () => context.push(AppRoutes.childProfileNew)),
          const SizedBox(height: AppSpacing.xl),
          _sectionLabel('ỨNG DỤNG'),
          _switchRow('Thông báo & nhắc nhở', _notifications, (v) => setState(() => _notifications = v)),
          const SizedBox(height: AppSpacing.xl),
          _sectionLabel('QUYỀN RIÊNG TƯ & BẢO MẬT'),
          _switchRow('Khóa ứng dụng bằng sinh trắc', _biometric, (v) => setState(() => _biometric = v)),
          _row('Xóa toàn bộ dữ liệu', Icons.delete_outline_rounded, () => _showStub('Xóa toàn bộ dữ liệu'), color: AppColors.danger),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.login),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.dangerSurface),
            ),
            child: const Text('Đăng xuất'),
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(child: Text('Bé Lớn Khôn · phiên bản 1.0.0', style: AppTextStyles.caption)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(label, style: AppTextStyles.captionBold),
    );
  }

  Widget _row(String label, IconData icon, VoidCallback onTap, {Color color = AppColors.textPrimary}) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smallRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: AppTextStyles.body.copyWith(color: color))),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: AppTextStyles.body),
      value: value,
      onChanged: onChanged,
    );
  }
}
