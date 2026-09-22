import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/otp_dialog.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/service_locator.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum ParentRole {
  mother('Mẹ'),
  father('Bố'),
  guardian('Người giám hộ khác');

  const ParentRole(this.label);
  final String label;
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  bool _rememberMe = true;
  bool _agreeTerms = false;
  ParentRole _role = ParentRole.mother;

  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _goToChildPicker() => context.push(AppRoutes.childPicker);

  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showError('Vui lòng nhập họ và tên');
      return;
    }
    if (_usernameCtrl.text.trim().isEmpty) {
      _showError('Vui lòng nhập tên đăng nhập');
      return;
    }
    if (!_emailCtrl.text.contains('@')) {
      _showError('Vui lòng nhập email hợp lệ');
      return;
    }
    if (_phoneCtrl.text.trim().length < 9) {
      _showError('Vui lòng nhập số điện thoại hợp lệ');
      return;
    }
    if (_passwordCtrl.text.length < 6) {
      _showError('Mật khẩu cần tối thiểu 6 ký tự');
      return;
    }
    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      _showError('Mật khẩu xác nhận không khớp');
      return;
    }
    if (!_agreeTerms) {
      _showError('Vui lòng đồng ý Điều khoản sử dụng & Chính sách quyền riêng tư');
      return;
    }

    final verified = await showOtpVerificationDialog(context, phone: _phoneCtrl.text.trim());
    if (!mounted || !verified) return;

    await ServiceLocator.authService.updateProfile(
      name: _nameCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
    );
    if (!mounted) return;

    // New account has no child profiles yet, so registration flows straight
    // into "Thêm hồ sơ bé mới" instead of the picker (which is for accounts
    // that already have at least one child).
    final addedChild = await context.push<bool>(AppRoutes.childProfileNew);
    if (!mounted) return;
    if (addedChild == true) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text('Bé Lớn Khôn', style: AppTextStyles.h1, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xxl),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceGreenLighter,
                  borderRadius: AppRadius.mediumRadius,
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(child: _TabButton('Đăng nhập', _isLogin, () => setState(() => _isLogin = true))),
                    Expanded(child: _TabButton('Đăng ký', !_isLogin, () => setState(() => _isLogin = false))),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (!_isLogin) ...[
                AppTextField(label: 'Họ và tên', hint: 'Nguyễn Thị A', controller: _nameCtrl),
                const SizedBox(height: AppSpacing.md),
                AppTextField(label: 'Tên đăng nhập', hint: 'mai_nguyen', controller: _usernameCtrl),
                const SizedBox(height: AppSpacing.md),
              ],
              AppTextField(label: 'Email', hint: 'ban@email.com', controller: _emailCtrl),
              if (!_isLogin) ...[
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Số điện thoại',
                  hint: '09xxxxxxxx',
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Vai trò với bé', style: AppTextStyles.bodySecondary),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final role in ParentRole.values) ...[
                      Expanded(child: _RoleChip(role: role, selected: _role == role, onTap: () => setState(() => _role = role))),
                      if (role != ParentRole.values.last) const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              AppTextField(label: 'Mật khẩu', hint: '••••••••', obscureText: true, controller: _passwordCtrl),
              if (!_isLogin) ...[
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Xác nhận mật khẩu',
                  hint: '••••••••',
                  obscureText: true,
                  controller: _confirmPasswordCtrl,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              if (_isLogin)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (v) => setState(() => _rememberMe = v ?? true),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('Ghi nhớ đăng nhập', style: AppTextStyles.caption),
                      ],
                    ),
                    Text('Quên mật khẩu?', style: AppTextStyles.caption.copyWith(color: AppColors.primaryDark)),
                  ],
                )
              else
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: _agreeTerms,
                        onChanged: (v) => setState(() => _agreeTerms = v ?? false),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Tôi đồng ý với Điều khoản sử dụng & Chính sách quyền riêng tư', style: AppTextStyles.caption),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: _isLogin ? 'Đăng nhập' : 'Đăng ký',
                onPressed: _isLogin ? _goToChildPicker : _register,
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Text('hoặc đăng nhập nhanh', style: AppTextStyles.caption),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _SocialButton('Tiếp tục với Google', Icons.g_mobiledata_rounded, _goToChildPicker),
              const SizedBox(height: AppSpacing.sm),
              _SocialButton('Tiếp tục với Apple', Icons.apple_rounded, _goToChildPicker),
              const SizedBox(height: AppSpacing.sm),
              _SocialButton('Tiếp tục với Facebook', Icons.facebook_rounded, _goToChildPicker),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton(this.label, this.active, this.onTap);
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.surface : Colors.transparent,
          borderRadius: AppRadius.smallRadius,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: active ? AppColors.primaryDark : AppColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role, required this.selected, required this.onTap});

  final ParentRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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

class _SocialButton extends StatelessWidget {
  const _SocialButton(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: AppColors.textSecondary),
      label: Text(label, style: AppTextStyles.body),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mediumRadius),
      ),
    );
  }
}
