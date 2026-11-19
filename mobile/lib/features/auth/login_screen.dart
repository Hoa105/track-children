import '../../services/auth_service.dart';
import 'otp_dialog.dart';

import 'package:flutter/material.dart';

import '../../app_colors.dart';

import 'auth_layout.dart';
import 'forgot_password_sheet.dart';
import 'social_provider_icon.dart';
import 'auth_form_style.dart';
import 'social_profile_screen.dart';
import 'registration_profile_form.dart';

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
  final _mascot = AuthMascotController();
  late final _accountFocus = _mascot.field();
  late final _passwordFocus = _mascot.field(obscured: () => _obscurePassword);
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _previewError;

  @override
  void dispose() {
    _mascot.dispose();
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateAccount(String? value) {
    final account = value?.trim() ?? '';
    if (account.isEmpty) {
      return 'Vui l\u00f2ng nh\u1eadp email ho\u1eb7c s\u1ed1 \u0111i\u1ec7n tho\u1ea1i.';
    }
    if (account.contains('@')) {
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(account)) {
        return 'Email ch\u01b0a \u0111\u00fang \u0111\u1ecbnh d\u1ea1ng.';
      }
    } else {
      if (!RegExp(r'^(0[0-9]{9}|\+84[0-9]{9})$').hasMatch(account)) {
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
    if (!_formKey.currentState!.validate()) {
      _mascot.showError();
      return;
    }
    setState(() {
      _isLoading = true;
      _previewError = null;
    });

    bool valid = false;
    try {
      await AuthService.instance.login(
        _accountController.text,
        _passwordController.text,
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
    } catch (_) {
      if (mounted) {
        setState(
          () => _previewError = 'Không thể đăng nhập. Vui lòng thử lại.',
        );
      }
    }
    if (!mounted) return;
    if (_previewError != null) _mascot.showError();
    if (valid) {
      _mascot.showSuccess();
      setState(() => _isLoading = false);
      widget.onLoginSuccess?.call();
      if (widget.onLoginSuccess != null) return;
    }
    setState(() {
      _isLoading = false;
      _previewError ??= 'Chưa hoàn tất đăng nhập.';
      if (!valid) _mascot.showError();
    });
  }

  Future<void> _socialLogin(SocialProvider provider) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _previewError = null;
    });
    try {
      await AuthService.instance.socialRegister(
        provider.name,
        acceptedTerms: false,
        requestConsent: (account) =>
            Navigator.of(context).push<SocialRegistrationConsent>(
              MaterialPageRoute(
                builder: (_) =>
                    SocialProfileScreen(provider: provider, account: account),
              ),
            ),
      );
      if (mounted) {
        _mascot.showSuccess();
        widget.onLoginSuccess?.call();
      }
    } on AuthException catch (e) {
      if (e.code == 'SOCIAL_CANCELLED') return;
      if (mounted) {
        setState(() => _previewError = e.toString());
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _previewError = 'Chưa đăng nhập được. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) {
        if (_previewError != null) _mascot.showError();
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'Chào mừng ba mẹ!',
    subtitle: '',
    onBack: _isLoading ? null : widget.onBack,
    mascot: _mascot,
    child: Form(
      key: _formKey,
      onChanged: _mascot.edited,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _FieldLabel(
            'Email ho\u1eb7c s\u1ed1 \u0111i\u1ec7n tho\u1ea1i',
          ),
          const SizedBox(height: 8),
          TextFormField(
            enabled: !_isLoading,
            controller: _accountController,
            focusNode: _accountFocus,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 15,
              color: HomeColors.ink,
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
              greenSprout: true,
              hint: 'Nhập email hoặc số điện thoại',
              icon: Icons.person_outline_rounded,
            ),
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Mật khẩu'),
          const SizedBox(height: 8),
          TextFormField(
            enabled: !_isLoading,
            autocorrect: false,
            enableSuggestions: false,
            controller: _passwordController,
            focusNode: _passwordFocus,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 15,
              color: HomeColors.ink,
            ),
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            validator: _validatePassword,
            onFieldSubmitted: (_) => _submit(),
            decoration:
                authInputDecoration(
                  greenSprout: true,
                  hint: 'Nhập mật khẩu',
                  icon: Icons.lock_outline_rounded,
                ).copyWith(
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                    onPressed: () => setState(() {
                      _obscurePassword = !_obscurePassword;
                      _mascot.visibilityChanged();
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
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading
                  ? null
                  : () => showForgotPasswordSheet(
                      context,
                      recovery: widget.passwordRecovery,
                      initialAccount: _accountController.text,
                    ),
              child: const Text('Qu\u00ean m\u1eadt kh\u1ea9u?'),
            ),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: const Color(0xFF793B3B)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: FilledButton(
              onPressed: _isLoading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: HomeColors.reminderCta,
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
          const SizedBox(height: 20),
          AuthSocialButtons(onPressed: _isLoading ? null : _socialLogin),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Chưa có tài khoản?', style: TextStyle(fontSize: 14)),
              TextButton(
                onPressed: _isLoading ? null : widget.onSignUp,
                child: const Text('Đăng ký'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isLoading ? null : () => showAuthPolicies(context),
            child: const Text('Điều khoản và quyền riêng tư'),
          ),
        ],
      ),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) =>
      Text(label, style: authSproutFieldLabelStyle);
}
