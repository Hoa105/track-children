import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/demo_store.dart';
import '../auth/parent_role.dart';
import '../settings/security_screen.dart';

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

  Uint8List? _avatarBytes;

  bool _isEditing = false;
  bool _isSaving = false;
  bool _hasStartedEditing = false;

  @override
  void initState() {
    super.initState();
    _loadInitialAvatar();
    _refreshProfile();
  }

  void _loadInitialAvatar() {
    final parent = DemoStore.instance.parent;
    final base64String = parent['avatar_base64'] as String?;
    if (base64String != null && base64String.isNotEmpty) {
      try {
        _avatarBytes = base64Decode(base64String);
      } catch (_) {}
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onSessionExpired?.call();
      }
    } catch (_) {
      // Giữ profile đã lưu khi không có kết nối mạng.
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

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource?>(
      context: context,
      backgroundColor: SettingsColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: SettingsColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Ảnh đại diện',
                  style: TextStyle(
                    color: SettingsColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: SettingsColors.iconBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.photo_library_outlined,
                    color: SettingsColors.textPrimary,
                  ),
                ),
                title: const Text(
                  'Chọn từ thư viện ảnh',
                  style: TextStyle(
                    color: SettingsColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: SettingsColors.iconBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: SettingsColors.textPrimary,
                  ),
                ),
                title: const Text(
                  'Chụp ảnh mới',
                  style: TextStyle(
                    color: SettingsColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              if (_avatarBytes != null)
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE8E8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFB44545),
                    ),
                  ),
                  title: const Text(
                    'Gỡ ảnh hiện tại',
                    style: TextStyle(
                      color: Color(0xFFB44545),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _avatarBytes = null;
                      _isEditing = true;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() {
          _avatarBytes = bytes;
          _isEditing = true;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể chọn ảnh. Vui lòng kiểm tra quyền truy cập.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final avatarBase64 =
          _avatarBytes != null ? base64Encode(_avatarBytes!) : null;

      if (AuthService.instance.signedIn) {
        await AuthService.instance.updateProfile(
          displayName: _fullNameController.text.trim(),
          defaultRelationship: _role.registrationValue,
        );
      }

      await DemoStore.instance.saveParent({
        'fullName': _fullNameController.text.trim(),
        'role': _role.name,
        'avatar_base64': avatarBase64,
      });

      if (!mounted) return;
      _fullNameController.text =
          AuthService.instance.user?['displayName'] as String? ??
          _fullNameController.text.trim();
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật thông tin và ảnh đại diện thành công.'),
          behavior: SnackBarBehavior.floating,
        ),
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
            behavior: SnackBarBehavior.floating,
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
    backgroundColor: SettingsColors.background,
    appBar: AppBar(
      backgroundColor: SettingsColors.background,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: SettingsColors.textPrimary),
      title: const Text(
        'Cài đặt tài khoản',
        style: TextStyle(
          color: SettingsColors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          tooltip: _isEditing ? 'Lưu thay đổi' : 'Chỉnh sửa thông tin',
          onPressed: _onEditSavePressed,
          icon: _isSaving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: SettingsColors.primary,
                  ),
                )
              : Icon(
                  _isEditing ? Icons.check_rounded : Icons.edit_outlined,
                  color: SettingsColors.primary,
                ),
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Avatar picker với nút camera tương tác
                        Center(
                          child: GestureDetector(
                            onTap: _pickAvatar,
                            child: Stack(
                              children: [
                                Container(
                                  width: 88,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: SettingsColors.iconBackground,
                                    border: Border.all(
                                      color: SettingsColors.surface,
                                      width: 3.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x1229451E),
                                        blurRadius: 14,
                                        offset: Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: _avatarBytes != null
                                      ? Image.memory(
                                          _avatarBytes!,
                                          fit: BoxFit.cover,
                                        )
                                      : Center(
                                          child: Text(
                                            _initial,
                                            style: const TextStyle(
                                              fontSize: 32,
                                              color: SettingsColors.textPrimary,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: SettingsColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: SettingsColors.surface,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isEditing ? 'Chạm vào ảnh để thay đổi avatar' : _fullNameController.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _isEditing
                                ? SettingsColors.textSecondary
                                : SettingsColors.textPrimary,
                            fontSize: _isEditing ? 13 : 17,
                            fontWeight: _isEditing ? FontWeight.w600 : FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: SettingsColors.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: SettingsColors.border),
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
                              const SizedBox(height: 16),
                              AppTextField(
                                label: 'Tên đăng nhập',
                                controller: _usernameController,
                                readOnly: true,
                                validator: (_) => null,
                                icon: Icons.alternate_email_rounded,
                              ),
                              const SizedBox(height: 16),
                              AppTextField(
                                label: 'Email',
                                controller: _emailController,
                                readOnly: true,
                                validator: (_) => null,
                                keyboardType: TextInputType.emailAddress,
                                icon: Icons.mail_outline_rounded,
                              ),
                              const SizedBox(height: 16),
                              AppTextField(
                                label: 'Số điện thoại',
                                controller: _phoneController,
                                readOnly: true,
                                validator: (_) => null,
                                keyboardType: TextInputType.phone,
                                icon: Icons.phone_outlined,
                              ),
                              const SizedBox(height: 22),
                              Text(
                                'Vai trò với bé',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: SettingsColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
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
                        const SizedBox(height: 16),
                        if (!_isEditing) ...[
                          // Thẻ lối tắt sang Bảo mật tài khoản
                          Container(
                            decoration: BoxDecoration(
                              color: SettingsColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: SettingsColors.border),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: SettingsColors.iconBackground,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.shield_outlined,
                                    color: SettingsColors.textPrimary,
                                    size: 22,
                                  ),
                                ),
                                title: const Text(
                                  'Bảo mật tài khoản',
                                  style: TextStyle(
                                    color: SettingsColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Mật khẩu, xác minh email/SĐT và liên kết',
                                  style: TextStyle(
                                    color: SettingsColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: SettingsColors.textSecondary,
                                ),
                                onTap: () => Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => SecurityScreen(
                                      onDeleted: widget.onSessionExpired,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Chạm vào ảnh đại diện hoặc nút sửa để cập nhật thông tin.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: SettingsColors.textSecondary),
                          ),
                        ] else ...[
                          // Nút Lưu to bản ở cuối thuận tiện cho thao tác 1 tay
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: _isSaving ? null : _save,
                            icon: _isSaving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_rounded),
                            label: Text(
                              _isSaving ? 'Đang lưu…' : 'Lưu thay đổi',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              backgroundColor: SettingsColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: _isSaving
                                ? null
                                : () => setState(() => _isEditing = false),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              foregroundColor: SettingsColors.textSecondary,
                              side: const BorderSide(color: SettingsColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Hủy',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
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
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: SettingsColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        readOnly: readOnly,
        validator: validator,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        onChanged: onChanged,
        style: TextStyle(
          color: readOnly
              ? SettingsColors.textSecondary
              : SettingsColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            icon,
            size: 20,
            color: readOnly
                ? SettingsColors.textSecondary
                : SettingsColors.primary,
          ),
          filled: true,
          fillColor: readOnly
              ? SettingsColors.background.withValues(alpha: 0.4)
              : SettingsColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: SettingsColors.border),
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
    selectedColor: SettingsColors.accent,
    backgroundColor: SettingsColors.surface,
    checkmarkColor: SettingsColors.textPrimary,
    side: BorderSide(
      color: selected ? SettingsColors.primary : SettingsColors.border,
    ),
    labelStyle: TextStyle(
      color: SettingsColors.textPrimary,
      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}
