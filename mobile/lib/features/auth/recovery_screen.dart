import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import 'auth_layout.dart';
import 'auth_form_style.dart';
import 'social_provider_icon.dart';
import 'otp_status.dart';

/// Secrets live only in this route and are disposed on cancellation/success.
class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key, this.initialAccount = ''});
  final String initialAccount;
  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _form = GlobalKey<FormState>();
  final _mascot = AuthMascotController();
  late final _account = TextEditingController(text: widget.initialAccount);
  final _code = TextEditingController(), _emailCode = TextEditingController();
  final _password = TextEditingController(), _confirm = TextEditingController();
  int _step = 0;
  bool _busy = false, _hide = true, _hideConfirm = true;
  String? _error;
  Map<String, dynamic>? _ticket, _extra;
  List<String> _options = [];
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _step != 0) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _mascot.dispose();
    for (final c in [_account, _code, _emailCode, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _additional(List<dynamic>? options) {
    _password.clear();
    _confirm.clear();
    _options = (options ?? ['support']).whereType<String>().toList();
    _step = 2;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'SOCIAL_CANCELLED') return;
      setState(() {
        if (e.code == 'RECOVERY_ADDITIONAL_VERIFICATION_REQUIRED') {
          _additional(e.details['verificationOptions'] as List?);
        } else if (e.code == 'TRANSACTION_INVALID') {
          _step = 0;
          _ticket = null;
          _extra = null;
          _password.clear();
          _confirm.clear();
          _code.clear();
          _emailCode.clear();
        }
        _error = e.toString();
      });
      _mascot.showError();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Không thể hoàn tất yêu cầu. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    if ((_step == 1 || _step == 3) &&
        !OtpTiming(_step == 1 ? _ticket : _extra)
            .canVerify(_step == 1 ? _code.text : _emailCode.text)) {
      return;
    }
    await _run(() async {
      final service = AuthService.instance;
      if (_step == 0) {
        final value = await service.startRecovery(_account.text.trim());
        if (!mounted) return;
        setState(() {
          _ticket = value;
          _code.clear();
          _step = 1;
        });
      } else if (_step == 1) {
        final value = await service.verifyRecovery(_ticket!, _code.text);
        if (!mounted) return;
        setState(() {
          _ticket = {..._ticket!, ...value};
          _code.clear();
          if (value['requiresAdditionalVerification'] == true) {
            _additional(value['verificationOptions'] as List?);
          } else {
            _step = 4;
          }
        });
      } else if (_step == 3) {
        await service.verifyRecoveryEmail(_extra!, _emailCode.text);
        if (!mounted) return;
        setState(() {
          _emailCode.clear();
          _extra = null;
          _step = 4;
        });
      } else if (_step == 4) {
        await service.completeRecovery(_ticket!, _password.text, _confirm.text);
        if (mounted) Navigator.pop(context, true);
      }
    });
  }

  Future<void> _resend() => _run(() async {
    final value = await AuthService.instance.resendRecovery(_ticket!);
    if (mounted) {
      setState(() {
        _ticket = value;
        _code.clear();
      });
    }
  });
  Future<void> _email() => _run(() async {
    final value = await AuthService.instance.recoveryEmail(_ticket!);
    if (mounted) {
      setState(() {
        _extra = value;
        _emailCode.clear();
        _step = 3;
      });
    }
  });
  Future<void> _provider(String provider) => _run(() async {
    await AuthService.instance.verifyRecoveryProvider(_ticket!, provider);
    if (mounted) setState(() => _step = 4);
  });
  Widget _field(
    String label,
    String key,
    TextEditingController controller, {
    bool password = false,
    bool confirmation = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: authSproutFieldLabelStyle),
      const SizedBox(height: 8),
      TextFormField(
        key: ValueKey(key),
        controller: controller,
        onChanged: (_) => setState(() {}),
        enabled: !_busy,
        obscureText: password && (confirmation ? _hideConfirm : _hide),
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: password
            ? TextInputType.visiblePassword
            : _step == 0
            ? TextInputType.text
            : TextInputType.number,
        autofillHints: password
            ? const [AutofillHints.newPassword]
            : _step == 0
            ? const [AutofillHints.username]
            : const [AutofillHints.oneTimeCode],
        inputFormatters: !password && _step != 0
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ]
            : null,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _next(),
        decoration:
            authInputDecoration(
              greenSprout: true,
              hint: password
                  ? (confirmation ? 'Nhập lại mật khẩu' : 'Nhập mật khẩu mới')
                  : _step == 0
                  ? 'Nhập email hoặc số điện thoại'
                  : 'Nhập mã xác minh 6 số',
              icon: password
                  ? Icons.lock_outline_rounded
                  : _step == 0
                  ? Icons.person_outline
                  : Icons.sms_outlined,
            ).copyWith(
              suffixIcon: password
                  ? IconButton(
                      tooltip: confirmation
                          ? 'Hiện/ẩn xác nhận mật khẩu'
                          : 'Hiện/ẩn mật khẩu',
                      onPressed: () => setState(() {
                        if (confirmation) {
                          _hideConfirm = !_hideConfirm;
                        } else {
                          _hide = !_hide;
                        }
                      }),
                      icon: Icon(
                        (confirmation ? _hideConfirm : _hide)
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    )
                  : null,
            ),
        validator: (value) {
          final text = value ?? '';
          if (_step == 0) {
            final id = text.trim();
            if (id.isEmpty) return 'Vui lòng nhập email hoặc số điện thoại.';
            return (id.contains('@')
                    ? RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(id)
                    : RegExp(r'^(0[0-9]{9}|\+84[0-9]{9})$').hasMatch(id))
                ? null
                : 'Email hoặc số điện thoại không đúng định dạng.';
          }
          if (password) {
            if (confirmation) {
              return text == _password.text
                  ? null
                  : 'Mật khẩu chưa trùng khớp.';
            }
            if (text.length < 8 || text.length > 64) {
              return 'Mật khẩu cần có 8–64 ký tự.';
            }
            return text.codeUnits.any((c) => c < 33 || c > 126)
                ? 'Mật khẩu không được chứa dấu, khoảng trắng hoặc emoji.'
                : null;
          }
          return RegExp(r'^[0-9]{6}$').hasMatch(text)
              ? null
              : 'Vui lòng nhập đủ 6 chữ số.';
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AuthLayout(
      title: switch (_step) {
        0 => 'Quên mật khẩu',
        1 || 3 => 'Xác minh tài khoản',
        2 => 'Xác minh bổ sung',
        _ => 'Đặt lại mật khẩu',
      },
      subtitle: '',
      mascot: _mascot,
      onBack: _busy ? null : () => Navigator.pop(context),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_step == 0)
              _field('Email hoặc số điện thoại', 'recovery-account', _account),
            if (_step == 1 || _step == 3) ...[
              Text(
                _step == 1
                    ? (_ticket?['message'] as String? ??
                          'Nhập mã xác minh được gửi đến bạn.')
                    : 'Nhập mã đã gửi đến ${_extra?['targetMasked'] ?? 'email đã xác minh'}.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              _field(
                'Mã xác minh',
                _step == 1 ? 'recovery-code' : 'recovery-email-code',
                _step == 1 ? _code : _emailCode,
              ),
              const SizedBox(height: 12),
              OtpStatus(
                ticket: _step == 1 ? _ticket : _extra,
                busy: _busy,
                onResend: _step == 1 ? _resend : _email,
              ),
              if (_step == 1)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _step = 0;
                          _ticket = null;
                          _code.clear();
                        }),
                  child: const Text('Sửa email hoặc số điện thoại'),
                ),
            ],
            if (_step == 2) ...[
              const Text(
                'Để bảo vệ tài khoản, hãy xác minh bằng một phương thức đã liên kết.',
              ),
              const SizedBox(height: 16),
              if (_options.contains('email'))
                OutlinedButton.icon(
                  onPressed: _busy ? null : _email,
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('Xác minh qua email'),
                ),
              for (final provider in ['google', 'apple'])
                if (_options.contains(provider))
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _provider(provider),
                      icon: SocialProviderIcon(
                        provider: provider == 'google'
                            ? SocialProvider.google
                            : SocialProvider.apple,
                      ),
                      label: Text(
                        'Xác minh với ${provider == 'google' ? 'Google' : 'Apple'}',
                      ),
                    ),
                  ),
              const SizedBox(height: 16),
              const Text(
                'Không sử dụng được phương thức đã liên kết? Liên hệ hỗ trợ:',
              ),
              const SelectableText('belonkhon@gmail.com'),
            ],
            if (_step == 4) ...[
              _field(
                'Mật khẩu mới',
                'recovery-password',
                _password,
                password: true,
              ),
              const SizedBox(height: 8),
              const Text(
                '8–64 ký tự, gồm chữ cái không dấu, chữ số hoặc ký tự đặc biệt. Không dùng khoảng trắng.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 20),
              _field(
                'Xác nhận mật khẩu',
                'recovery-confirm',
                _confirm,
                password: true,
                confirmation: true,
              ),
            ],
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
            if (_step != 2)
              FilledButton(
                key: const ValueKey('recovery-next'),
                onPressed:
                    _busy ||
                        ((_step == 1 || _step == 3) &&
                            !OtpTiming(_step == 1 ? _ticket : _extra).canVerify(
                              _step == 1 ? _code.text : _emailCode.text,
                            ))
                    ? null
                    : _next,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _step == 0
                            ? 'Tiếp tục'
                            : _step == 4
                            ? 'Lưu mật khẩu'
                            : 'Xác minh',
                      ),
              ),
            if (_step == 2 && _busy)
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    ),
  );
}
