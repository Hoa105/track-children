import '../../services/auth_service.dart';

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'auth_entrance_animation.dart';
import 'otp_dialog.dart';
import 'parent_role.dart';
import 'auth_form_style.dart';
import 'social_provider_icon.dart';
import 'social_registration_dialog.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({
    required this.onLogin,
    required this.onChildProfilePreview,
    this.onExistingAccount,
    super.key,
  });

  final VoidCallback onLogin;
  final VoidCallback onChildProfilePreview;
  final VoidCallback? onExistingAccount;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  ParentRole _parentRole = ParentRole.mother;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool? _emailSelected;
  bool get _useEmail => _emailSelected ?? true;
  bool _isSubmitting = false;
  bool _isVerifyingOtp = false;
  bool _isCompletingSocial = false;
  bool _attemptedSubmit = false;
  bool _acceptedTerms = false;
  String? _previewMessage;
  final Map<String, String> _serverErrors = {};
  Map<String, dynamic>? _pendingChallenge;
  Map<String, dynamic>? _pendingPayload;

  Map<String, dynamic> get _registrationPayload => {
    'displayName': _nameController.text.trim().isEmpty
        ? 'Phụ huynh'
        : _nameController.text.trim(),
    if (_useEmail)
      'email': _emailController.text.trim()
    else
      'phone': _phoneController.text.trim(),
    'password': _passwordController.text,
    'defaultRelationship': _parentRole.registrationValue,
    'acceptedTerms': _acceptedTerms,
  };

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) => (value?.trim().length ?? 0) <= 150
      ? _serverErrors['displayName']
      : 'T\u00ean hi\u1ec3n th\u1ecb t\u1ed1i \u0111a 150 k\u00fd t\u1ef1.';

  String? _validatePhone(String? value) {
    var phone = (value ?? '').replaceAll(RegExp(r'[\s()-]'), '');
    if (phone.isEmpty) return 'Vui lòng nhập số điện thoại.';
    if (phone.startsWith('0')) phone = '+84${phone.substring(1)}';
    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone)) {
      return 'Số điện thoại chưa đúng định dạng.';
    }
    return _serverErrors['phone'];
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Vui lòng nhập email.';
    if (email.length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Email chưa đúng định dạng.';
    }
    return _serverErrors['email'];
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu.';
    if (value.runes.length < 8 || value.runes.length > 64) {
      return 'M\u1eadt kh\u1ea9u c\u1ea7n c\u00f3 8\u201364 k\u00fd t\u1ef1.';
    }
    return _serverErrors['password'];
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng xác nhận mật khẩu.';
    if (value != _passwordController.text) return 'Mật khẩu chưa trùng khớp.';
    return null;
  }

  Future<void> _showTerms() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final docs = await AuthService.instance.documents();
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Điều khoản và chính sách'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final doc in docs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        '${switch (doc['docType']) {
                          'terms' => 'Điều khoản sử dụng',
                          'privacy' => 'Chính sách quyền riêng tư',
                          'data_policy' => 'Chính sách dữ liệu',
                          _ => doc['docType'],
                        }} — ${doc['version']}\n${doc['content']}',
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
            FilledButton(
              onPressed: () {
                setState(() => _acceptedTerms = true);
                Navigator.pop(context);
              },
              child: const Text('Đồng ý'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _previewMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    _serverErrors.clear();
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
      final payload = _registrationPayload;
      final unchanged =
          _pendingPayload != null &&
          payload.entries.every(
            (entry) => _pendingPayload![entry.key] == entry.value,
          ) &&
          payload.length == _pendingPayload!.length;
      final challenge = unchanged && _pendingChallenge != null
          ? _pendingChallenge!
          : await AuthService.instance.register(payload);
      _pendingPayload = payload;
      _pendingChallenge = challenge;
      if (!mounted) return;
      setState(() => _isVerifyingOtp = true);
      final verified = await showOtpVerificationDialog(
        context,
        challenge: challenge,
        onChallengeChanged: (value) => _pendingChallenge = value,
      );
      if (mounted && verified == true) {
        _pendingChallenge = null;
        _pendingPayload = null;
        _passwordController.clear();
        _confirmPasswordController.clear();
        widget.onChildProfilePreview();
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _previewMessage = e.toString();
          if (e.code == 'ACCOUNT_CONFLICT') {
            _serverErrors[_useEmail ? 'email' : 'phone'] =
                'Thông tin liên hệ đã được sử dụng.';
          } else if (e.details['fields'] is Map) {
            for (final field in (e.details['fields'] as Map).keys) {
              _serverErrors[field.toString()] = 'Thông tin chưa hợp lệ.';
            }
          }
        });
        _formKey.currentState?.validate();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _previewMessage = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isVerifyingOtp = false;
        });
      }
    }
  }

  Future<void> _socialRegister(SocialProvider provider) async {
    if (_isSubmitting) return;
    setState(() {
      _previewMessage = null;
    });
    setState(() => _isSubmitting = true);
    try {
      final created = await AuthService.instance.socialRegister(
        provider.name,
        acceptedTerms: false,
        displayName: _nameController.text,
        requestConsent: (account) async {
          if (!mounted) return null;
          setState(() => _isCompletingSocial = true);
          try {
            return await showDialog<SocialRegistrationConsent>(
              context: context,
              barrierDismissible: false,
              builder: (_) => SocialRegistrationDialog(
                providerName: provider == SocialProvider.google
                    ? 'Google'
                    : 'Apple',
                account: account,
              ),
            );
          } finally {
            if (mounted) setState(() => _isCompletingSocial = false);
          }
        },
      );
      if (mounted) {
        (created
            ? widget.onChildProfilePreview
            : widget.onExistingAccount ?? widget.onChildProfilePreview)();
      }
    } on AuthException catch (e) {
      if (e.code == 'SOCIAL_CANCELLED') return;
      if (mounted) {
        setState(() => _previewMessage = e.toString());
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _previewMessage = 'Chưa đăng nhập được. Vui lòng thử lại.',
        );
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
                      height: 52,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: 'Quay lại đăng nhập',
                          onPressed: _isSubmitting ? null : widget.onLogin,
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
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
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
                          autovalidateMode: _attemptedSubmit
                              ? AutovalidateMode.onUserInteraction
                              : AutovalidateMode.disabled,
                          onChanged: () {
                            if (_serverErrors.isNotEmpty) {
                              setState(() => _serverErrors.clear());
                            }
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionLabel(
                                'Tên hiển thị (không bắt buộc)',
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                enabled: !_isSubmitting,
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                validator: _validateName,
                                decoration: authInputDecoration(
                                  hint: 'Tên bạn muốn hiển thị',
                                  icon: Icons.badge_outlined,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 12,
                                children: [
                                  _SectionLabel(
                                    _useEmail
                                        ? 'Email'
                                        : 'S\u1ed1 \u0111i\u1ec7n tho\u1ea1i',
                                  ),
                                  TextButton(
                                    key: const ValueKey(
                                      'registration-method-selector',
                                    ),
                                    onPressed: _isSubmitting
                                        ? null
                                        : () {
                                            FocusScope.of(context).unfocus();
                                            setState(() {
                                              _emailSelected = !_useEmail;
                                              _previewMessage = null;
                                            });
                                          },
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      textStyle: const TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    child: Text(
                                      _useEmail
                                          ? 'D\u00f9ng s\u1ed1 \u0111i\u1ec7n tho\u1ea1i'
                                          : 'D\u00f9ng email',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                enabled: !_isSubmitting,
                                key: ValueKey(_useEmail),
                                controller: _useEmail
                                    ? _emailController
                                    : _phoneController,
                                keyboardType: _useEmail
                                    ? TextInputType.emailAddress
                                    : TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                autofillHints: [
                                  _useEmail
                                      ? AutofillHints.email
                                      : AutofillHints.telephoneNumber,
                                ],
                                validator: _useEmail
                                    ? _validateEmail
                                    : _validatePhone,
                                decoration: authInputDecoration(
                                  hint: _useEmail
                                      ? 'ban@email.com'
                                      : '09xxxxxxxx',
                                  icon: _useEmail
                                      ? Icons.mail_outline_rounded
                                      : Icons.phone_outlined,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const _SectionLabel('Mật khẩu'),
                              const SizedBox(height: 8),
                              TextFormField(
                                enabled: !_isSubmitting,
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                validator: _validatePassword,
                                decoration:
                                    authInputDecoration(
                                      hint: 'Có ít nhất 8 ký tự',
                                      icon: Icons.lock_outline_rounded,
                                    ).copyWith(
                                      suffixIcon: IconButton(
                                        tooltip: _obscurePassword
                                            ? 'Hiện mật khẩu'
                                            : 'Ẩn mật khẩu',
                                        onPressed: _isSubmitting
                                            ? null
                                            : () => setState(() {
                                                _obscurePassword =
                                                    !_obscurePassword;
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
                                enabled: !_isSubmitting,
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmation,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                validator: _validateConfirmPassword,
                                onFieldSubmitted: (_) => _submit(),
                                decoration:
                                    authInputDecoration(
                                      hint: 'Nhập lại mật khẩu',
                                      icon: Icons.lock_outline_rounded,
                                    ).copyWith(
                                      suffixIcon: IconButton(
                                        tooltip: _obscureConfirmation
                                            ? 'Hiện xác nhận mật khẩu'
                                            : 'Ẩn xác nhận mật khẩu',
                                        onPressed: _isSubmitting
                                            ? null
                                            : () => setState(() {
                                                _obscureConfirmation =
                                                    !_obscureConfirmation;
                                              }),
                                        icon: Icon(
                                          _obscureConfirmation
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                      ),
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
                                      onSelected: _isSubmitting
                                          ? null
                                          : (_) => setState(
                                              () => _parentRole = role,
                                            ),
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
                                      onChanged: _isSubmitting
                                          ? null
                                          : (value) => setState(
                                              () => _acceptedTerms =
                                                  value ?? false,
                                            ),
                                      activeColor: AppColors.primary,
                                    ),
                                    Expanded(
                                      child: InkWell(
                                        onTap: _isSubmitting
                                            ? null
                                            : _showTerms,
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
                                  child:
                                      _isSubmitting &&
                                          !_isVerifyingOtp &&
                                          !_isCompletingSocial
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
                          onPressed: _isSubmitting
                              ? null
                              : () => _socialRegister(provider),
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
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Đã có tài khoản? ',
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          TextButton(
                            onPressed: _isSubmitting ? null : widget.onLogin,
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
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(label, style: authFieldLabelStyle);
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
