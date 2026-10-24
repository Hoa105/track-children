import '../../services/demo_store.dart';

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../services/auth_service.dart';
import '../auth/parent_role.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({
    this.fullName = 'Trần Lạc Quan',
    this.username = 'quan_tran',
    this.email = 'quan@email.com',
    this.phone = '0912345678',
    this.role = ParentRole.mother,
    this.onSessionExpired,
    super.key,
  });

  final String fullName;
  final String username;
  final String email;
  final String phone;
  final ParentRole role;
  final VoidCallback? onSessionExpired;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _fullNameController = TextEditingController(text: widget.fullName);
  late final _usernameController = TextEditingController(text: widget.username);
  late final _emailController = TextEditingController(text: widget.email);
  late final _phoneController = TextEditingController(text: widget.phone);
  late ParentRole _role = widget.role;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _hasStartedEditing = false;

  @override
  void initState() {
    super.initState();
    _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    final auth = AuthService.instance;
    if (!auth.signedIn || auth.demoMode) return;
    try {
      final profile = await auth.currentUser();
      if (!mounted || _hasStartedEditing) return;
      setState(() {
        _fullNameController.text =
            profile['displayName'] as String? ??
            profile['fullName'] as String? ??
            '';
        _emailController.text = profile['email'] as String? ?? '';
        _phoneController.text = profile['phone'] as String? ?? '';
        final role = profile['defaultRelationship'] ?? profile['relationship'];
        _role = ParentRole.values.firstWhere(
          (value) => value.registrationValue == role,
          orElse: () => ParentRole.guardian,
        );
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      if (!auth.signedIn) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
        widget.onSessionExpired?.call();
      }
      // Keep the cached profile available when the network is unavailable.
    } catch (_) {
      // A background refresh must not prevent reading or editing cached data.
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value) =>
      (value?.trim().isNotEmpty ?? false) ? null : 'Thông tin này là bắt buộc.';

  Future<void> _save() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      if (AuthService.instance.signedIn) {
        await AuthService.instance.updateProfile(
          displayName: _fullNameController.text,
          defaultRelationship: _role.registrationValue,
        );
      } else if (DemoStore.instance.signedIn) {
        await DemoStore.instance.saveParent({
          'fullName': _fullNameController.text.trim(),
          'role': _role.name,
        });
      } else {
        throw AuthException('SESSION_EXPIRED', {});
      }
      if (!mounted) return;
      _fullNameController.text =
          AuthService.instance.user?['displayName'] as String? ??
          _fullNameController.text.trim();
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu thay đổi thông tin tài khoản.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is AuthException
                  ? error.toString()
                  : 'Chưa lưu được thông tin. Vui lòng thử lại.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _onEditSavePressed() {
    if (_isSaving) return;
    if (_isEditing) {
      _save();
    } else {
      _hasStartedEditing = true;
      setState(() => _isEditing = true);
    }
  }

  String get _initial {
    final name = _fullNameController.text.trim();
    return name.isEmpty
        ? '?'
        : String.fromCharCode(name.runes.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      title: const Text('Cài đặt tài khoản'),
      centerTitle: true,
      actions: [
        IconButton(
          tooltip: _isEditing ? 'Lưu' : 'Chỉnh sửa',
          onPressed: _onEditSavePressed,
          icon: _isSaving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(_isEditing ? Icons.check_rounded : Icons.edit_outlined),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: EmptyAvatar(initial: _initial)),
                        const SizedBox(height: 12),
                        Text(
                          _fullNameController.text,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.border),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A23332E),
                                blurRadius: 16,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppTextField(
                                label: 'Họ và tên',
                                controller: _fullNameController,
                                readOnly: !_isEditing || _isSaving,
                                validator: _validateRequired,
                                icon: Icons.person_outline_rounded,
                                textCapitalization: TextCapitalization.words,
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 18),
                              AppTextField(
                                label: 'Tên đăng nhập',
                                controller: _usernameController,
                                readOnly: true,
                                validator: (_) => null,
                                icon: Icons.alternate_email_rounded,
                              ),
                              const SizedBox(height: 18),
                              AppTextField(
                                label: 'Email',
                                controller: _emailController,
                                readOnly: true,
                                validator: (_) => null,
                                keyboardType: TextInputType.emailAddress,
                                icon: Icons.mail_outline_rounded,
                              ),
                              const SizedBox(height: 18),
                              AppTextField(
                                label: 'Số điện thoại',
                                controller: _phoneController,
                                readOnly: true,
                                validator: (_) => null,
                                keyboardType: TextInputType.phone,
                                icon: Icons.phone_outlined,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Vai trò với bé',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final role in ParentRole.values)
                                    _RoleChip(
                                      role: role,
                                      selected: _role == role,
                                      enabled: _isEditing && !_isSaving,
                                      onSelected: () =>
                                          setState(() => _role = role),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (!_isEditing) ...[
                          const SizedBox(height: 14),
                          Text(
                            'Chọn biểu tượng chỉnh sửa để cập nhật thông tin.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class EmptyAvatar extends StatelessWidget {
  const EmptyAvatar({required this.initial, super.key});

  final String initial;

  @override
  Widget build(BuildContext context) => Container(
    width: 72,
    height: 72,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.primarySoft,
      border: Border.all(color: AppColors.surface, width: 3),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1423332E),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Text(
      initial,
      style: Theme.of(context).textTheme.headlineMedium
          ?.copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.w700),
    ),
  );
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    required this.controller,
    required this.readOnly,
    required this.validator,
    required this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final bool readOnly;
  final String? Function(String?) validator;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: AppColors.textPrimary),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        readOnly: readOnly,
        validator: validator,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        onChanged: onChanged,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 21),
          filled: true,
          fillColor: readOnly
              ? const Color(0xFFF7F6F1)
              : const Color(0xFFFCFBF8),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    ],
  );
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.role,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final ParentRole role;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(role.label),
    selected: selected,
    onSelected: enabled ? (_) => onSelected() : null,
    selectedColor: AppColors.primarySoft,
    checkmarkColor: AppColors.primary,
    side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
    labelStyle: TextStyle(
      color: selected ? AppColors.primaryDark : AppColors.textPrimary,
    ),
  );
}
