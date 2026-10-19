import '../../services/auth_service.dart';

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'auth_entrance_animation.dart';
import 'otp_dialog.dart';
import 'parent_role.dart';
import 'social_provider_icon.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({
    required this.onLogin,
    required this.onChildProfilePreview,
    super.key,
  });

  final VoidCallback onLogin;
  final VoidCallback onChildProfilePreview;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  ParentRole _parentRole = ParentRole.mother;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _attemptedSubmit = false;
  bool _acceptedTerms = false;
  String? _previewMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) =>
      (value?.trim().isNotEmpty ?? false) && value!.trim().length <= 150
      ? null
      : 'Tên hiển thị cần có 1–150 ký tự.';

  String? _validateUsername(String? value) =>
      RegExp(r'^[a-z0-9_.]{3,30}$').hasMatch((value ?? '').trim().toLowerCase())
      ? null
      : 'Tên người dùng gồm 3–30 ký tự: a-z, 0-9, _ hoặc dấu chấm.';

  String? _validatePhone(String? value) {
    var phone = (value ?? '').replaceAll(RegExp(r'[\s()-]'), '');
    if (phone.isEmpty) return 'Vui lòng nhập số điện thoại.';
    if (phone.startsWith('0')) phone = '+84${phone.substring(1)}';
    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone)) {
      return 'Số điện thoại chưa đúng định dạng.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Vui lòng nhập email.';
    if (email.length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Email chưa đúng định dạng.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu.';
    if (value.length < 6 || value.length > 128) {
      return 'Mật khẩu cần có 6–128 ký tự.';
    }
    if (!RegExp(r'[a-z]').hasMatch(value) ||
        !RegExp(r'[A-Z]').hasMatch(value) ||
        !RegExp(r'[0-9]').hasMatch(value) ||
        !RegExp(r'[^a-zA-Z0-9\s]').hasMatch(value)) {
      return 'Mật khẩu cần có chữ thường, chữ hoa, chữ số và ký tự đặc biệt.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng xác nhận mật khẩu.';
    if (value != _passwordController.text) return 'Mật khẩu chưa trùng khớp.';
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    final isFormValid = _formKey.currentState!.validate();
    setState(() {
      _previewMessage = null;
      _attemptedSubmit = true;
    });
    if (!_acceptedTerms) return;
    if (!isFormValid) return;

    setState(() => _isSubmitting = true);
    try {
      final docs = await AuthService.instance.documents();
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Điều khoản và chính sách'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final doc in docs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      '${doc['docType']} — ${doc['version']}\n${doc['content']}',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Đồng ý điều khoản bắt buộc'),
            ),
          ],
        ),
      );
      if (accepted != true) return;
      if (!mounted) return;
      setState(() => _isSubmitting = true);
      final challenge = await AuthService.instance.register({
        'fullName': _nameController.text.trim(),
        'username': _usernameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'relationship': _parentRole.name,
        'consents': [
          for (final doc in docs.where((d) => d['isRequired'] == true))
            {'documentId': doc['id'], 'isAccepted': true},
        ],
      });
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (challenge['requiresOtp'] == false) {
        widget.onChildProfilePreview();
        return;
      }
      final verified = await showOtpVerificationDialog(
        context,
        challenge: challenge,
      );
      if (mounted && verified == true) widget.onChildProfilePreview();
    } catch (e) {
      if (mounted) {
        setState(() => _previewMessage = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsTerms = _attemptedSubmit && !_acceptedTerms;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 48,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: 'Quay lại đăng nhập',
                          onPressed: widget.onLogin,
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        'Tạo tài khoản',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        'Bắt đầu lưu lại hành trình chăm sóc bé của gia đình.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                    AuthEntranceCard(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A23332E),
                              blurRadius: 16,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionLabel('Họ và tên'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                validator: _validateName,
                                decoration: _signUpInput(
                                  hint: 'Nguyễn Thị A',
                                  icon: Icons.badge_outlined,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const _SectionLabel('Tên đăng nhập'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _usernameController,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                validator: _validateUsername,
                                decoration: _signUpInput(
                                  hint: 'mai_nguyen',
                                  icon: Icons.alternate_email_rounded,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const _SectionLabel('Email'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                validator: _validateEmail,
                                decoration: _signUpInput(
                                  hint: 'ban@email.com',
                                  icon: Icons.mail_outline_rounded,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const _SectionLabel('Số điện thoại'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.telephoneNumber,
                                ],
                                validator: _validatePhone,
                                decoration: _signUpInput(
                                  hint: '09xxxxxxxx',
                                  icon: Icons.phone_outlined,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const _SectionLabel('Mật khẩu'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                validator: _validatePassword,
                                decoration:
                                    _signUpInput(
                                      hint: 'Tối thiểu 6 ký tự',
                                      icon: Icons.lock_outline_rounded,
                                    ).copyWith(
                                      suffixIcon: IconButton(
                                        tooltip: _obscurePassword
                                            ? 'Hiện mật khẩu'
                                            : 'Ẩn mật khẩu',
                                        onPressed: () => setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        }),
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                      ),
                                    ),
                              ),
                              const SizedBox(height: 8),
                              const _SectionLabel('Xác nhận mật khẩu'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                validator: _validateConfirmPassword,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: _signUpInput(
                                  hint: 'Nhập lại mật khẩu',
                                  icon: Icons.lock_outline_rounded,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const _SectionLabel('Vai trò với bé'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  for (final role in ParentRole.values)
                                    ChoiceChip(
                                      label: Text(role.label),
                                      selected: _parentRole == role,
                                      onSelected: (_) =>
                                          setState(() => _parentRole = role),
                                      selectedColor: AppColors.primarySoft,
                                      checkmarkColor: AppColors.primary,
                                      side: BorderSide(
                                        color: _parentRole == role
                                            ? AppColors.primary
                                            : AppColors.border,
                                      ),
                                      labelStyle: TextStyle(
                                        color: _parentRole == role
                                            ? AppColors.primaryDark
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Material(
                                color: Colors.transparent,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: _acceptedTerms,
                                      onChanged: (value) => setState(
                                        () => _acceptedTerms = value ?? false,
                                      ),
                                      activeColor: AppColors.primary,
                                    ),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => setState(
                                          () =>
                                              _acceptedTerms = !_acceptedTerms,
                                        ),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          child: Text(
                                            'Tôi đồng ý với Điều khoản sử dụng & Chính sách quyền riêng tư',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (needsTerms)
                                const _InlineError(
                                  'Vui lòng đồng ý với các điều khoản.',
                                ),
                              if (_previewMessage != null) ...[
                                const SizedBox(height: 16),
                                _PreviewNotice(message: _previewMessage!),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: widget.onChildProfilePreview,
                                    icon: const Icon(
                                      Icons.arrow_forward_rounded,
                                    ),
                                    label: const Text('Xem giao diện hồ sơ bé'),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 22),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: FilledButton(
                                  onPressed: _isSubmitting ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox.square(
                                          dimension: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Đăng ký'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        'Hoặc tiếp tục với',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SocialAuthButton(
                      label: 'Tiếp tục với Google',
                      provider: SocialProvider.google,
                      onPressed: () => _showUnavailable('Google'),
                    ),
                    const SizedBox(height: 8),
                    _SocialAuthButton(
                      label: 'Tiếp tục với Apple',
                      provider: SocialProvider.apple,
                      onPressed: () => _showUnavailable('Apple'),
                    ),
                    const SizedBox(height: 8),
                    _SocialAuthButton(
                      label: 'Tiếp tục với Facebook',
                      provider: SocialProvider.facebook,
                      onPressed: () => _showUnavailable('Facebook'),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Đã có tài khoản? ',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed: widget.onLogin,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                            ),
                            child: const Text('Đăng nhập'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showUnavailable(String provider) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$provider chưa được kết nối trong bản xem trước.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _SocialAuthButton extends StatelessWidget {
  const _SocialAuthButton({
    required this.label,
    required this.provider,
    required this.onPressed,
  });

  final String label;
  final SocialProvider provider;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 48,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SocialProviderIcon(provider: provider),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.labelLarge
        ?.copyWith(color: AppColors.textPrimary),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: const Color(0xFF9E4545)),
      ),
    ),
  );
}

class _PreviewNotice extends StatelessWidget {
  const _PreviewNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppColors.primaryDark),
      ),
    ),
  );
}

InputDecoration _signUpInput({required String hint, required IconData icon}) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, size: 21),
    filled: true,
    fillColor: const Color(0xFFFCFBF8),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFB94D4D)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFB94D4D), width: 1.5),
    ),
  );
}
