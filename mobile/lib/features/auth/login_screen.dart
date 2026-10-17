import '../../services/demo_store.dart';

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'auth_entrance_animation.dart';
import 'social_provider_icon.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.onSignUp,
    required this.onBack,
    this.onLoginSuccess,
    super.key,
  });

  final VoidCallback onSignUp;
  final VoidCallback onBack;
  final VoidCallback? onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _demoEmail = 'demo@trackchildren.vn';
  static const _demoPassword = DemoStore.password;
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController(text: _demoEmail);
  final _passwordController = TextEditingController(text: _demoPassword);
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _previewError;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateAccount(String? value) {
    final account = value?.trim() ?? '';
    if (account.isEmpty) return 'Vui lòng nhập email.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(account)) {
      return 'Email chưa đúng định dạng.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu.';
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _previewError = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    bool valid = false;
    try {
      valid = await DemoStore.instance.login(
        _accountController.text,
        _passwordController.text,
        useServer: true,
      );
    } catch (e) {
      if (mounted) setState(() => _previewError = e.toString());
    }
    if (!mounted) return;
    if (valid) {
      setState(() => _isLoading = false);
      widget.onLoginSuccess?.call();
      if (widget.onLoginSuccess != null) return;
    }
    setState(() {
      _isLoading = false;
      _previewError ??= 'Thông tin đăng nhập chưa đúng. Vui lòng kiểm tra lại.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 48,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: 'Quay lại',
                          onPressed: widget.onBack,
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        'Chào mừng bạn trở lại',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        'Đăng nhập để tiếp tục hành trình cùng bé.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 18),
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
                              const _FieldLabel('Email'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _accountController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.username,
                                  AutofillHints.email,
                                  AutofillHints.telephoneNumber,
                                ],
                                validator: _validateAccount,
                                decoration: _inputDecoration(
                                  hint: 'ban@email.com',
                                  icon: Icons.mail_outline_rounded,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const _FieldLabel('Mật khẩu'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                validator: _validatePassword,
                                onFieldSubmitted: (_) => _submit(),
                                decoration:
                                    _inputDecoration(
                                      hint: '••••••••',
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
                              const SizedBox(height: 12),
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        _showUnavailable('Khôi phục mật khẩu'),
                                    child: const Text('Quên mật khẩu?'),
                                  ),
                                ],
                              ),
                              if (_previewError != null) ...[
                                const SizedBox(height: 16),
                                Semantics(
                                  liveRegion: true,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFCE7E7),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.info_outline_rounded,
                                          size: 18,
                                          color: Color(0xFF9E4545),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _previewError!,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: const Color(
                                                    0xFF793B3B,
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 56,
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _isLoading ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox.square(
                                          dimension: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Đăng nhập'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Center(
                      child: Text(
                        'Hoặc tiếp tục với',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SocialLoginButton(
                      label: 'Tiếp tục với Google',
                      provider: SocialProvider.google,
                      onPressed: () => _showUnavailable('Google'),
                    ),
                    const SizedBox(height: 8),
                    _SocialLoginButton(
                      label: 'Tiếp tục với Apple',
                      provider: SocialProvider.apple,
                      onPressed: () => _showUnavailable('Apple'),
                    ),
                    const SizedBox(height: 8),
                    _SocialLoginButton(
                      label: 'Tiếp tục với Facebook',
                      provider: SocialProvider.facebook,
                      onPressed: () => _showUnavailable('Facebook'),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        'Tài khoản mẫu: $_demoEmail · $_demoPassword',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Bạn chưa có tài khoản? ',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed: widget.onSignUp,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                            ),
                            child: const Text('Tạo tài khoản'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Thông tin của bạn được dùng để đồng hành cùng bé.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
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

  void _showUnavailable(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$feature chưa được kết nối trong bản xem trước.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.labelLarge
        ?.copyWith(color: AppColors.textPrimary),
  );
}

InputDecoration _inputDecoration({
  required String hint,
  required IconData icon,
}) {
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

class _SocialLoginButton extends StatelessWidget {
  const _SocialLoginButton({
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
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    ),
  );
}
