import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_colors.dart';
import '../../services/auth_service.dart';

import 'dart:async';

Future<bool?> showOtpVerificationDialog(
  BuildContext context, {
  required Map<String, dynamic> challenge,
  bool remember = true,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => OtpDialog(challenge: challenge, remember: remember),
);

class OtpDialog extends StatefulWidget {
  const OtpDialog({required this.challenge, this.remember = true, super.key});

  final Map<String, dynamic> challenge;
  final bool remember;

  @override
  State<OtpDialog> createState() => _OtpDialogState();
}

class _OtpDialogState extends State<OtpDialog> {
  final _codeController = TextEditingController();
  String? _error;
  late Map<String, dynamic> _challenge;
  bool _busy = false;
  int _attemptsRemaining = 5;
  int _resendCount = 0;
  static const _maxResends = 5;
  DateTime? _localResendAt;
  int get _secondsLeft =>
      (DateTime.parse(_challenge['expiresAt'] as String)
                  .difference(DateTime.now())
                  .inMilliseconds /
              1000)
          .ceil()
          .clamp(0, 300);
  bool get _canConfirm => !_busy && _secondsLeft > 0 && _attemptsRemaining > 0;
  Timer? _timer;
  int get _wait =>
      (_localResendAt ??
                  DateTime.parse(_challenge['resendAvailableAt'] as String))
              .difference(DateTime.now())
              .inMilliseconds ~/
          1000 +
      1;
  int get _resendWait => _wait.clamp(0, 3600);

  @override
  void initState() {
    super.initState();
    _challenge = widget.challenge;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (!_canConfirm) return;
    if (!RegExp(r'^[0-9]{6}$').hasMatch(_codeController.text)) {
      setState(() => _error = 'Vui lòng nhập đủ 6 chữ số.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.instance.verify(
        _challenge,
        _codeController.text,
        remember: widget.remember,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          if (e.code == 'OTP_INVALID') {
            final serverRemaining = e.details['attemptsRemaining'] as int?;
            _attemptsRemaining = (_attemptsRemaining - 1).clamp(0, 5);
            if (serverRemaining != null &&
                serverRemaining < _attemptsRemaining) {
              _attemptsRemaining = serverRemaining.clamp(0, 5);
            }
          } else if (e.code == 'OTP_ATTEMPTS_EXCEEDED') {
            _attemptsRemaining = 0;
          } else if (e.code == 'OTP_EXPIRED') {
            _challenge = {
              ..._challenge,
              'expiresAt': DateTime.now().toIso8601String(),
            };
          }
          _error = e.toString();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy || _resendWait > 0 || _resendCount >= _maxResends) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final value = await AuthService.instance.resend(_challenge);
      if (mounted) {
        setState(() {
          _resendCount++;
          _localResendAt = DateTime.now().add(const Duration(seconds: 60));
          if (value['deliveryStatus'] == 'failed') {
            _error = 'Chưa gửi được mã mới. Vui lòng thử lại sau 60 giây.';
            return;
          }
          _challenge = value;
          _codeController.clear();
          _attemptsRemaining = 5;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Xác thực OTP'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nhập mã OTP gửi đến ${_challenge['targetMasked']}.'),
          const SizedBox(height: 8),
          Text(
            _challenge['deliveryStatus'] == 'failed'
                ? 'Chưa gửi được SMS. Vui lòng gửi lại.'
                : _secondsLeft == 0
                ? 'Mã đã hết hạn. Vui lòng gửi lại.'
                : 'Mã hết hạn sau ${_secondsLeft ~/ 60}:${(_secondsLeft % 60).toString().padLeft(2, '0')}.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            enabled: _canConfirm,
            controller: _codeController,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _confirm(),
            decoration: InputDecoration(
              hintText: '••••••',
              errorText: _error,
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _attemptsRemaining == 0
                ? 'Đã nhập sai 5 lần. Vui lòng yêu cầu mã mới.'
                : 'Còn $_attemptsRemaining lần nhập mã.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          TextButton(
            onPressed: _busy || _resendWait > 0 || _resendCount >= _maxResends
                ? null
                : _resend,
            child: Text(
              _resendCount >= _maxResends
                  ? 'Đã đạt giới hạn gửi lại'
                  : _resendWait > 0
                  ? 'Gửi lại sau $_resendWait giây'
                  : 'Gửi lại OTP',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _canConfirm ? _confirm : null,
          child: Text(_busy ? 'Đang xử lý…' : 'Xác nhận'),
        ),
      ],
    ),
  );
}
