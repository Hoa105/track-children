import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_colors.dart';

Future<bool?> showOtpVerificationDialog(
  BuildContext context, {
  required String phone,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => OtpDialog(phone: phone),
);

class OtpDialog extends StatefulWidget {
  const OtpDialog({required this.phone, super.key});

  final String phone;

  @override
  State<OtpDialog> createState() => _OtpDialogState();
}

class _OtpDialogState extends State<OtpDialog> {
  final _codeController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_codeController.text == '123456') {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _error = 'Mã OTP chưa đúng.');
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Xác thực OTP'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nhập mã OTP đã gửi đến số ${widget.phone}.'),
        const SizedBox(height: 8),
        const Text(
          'Bản xem trước dùng mã 123456; hiện chưa gửi SMS.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Hủy'),
      ),
      FilledButton(onPressed: _confirm, child: const Text('Xác nhận')),
    ],
  );
}
