import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_colors.dart';

import '../../services/auth_service.dart';
import 'auth_layout.dart';
import 'auth_form_style.dart';
import 'parent_role.dart';
import 'registration_gateway.dart';
import 'registration_profile_form.dart';
import 'social_provider_icon.dart';
import 'social_profile_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({
    required this.onLogin,
    required this.onChildProfilePreview,
    this.onExistingAccount,
    this.registrationGateway,
    super.key,
  });
  final VoidCallback onLogin, onChildProfilePreview;
  final VoidCallback? onExistingAccount;
  final RegistrationGateway? registrationGateway;
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController(), _code = TextEditingController();
  final _password = TextEditingController(), _confirm = TextEditingController();
  final _name = TextEditingController();
  final _mascot = AuthMascotController();
  late final _phoneFocus = _mascot.field();
  late final _codeFocus = _mascot.field();
  late final _nameFocus = _mascot.field();
  late final _passwordFocus = _mascot.field(obscured: () => _hidePassword);
  late final _confirmFocus = _mascot.field(obscured: () => _hideConfirm);
  late final RegistrationGateway _gateway =
      widget.registrationGateway ?? UnavailableRegistrationGateway();
  int _step = 0;
  bool _busy = false, _accepted = false, _attempted = false;
  bool _hidePassword = true, _hideConfirm = true;
  ParentRole? _role;
  Map<String, dynamic>? _challenge, _grant;
  String? _error;
  late final Timer _timer;
  static const _titles = [
    'Tạo tài khoản',
    'Xác minh số điện thoại',
    'Tạo mật khẩu',
    'Thông tin của bạn',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_step > 1 &&
          _grant != null &&
          _left(_grant, 'expiresAt') == 0 &&
          !_busy) {
        _expire();
      } else if (_step == 1) {
        setState(() {});
      }
    });
  }

  int _left(Map<String, dynamic>? value, String field) {
    final date = DateTime.tryParse(value?[field]?.toString() ?? '');
    if (date == null) return 0;
    return ((date.difference(DateTime.now()).inMilliseconds / 1000).ceil())
        .clamp(0, 3600);
  }

  void _expire() {
    _password.clear();
    _confirm.clear();
    setState(() {
      _grant = null;
      _step = 1;
      _error =
          'Phiên xác minh đã hết hạn. Vui lòng xác minh lại số điện thoại.';
    });
  }

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _error = null;
      _attempted = false;
    });
  }

  void _back() {
    if (_busy) return;
    if (_step == 0) {
      widget.onLogin();
      return;
    }
    if (_step == 1) {
      _challenge = null;
      _grant = null;
      _code.clear();
      _password.clear();
      _confirm.clear();
      _accepted = false;
    }
    _go(_step - 1);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'SOCIAL_CANCELLED') return;
      if (e.code == 'REGISTRATION_CHALLENGE_INVALID' && _step > 1) _expire();
      setState(() => _error = e.toString());
      _mascot.showError();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Không thể hoàn tất yêu cầu. Vui lòng thử lại.',
        );
        _mascot.showError();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _attempted = true);
    if (!(_form.currentState?.validate() ?? false) ||
        (_step == 3 && !_accepted)) {
      _mascot.showError();
      return;
    }
    if (_step >= 2 && _left(_grant, 'expiresAt') == 0) {
      _expire();
      return;
    }
    if (_step == 2) {
      _go(3);
      return;
    }
    await _run(() async {
      if (_step == 0) {
        final result = await _gateway.start(_phone.text.trim());
        if (!mounted) return;
        _challenge = result;
        _code.clear();
        _go(1);
      } else if (_step == 1) {
        final grant = await _gateway.verify(_challenge!, _code.text);
        if (!mounted) return;
        if (_left(grant, 'expiresAt') == 0) {
          throw AuthException('REGISTRATION_CHALLENGE_INVALID', {});
        }
        _grant = grant;
        _code.clear();
        _go(2);
      } else {
        await _gateway.complete(_grant!, {
          'phone': _phone.text.trim(),
          'password': _password.text,
          'displayName': _name.text.trim(),
          'defaultRelationship': _role!.registrationValue,
          'acceptedTerms': _accepted,
        });
        if (!mounted) return;
        _password.clear();
        _confirm.clear();
        _grant = null;
        widget.onChildProfilePreview();
      }
    });
  }

  Future<void> _resend() => _run(() async {
    final value = await _gateway.resend(_challenge!);
    if (!mounted) return;
    setState(() {
      _challenge = value;
      _grant = null;
      _code.clear();
    });
  });

  Future<void> _social(SocialProvider provider) => _run(() async {
    final created = await AuthService.instance.socialRegister(
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
    if (!mounted) return;
    (created
        ? widget.onChildProfilePreview
        : widget.onExistingAccount ?? widget.onChildProfilePreview)();
  });

  @override
  void dispose() {
    _timer.cancel();
    _mascot.dispose();
    for (final controller in [_phone, _code, _password, _confirm, _name]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _passwordField({required bool confirmation}) {
    final hidden = confirmation ? _hideConfirm : _hidePassword;
    return TextFormField(
      key: ValueKey(
        confirmation ? 'registration-confirm' : 'registration-password',
      ),
      controller: confirmation ? _confirm : _password,
      focusNode: confirmation ? _confirmFocus : _passwordFocus,
      enabled: !_busy,
      obscureText: hidden,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: const [AutofillHints.newPassword],
      textInputAction: confirmation
          ? TextInputAction.done
          : TextInputAction.next,
      onFieldSubmitted: confirmation ? (_) => _next() : null,
      decoration:
          authInputDecoration(
            greenSprout: true,
            hint: confirmation ? 'Nhập lại mật khẩu' : 'Nhập mật khẩu',
            icon: Icons.lock_outline_rounded,
          ).copyWith(
            suffixIcon: IconButton(
              tooltip: confirmation
                  ? (hidden ? 'Hiện xác nhận mật khẩu' : 'Ẩn xác nhận mật khẩu')
                  : (hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu'),
              onPressed: () => setState(() {
                if (confirmation) {
                  _hideConfirm = !hidden;
                } else {
                  _hidePassword = !hidden;
                }
                _mascot.visibilityChanged();
              }),
              icon: Icon(
                hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
      validator: (value) {
        final text = value ?? '';
        if (text.isEmpty) {
          return confirmation
              ? 'Vui lòng xác nhận mật khẩu.'
              : 'Vui lòng nhập mật khẩu.';
        }
        if (confirmation) {
          return text == _password.text ? null : 'Mật khẩu chưa trùng khớp.';
        }
        if (text.length < 8 || text.length > 64) {
          return 'Mật khẩu cần có 8–64 ký tự.';
        }
        if (text.codeUnits.any((c) => c < 33 || c > 126)) {
          return 'Mật khẩu không được chứa dấu, khoảng trắng hoặc emoji.';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _back();
    },
    child: AuthLayout(
      title: _titles[_step],
      subtitle: '',
      onBack: _busy ? null : _back,
      mascot: _mascot,
      child: Form(
        key: _form,
        autovalidateMode: _attempted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        onChanged: _mascot.edited,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_step == 0) ...[
              const Text('Số điện thoại', style: authSproutFieldLabelStyle),
              const SizedBox(height: 8),
              TextFormField(
                key: const ValueKey('registration-phone'),
                controller: _phone,
                focusNode: _phoneFocus,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _next(),
                decoration: authInputDecoration(
                  greenSprout: true,
                  hint: 'Nhập số điện thoại',
                  icon: Icons.phone_outlined,
                ),
                validator: (value) {
                  final phone = value?.trim() ?? '';
                  if (phone.isEmpty) return 'Vui lòng nhập số điện thoại.';
                  // Format only; the server validates current allocated mobile prefixes.
                  if (!RegExp(r'^(0[0-9]{9}|\+84[0-9]{9})$').hasMatch(phone)) {
                    return 'Số điện thoại không đúng định dạng. Ví dụ: 0912345678 hoặc +84912345678.';
                  }
                  return null;
                },
              ),
              TextButton(
                onPressed: _busy ? null : () => showAuthPolicies(context),
                child: const Text('Điều khoản và chính sách quyền riêng tư'),
              ),
            ],
            if (_step == 1) ...[
              Text(
                'Nhập mã xác minh gồm 6 chữ số đã gửi đến ${_challenge?['targetMasked'] ?? ''}.',
              ),
              const SizedBox(height: 16),
              const Text('Mã xác minh', style: authSproutFieldLabelStyle),
              const SizedBox(height: 8),
              TextFormField(
                key: const ValueKey('registration-otp'),
                controller: _code,
                focusNode: _codeFocus,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _next(),
                decoration: authInputDecoration(
                  greenSprout: true,
                  hint: 'Nhập mã xác minh 6 số',
                  icon: Icons.sms_outlined,
                ),
                validator: (v) => RegExp(r'^[0-9]{6}$').hasMatch(v ?? '')
                    ? null
                    : 'Vui lòng nhập đủ 6 chữ số.',
              ),
              Text(
                _left(_challenge, 'expiresAt') == 0
                    ? 'Mã đã hết hạn. Vui lòng gửi lại.'
                    : 'Mã hết hạn sau ${_left(_challenge, 'expiresAt') ~/ 60}:${(_left(_challenge, 'expiresAt') % 60).toString().padLeft(2, '0')}.',
              ),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _busy ? null : _back,
                    child: const Text('Sửa số điện thoại'),
                  ),
                  TextButton(
                    onPressed:
                        !_busy && _left(_challenge, 'resendAvailableAt') == 0
                        ? _resend
                        : null,
                    child: Text(
                      _left(_challenge, 'resendAvailableAt') > 0
                          ? 'Gửi lại sau ${_left(_challenge, 'resendAvailableAt')} giây'
                          : 'Gửi lại mã',
                    ),
                  ),
                ],
              ),
            ],
            if (_step == 2) ...[
              const Text('Mật khẩu', style: authSproutFieldLabelStyle),
              const SizedBox(height: 8),
              _passwordField(confirmation: false),
              const SizedBox(height: 8),
              const Text(
                '8–64 ký tự, không dấu, khoảng trắng hoặc emoji.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 20),
              const Text('Xác nhận mật khẩu', style: authSproutFieldLabelStyle),
              const SizedBox(height: 8),
              _passwordField(confirmation: true),
            ],
            if (_step == 3)
              RegistrationProfileForm(
                name: _name,
                nameFocus: _nameFocus,
                role: _role,
                accepted: _accepted,
                enabled: !_busy,
                showConsentError: _attempted,
                onRole: (v) => setState(() => _role = v),
                onAccepted: (v) => setState(() => _accepted = v),
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('registration-next'),
              onPressed: _busy ? null : _next,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _step == 3
                          ? 'Hoàn tất đăng ký'
                          : _step == 1
                          ? 'Xác minh'
                          : 'Tiếp tục',
                    ),
            ),
            if (_step == 0) ...[
              const SizedBox(height: 20),
              AuthSocialButtons(onPressed: _busy ? null : _social),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy ? null : widget.onLogin,
                child: const Text('Đã có tài khoản? Đăng nhập'),
              ),
            ],
            const SizedBox(height: 24),
            Semantics(
              key: ValueKey('registration-step-${_step + 1}'),
              label: 'Bước ${_step + 1} trên 4',
              child: ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    4,
                    (index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == _step
                              ? HomeColors.reminderCta
                              : HomeColors.iconBackground,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
