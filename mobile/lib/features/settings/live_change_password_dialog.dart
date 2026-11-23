import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/demo_store.dart';

class LiveChangePasswordDialog extends StatefulWidget {
  const LiveChangePasswordDialog({super.key});

  @override
  State<LiveChangePasswordDialog> createState() =>
      _LiveChangePasswordDialogState();
}

class _LiveChangePasswordDialogState extends State<LiveChangePasswordDialog> {
  bool _saving = false;
  String? _error;
  bool _obscureCurrent = true;
  bool _obscureNext = true;
  bool _obscureConfirm = true;

  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (AuthService.instance.signedIn && !AuthService.instance.demoMode) {
        await AuthService.instance.changePassword(
          currentPassword: _current.text,
          newPassword: _next.text,
        );
      } else {
        final currentDemoPass =
            DemoStore.instance.parent['password'] as String? ?? '';
        if (currentDemoPass.isNotEmpty && _current.text != currentDemoPass) {
          throw AuthException(
            'INVALID_CREDENTIALS',
            {'message': 'Mật khẩu hiện tại chưa đúng.'},
          );
        }
        await DemoStore.instance.saveParent({'password': _next.text});
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is AuthException
              ? (e.code == 'INVALID_CREDENTIALS'
                    ? 'Mật khẩu hiện tại chưa đúng.'
                    : e.toString())
              : 'Chưa đổi được mật khẩu. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _requiredValue(String? value) =>
      value == null || value.isEmpty ? 'Vui lòng nhập mật khẩu.' : null;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      backgroundColor: SettingsColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text(
        'Đổi mật khẩu',
        style: TextStyle(
          color: SettingsColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                enabled: !_saving,
                controller: _current,
                obscureText: _obscureCurrent,
                validator: _requiredValue,
                style: const TextStyle(color: SettingsColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Mật khẩu hiện tại',
                  labelStyle: const TextStyle(
                    color: SettingsColors.textSecondary,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrent
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: SettingsColors.textSecondary,
                    ),
                    onPressed: () => setState(
                      () => _obscureCurrent = !_obscureCurrent,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: SettingsColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: SettingsColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                enabled: !_saving,
                controller: _next,
                obscureText: _obscureNext,
                validator: (value) {
                  if (value == null || value.length < 8 || value.length > 64) {
                    return 'Mật khẩu mới cần từ 8 đến 64 ký tự.';
                  }
                  if (value == _current.text) {
                    return 'Mật khẩu mới phải khác mật khẩu hiện tại.';
                  }
                  return null;
                },
                style: const TextStyle(color: SettingsColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Mật khẩu mới',
                  helperText: 'Tối thiểu 8 ký tự',
                  helperStyle: const TextStyle(
                    color: SettingsColors.textSecondary,
                  ),
                  labelStyle: const TextStyle(
                    color: SettingsColors.textSecondary,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNext
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: SettingsColors.textSecondary,
                    ),
                    onPressed: () => setState(() => _obscureNext = !_obscureNext),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: SettingsColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: SettingsColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                enabled: !_saving,
                controller: _confirm,
                obscureText: _obscureConfirm,
                validator: (value) =>
                    value != _next.text ? 'Mật khẩu chưa trùng khớp.' : null,
                style: const TextStyle(color: SettingsColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Xác nhận mật khẩu mới',
                  labelStyle: const TextStyle(
                    color: SettingsColors.textSecondary,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: SettingsColors.textSecondary,
                    ),
                    onPressed: () => setState(
                      () => _obscureConfirm = !_obscureConfirm,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: SettingsColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: SettingsColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFB44545),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: SettingsColors.textSecondary,
          ),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: SettingsColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Xác nhận'),
        ),
      ],
    ),
  );
}
