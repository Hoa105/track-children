import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import 'auth_form_style.dart';

abstract class PasswordRecovery {
  Future<Map<String, dynamic>> send(String account);
  Future<String> verify(Map<String, dynamic> challenge, String code);
  Future<void> reset(String token, String password);
}

Future<void> showForgotPasswordSheet(
  BuildContext context, {
  String initialAccount = '',
  PasswordRecovery? recovery,
}) async {
  final token = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _RecoveryDialog(account: initialAccount, recovery: recovery),
  );
  if (token == null || recovery == null || !context.mounted) return;
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _RecoveryDialog(account: '', recovery: recovery, token: token),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã cập nhật mật khẩu. Bạn có thể đăng nhập.'),
      ),
    );
  }
}

class _RecoveryDialog extends StatefulWidget {
  const _RecoveryDialog({
    required this.account,
    required this.recovery,
    this.token,
  });
  final String account;
  final PasswordRecovery? recovery;
  final String? token;
  @override
  State<_RecoveryDialog> createState() => _RecoveryDialogState();
}

class _RecoveryDialogState extends State<_RecoveryDialog> {
  final _form = GlobalKey<FormState>();
  late final _account = TextEditingController(text: widget.account);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  Map<String, dynamic>? _challenge;
  bool _busy = false, _hidden = true;
  String? _error;
  int _attempts = 5, _sends = 0;
  DateTime? _resendAt;
  Timer? _timer;
  bool get _reset => widget.token != null;
  int get _wait => _resendAt == null
      ? 0
      : (_resendAt!.difference(DateTime.now()).inMilliseconds / 1000)
            .ceil()
            .clamp(0, 60);
  int get _expiry => _challenge == null
      ? 0
      : (DateTime.parse(_challenge!['expiresAt'] as String)
                    .difference(DateTime.now())
                    .inMilliseconds /
                1000)
            .ceil()
            .clamp(0, 300);
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _challenge != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _account.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validateAccount(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Nhập email hoặc số điện thoại.';
    if (v.contains('@'))
      return v.length <= 254 &&
              RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)
          ? null
          : 'Email chưa đúng định dạng.';
    var phone = v.replaceAll(RegExp(r'[\s()-]'), '');
    if (phone.startsWith('0')) phone = '+84${phone.substring(1)}';
    return RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone)
        ? null
        : 'Số điện thoại chưa đúng định dạng.';
  }

  Future<void> _send() async {
    if (_busy || _wait > 0 || _sends >= 5) return;
    if (_challenge == null && !_form.currentState!.validate()) return;
    if (widget.recovery == null) {
      setState(() => _error = 'Chức năng gửi OTP chưa được kết nối.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.recovery!.send(_account.text.trim());
      if (!mounted) return;
      setState(() {
        _sends++;
        _resendAt = DateTime.now().add(const Duration(seconds: 60));
        if (result['deliveryStatus'] == 'failed') {
          _error = 'Chưa gửi được OTP. Vui lòng thử lại sau.';
          return;
        }
        _challenge = result;
        _attempts = 5;
        _code.clear();
      });
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Chưa gửi được OTP. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_reset && _challenge == null) {
      await _send();
      return;
    }
    if (!_reset && (_expiry == 0 || _attempts == 0)) return;
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_reset) {
        await widget.recovery!.reset(widget.token!, _password.text);
        if (mounted) Navigator.pop(context, true);
      } else {
        final token = await widget.recovery!.verify(_challenge!, _code.text);
        if (token.isEmpty) throw StateError('Missing verified token');
        if (mounted) Navigator.pop(context, token);
      }
    } on AuthException catch (e) {
      if (mounted)
        setState(() {
          if (e.code == 'OTP_INVALID') {
            _attempts = (_attempts - 1).clamp(0, 5);
            final left = e.details['attemptsRemaining'] as int?;
            if (left != null && left < _attempts) _attempts = left.clamp(0, 5);
          } else if (e.code == 'OTP_ATTEMPTS_EXCEEDED' ||
              e.code == 'OTP_EXPIRED') {
            _attempts = 0;
          }
          _error = e.toString();
        });
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa hoàn tất. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sent = _challenge != null;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(
          _reset
              ? 'Đặt mật khẩu mới'
              : sent
              ? 'Xác minh OTP'
              : 'Quên mật khẩu',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_reset) ...[
                  TextFormField(
                    controller: _password,
                    obscureText: _hidden,
                    enabled: !_busy,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (v) =>
                        (v?.runes.length ?? 0) >= 8 &&
                            (v?.runes.length ?? 0) <= 64
                        ? null
                        : 'Mật khẩu cần có 8–64 ký tự.',
                    decoration:
                        authInputDecoration(
                          hint: 'Có ít nhất 8 ký tự',
                          icon: Icons.lock_outline_rounded,
                        ).copyWith(
                          labelText: 'Mật khẩu mới',
                          suffixIcon: IconButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() => _hidden = !_hidden),
                            tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                            icon: Icon(
                              _hidden
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirm,
                    obscureText: _hidden,
                    enabled: !_busy,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: (v) =>
                        v == _password.text && (v?.isNotEmpty ?? false)
                        ? null
                        : 'Mật khẩu chưa trùng khớp.',
                    onFieldSubmitted: (_) => _submit(),
                    decoration: authInputDecoration(
                      hint: 'Nhập lại mật khẩu',
                      icon: Icons.lock_outline_rounded,
                    ).copyWith(labelText: 'Xác nhận mật khẩu'),
                  ),
                ] else ...[
                  Text(
                    sent
                        ? 'Nhập mã gửi đến ${_challenge!['targetMasked'] ?? _account.text}.'
                        : 'Nhập email hoặc số điện thoại đã liên kết để nhận OTP.',
                  ),
                  const SizedBox(height: 20),
                  if (!sent)
                    TextFormField(
                      controller: _account,
                      enabled: !_busy,
                      autofocus: true,
                      validator: _validateAccount,
                      onFieldSubmitted: (_) => _send(),
                      decoration: authInputDecoration(
                        hint: 'Email hoặc số điện thoại',
                        icon: Icons.person_outline_rounded,
                      ),
                    )
                  else ...[
                    TextFormField(
                      key: const ValueKey('recovery-otp'),
                      controller: _code,
                      enabled: !_busy && _attempts > 0 && _expiry > 0,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) => RegExp(r'^[0-9]{6}$').hasMatch(v ?? '')
                          ? null
                          : 'Nhập đủ 6 chữ số.',
                      onFieldSubmitted: (_) => _submit(),
                      decoration: authInputDecoration(
                        hint: 'Mã OTP',
                        icon: Icons.password_rounded,
                      ).copyWith(counterText: ''),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _expiry == 0
                          ? 'Mã đã hết hạn.'
                          : _attempts == 0
                          ? 'Mã không còn hiệu lực.'
                          : '${_expiry ~/ 60}:${(_expiry % 60).toString().padLeft(2, '0')} • Còn $_attempts lần nhập',
                      style: const TextStyle(fontSize: 13),
                    ),
                    TextButton(
                      onPressed: _busy || _wait > 0 || _sends >= 5
                          ? null
                          : _send,
                      child: Text(
                        _sends >= 5
                            ? 'Đã đạt giới hạn gửi lại'
                            : _wait > 0
                            ? 'Gửi lại sau $_wait giây'
                            : 'Gửi lại OTP',
                      ),
                    ),
                  ],
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFF9E4545)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: _busy || (sent && (_expiry == 0 || _attempts == 0))
                ? null
                : _submit,
            child: Text(
              _busy
                  ? 'Đang xử lý…'
                  : _reset
                  ? 'Lưu mật khẩu'
                  : sent
                  ? 'Xác nhận'
                  : 'Gửi mã OTP',
            ),
          ),
        ],
      ),
    );
  }
}
