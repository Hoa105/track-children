import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_text_field.dart';

/// Shows a mock OTP verification dialog for [phone]. Returns true if the
/// (mock) code was accepted, false/null if the user cancelled.
Future<bool> showOtpVerificationDialog(BuildContext context, {required String phone}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _OtpDialog(phone: phone),
  );
  return result ?? false;
}

class _OtpDialog extends StatefulWidget {
  const _OtpDialog({required this.phone});
  final String phone;

  @override
  State<_OtpDialog> createState() => _OtpDialogState();
}

class _OtpDialogState extends State<_OtpDialog> {
  final _codeCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_codeCtrl.text.trim().length != 6) {
      setState(() => _error = 'Mã OTP gồm 6 chữ số');
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Xác thực OTP'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nhập mã OTP đã gửi đến số ${widget.phone}',
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            hint: '••••••',
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.danger)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Hủy')),
        TextButton(onPressed: _confirm, child: const Text('Xác nhận')),
      ],
    );
  }
}
