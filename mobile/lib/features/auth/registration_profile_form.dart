import 'package:flutter/material.dart';

import '../../app_colors.dart';

import 'auth_form_style.dart';
import 'auth_policies_dialog.dart';
import 'parent_role.dart';
import '../../services/auth_service.dart';

Future<void> showAuthPolicies(BuildContext context) async {
  try {
    final docs = await AuthService.instance.documents();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AuthPoliciesDialog(documents: docs),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa tải được điều khoản. Vui lòng thử lại.'),
        ),
      );
    }
  }
}

class RegistrationProfileForm extends StatelessWidget {
  const RegistrationProfileForm({
    super.key,
    required this.name,
    required this.role,
    required this.accepted,
    required this.enabled,
    required this.onRole,
    required this.onAccepted,
    this.showConsentError = false,
    this.nameFocus,
  });
  final TextEditingController name;
  final FocusNode? nameFocus;
  final ParentRole? role;
  final bool accepted, enabled, showConsentError;
  final ValueChanged<ParentRole> onRole;
  final ValueChanged<bool> onAccepted;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Tên hiển thị', style: authSproutFieldLabelStyle),
      const SizedBox(height: 8),
      TextFormField(
        key: const ValueKey('registration-name'),
        controller: name,
        focusNode: nameFocus,
        enabled: enabled,
        textCapitalization: TextCapitalization.words,
        autofillHints: const [AutofillHints.name],
        decoration: authInputDecoration(
          greenSprout: true,
          hint: 'Nhập tên hiển thị',
          icon: Icons.badge_outlined,
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text.isEmpty) return 'Vui lòng nhập tên hiển thị.';
          if (text.characters.length > 50) {
            return 'Tên hiển thị tối đa 50 ký tự.';
          }
          if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(text)) {
            return 'Tên hiển thị chứa ký tự không hợp lệ.';
          }
          return null;
        },
      ),
      const SizedBox(height: 20),
      const Text('Mối quan hệ với bé', style: authSproutFieldLabelStyle),
      const SizedBox(height: 8),
      FormField<ParentRole>(
        key: ValueKey(role),
        initialValue: role,
        validator: (_) => role == null ? 'Vui lòng chọn vai trò với bé.' : null,
        builder: (field) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in ParentRole.values)
                  ChoiceChip(
                    selectedColor: HomeColors.iconBackground,
                    backgroundColor: HomeColors.surface,
                    side: BorderSide(
                      color: item == role
                          ? HomeColors.primary
                          : HomeColors.iconBackground,
                    ),
                    label: Text(
                      item == ParentRole.guardian ? 'Khác' : item.label,
                    ),
                    selected: item == role,
                    onSelected: enabled ? (_) => onRole(item) : null,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
              ],
            ),
            if (field.hasError)
              Text(
                field.errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Material(
        color: Colors.transparent,
        child: CheckboxListTile(
          key: const ValueKey('registration-consent'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: accepted,
          onChanged: enabled ? (value) => onAccepted(value ?? false) : null,
          title: const Text(
            'Tôi đồng ý với Điều khoản sử dụng và Chính sách quyền riêng tư',
          ),
        ),
      ),
      if (showConsentError && !accepted)
        Text(
          'Vui lòng đồng ý với điều khoản và chính sách.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      TextButton(
        onPressed: enabled ? () => showAuthPolicies(context) : null,
        child: const Text('Đọc điều khoản và chính sách'),
      ),
    ],
  );
}
