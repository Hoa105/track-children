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
  Timer? _timer;
  int get _wait =>
      DateTime.parse(_challenge['resendAvailableAt'] as String)
          .difference(DateTime.now())
          .inSeconds
          .clamp(0, 3600);

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
    if (_busy) return;
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
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final value = await AuthService.instance.resend(_challenge);
      if (mounted) {
        setState(() {
          _challenge = value;
          _codeController.clear();
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
                : 'Mã có hiệu lực trong 5 phút.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            enabled: !_busy,
            controller: _codeController,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 6,
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
          TextButton(
            onPressed: _busy || _wait > 0 ? null : _resend,
            child: Text(_wait > 0 ? 'Gửi lại sau $_wait giây' : 'Gửi lại OTP'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _busy ? null : _confirm,
          child: Text(_busy ? 'Đang xử lý…' : 'Xác nhận'),
        ),
      ],
    ),
  );
}
