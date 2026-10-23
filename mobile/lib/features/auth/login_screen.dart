import '../../services/auth_service.dart';
import 'otp_dialog.dart';

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'auth_entrance_animation.dart';
import 'forgot_password_sheet.dart';
import 'social_provider_icon.dart';
import 'auth_form_style.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.onSignUp,
    required this.onBack,
    this.onLoginSuccess,
    this.passwordRecovery,
    super.key,
  });

  final VoidCallback onSignUp;
  final VoidCallback onBack;
  final VoidCallback? onLoginSuccess;
  final PasswordRecovery? passwordRecovery;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;
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
    if (account.isEmpty)
      return 'Vui l\u00f2ng nh\u1eadp email ho\u1eb7c s\u1ed1 \u0111i\u1ec7n tho\u1ea1i.';
    if (account.contains('@')) {
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(account)) {
        return 'Email ch\u01b0a \u0111\u00fang \u0111\u1ecbnh d\u1ea1ng.';
      }
    } else {
      var phone = account.replaceAll(RegExp(r'[\s()-]'), '');
      if (phone.startsWith('0')) phone = '+84${phone.substring(1)}';
      if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone)) {
        return 'S\u1ed1 \u0111i\u1ec7n tho\u1ea1i ch\u01b0a \u0111\u00fang \u0111\u1ecbnh d\u1ea1ng.';
      }
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu.';
    return null;
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _previewError = null;
    });

    bool valid = false;
    try {
      await AuthService.instance.login(
        _accountController.text,
        _passwordController.text,
        remember: _rememberMe,
      );
      valid = true;
    } on AuthException catch (e) {
      if (e.code == 'VERIFICATION_REQUIRED' && mounted) {
        setState(() => _isLoading = false);
        valid =
            await showOtpVerificationDialog(
              context,
              challenge: Map<String, dynamic>.from(
                e.details['registration'] as Map,
              ),
              remember: _rememberMe,
            ) ==
            true;
      } else {
        if (mounted) {
          setState(
            () => _previewError = e.code == 'INVALID_CREDENTIALS'
                ? 'Email/s\u1ed1 \u0111i\u1ec7n tho\u1ea1i ho\u1eb7c m\u1eadt kh\u1ea9u kh\u00f4ng \u0111\u00fang'
                : e.toString(),
          );
        }
      }
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
      _previewError ??= 'Chưa hoàn tất đăng nhập.';
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
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
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
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        'Chào mừng bạn trở lại',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
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
                              const _FieldLabel(
                                'Email ho\u1eb7c s\u1ed1 \u0111i\u1ec7n tho\u1ea1i',
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _accountController,
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 15,
                                  color: Color(0xFF172B35),
                                ),
                                keyboardType: TextInputType.text,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.username,
                                  AutofillHints.email,
                                  AutofillHints.telephoneNumber,
                                ],
                                validator: _validateAccount,
                                decoration: authInputDecoration(
                                  hint: 'Email / 09xx xxx xxx',
                                  icon: Icons.person_outline_rounded,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const _FieldLabel('Mật khẩu'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _passwordController,
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 15,
                                  color: Color(0xFF172B35),
                                ),
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                validator: _validatePassword,
                                onFieldSubmitted: (_) => _submit(),
                                decoration:
                                    authInputDecoration(
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
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: _rememberMe,
                                        onChanged: (value) => setState(
                                          () => _rememberMe = value ?? false,
                                        ),
                                        activeColor: AppColors.primary,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      const Flexible(
                                        child: Text('Ghi nhớ đăng nhập'),
                                      ),
                                    ],
                                  ),
                                  TextButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () => showForgotPasswordSheet(
                                            context,
                                            recovery: widget.passwordRecovery,
                                            initialAccount:
                                                _accountController.text,
                                          ),
                                    child: const Text(
                                      'Qu\u00ean m\u1eadt kh\u1ea9u?',
                                    ),
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
                                    textStyle: const TextStyle(
                                      fontFamily: 'Nunito',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
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
                    const SizedBox(height: 24),
                    const Row(
                      children: [
                        Expanded(child: Divider(color: AppColors.border)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Ho\u1eb7c ti\u1ebfp t\u1ee5c v\u1edbi',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: AppColors.border)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    for (final provider in const [
                      SocialProvider.google,
                      SocialProvider.apple,
                    ]) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  final name = provider == SocialProvider.google
                                      ? 'Google'
                                      : 'Apple';
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '\u0110\u0103ng nh\u1eadp v\u1edbi $name ch\u01b0a \u0111\u01b0\u1ee3c k\u1ebft n\u1ed1i.',
                                        ),
                                      ),
                                    );
                                },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 52),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            backgroundColor: AppColors.surface,
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ExcludeSemantics(
                                child: SocialProviderIcon(provider: provider),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  'Ti\u1ebfp t\u1ee5c v\u1edbi ${provider == SocialProvider.google ? 'Google' : 'Apple'}',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 20),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Bạn chưa có tài khoản? ',
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              color: Color(0xFF64748B),
                            ),
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(label, style: authFieldLabelStyle);
}
