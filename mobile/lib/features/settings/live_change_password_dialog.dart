import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class LiveChangePasswordDialog extends StatefulWidget {
  const LiveChangePasswordDialog({super.key});

  @override
  State<LiveChangePasswordDialog> createState() =>
      _LiveChangePasswordDialogState();
}

class _LiveChangePasswordDialogState extends State<LiveChangePasswordDialog> {
  bool saving = false;
  String? error;

  Future<void> submit() async {
    if (saving || !formKey.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await AuthService.instance.changePassword(
        currentPassword: current.text,
        newPassword: next.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is AuthException
              ? (e.code == 'INVALID_CREDENTIALS'
                    ? 'Mật khẩu hiện tại chưa đúng.'
                    : e.toString())
              : 'Chưa đổi được mật khẩu. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  final formKey = GlobalKey<FormState>();
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();

  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  String? requiredValue(String? value) =>
      value == null || value.isEmpty ? 'Vui lòng nhập mật khẩu.' : null;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: const Text('Đổi mật khẩu'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                enabled: !saving,
                controller: current,
                obscureText: true,
                validator: requiredValue,
                decoration: const InputDecoration(
                  labelText: 'Mật khẩu hiện tại',
                ),
              ),
              TextFormField(
                enabled: !saving,
                controller: next,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.length < 8 || value.length > 64) {
                    return 'Mật khẩu mới cần từ 8 đến 64 ký tự.';
                  }
                  if (value == current.text) {
                    return 'Mật khẩu mới phải khác mật khẩu cũ.';
                  }
                  return null;
                },
                decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
              ),
              TextFormField(
                enabled: !saving,
                controller: confirm,
                obscureText: true,
                validator: (value) =>
                    value != next.text ? 'Mật khẩu chưa trùng khớp.' : null,
                decoration: const InputDecoration(
                  labelText: 'Xác nhận mật khẩu mới',
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: saving ? null : submit,
          child: saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Xác nhận'),
        ),
      ],
    ),
  );
}
