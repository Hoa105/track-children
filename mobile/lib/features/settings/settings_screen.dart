import '../../services/demo_store.dart';

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../account/account_settings_screen.dart';
import '../auth/parent_role.dart';
import '../child/add_child_profile_screen.dart';
import '../child/child_profile_screen.dart';
import '../navigation/app_bottom_navigation_bar.dart';
import '../sharing/child_sharing_screen.dart';
import 'delete_account_screen.dart';
import '../growth/growth_screen.dart';
import '../explore/explore_screen.dart';
import 'demo_data_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({this.onLogout, this.childName = 'Bé An', super.key});

  final VoidCallback? onLogout;
  final String childName;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with DemoStoreBinding {
  bool _notificationsEnabled = true;
  bool _biometricEnabled = false;

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<String>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (!mounted || changed == null) return;
    if (DemoStore.instance.signedIn) {
      try {
        await DemoStore.instance.saveParent({'password': changed});
        if (mounted) _toast('Đã đổi mật khẩu tài khoản test.');
      } catch (_) {
        if (mounted) _toast('Chưa lưu được mật khẩu.');
      }
    } else {
      _toast('Đổi mật khẩu chưa được kết nối dịch vụ tài khoản.');
    }
  }

  Future<void> _selectLanguage() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ngôn ngữ'),
        content: const Material(
          color: Colors.transparent,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.check_circle_rounded, color: AppColors.primary),
            title: Text('Tiếng Việt'),
            subtitle: Text('Ngôn ngữ đang sử dụng'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPrivacyPolicy() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Chính sách quyền riêng tư'),
      content: const SingleChildScrollView(
        child: Text(
          'Bé Lớn Khôn hỗ trợ phụ huynh ghi lại thông tin chăm sóc và phát triển của trẻ. '
          'Thông tin hồ sơ chỉ nên được chia sẻ với người chăm sóc mà phụ huynh tin cậy. '
          'Bản xem trước này chưa kết nối hệ thống lưu trữ hoặc xử lý dữ liệu tài khoản.',
          style: TextStyle(height: 1.5),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn có muốn đăng xuất khỏi tài khoản này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    if (widget.onLogout != null) {
      widget.onLogout!();
    } else {
      _toast('Đăng xuất chưa được kết nối trong bản xem trước.');
    }
  }

  void _openChildProfiles() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            _ChildProfilesSettingsScreen(onAddChild: _openAddChildProfile),
      ),
    );
  }

  void _openAddChildProfile() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AddChildProfileScreen(
          onOpenHomePreview: (name) {
            Navigator.of(context).pop();
            _toast('Đã lưu hồ sơ $name trong dữ liệu test.');
          },
        ),
      ),
    );
  }

  void _onNavigationTap(String destination) {
    if (destination == 'Trang chủ') {
      Navigator.of(context)
          .popUntil((route) => route.settings.name == '/home' || route.isFirst);
    } else if (destination == 'Theo dõi') {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => GrowthScreen(
            childName:
                DemoStore.instance.child?['full_name'] as String? ??
                widget.childName,
            onLogout: widget.onLogout,
          ),
        ),
      );
    } else if (destination == 'Khám phá') {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ExploreScreen(onLogout: widget.onLogout),
        ),
      );
    } else if (destination != 'Cá nhân') {
      _toast('$destination sẽ được làm ở bước sau.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      title: const Text('Cài đặt & Quyền riêng tư'),
      centerTitle: true,
    ),
    body: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ParentSummaryCard(
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => AccountSettingsScreen(
                              fullName:
                                  DemoStore.instance.parent['fullName']
                                      as String,
                              username:
                                  DemoStore.instance.parent['username']
                                      as String,
                              email:
                                  DemoStore.instance.parent['email'] as String,
                              phone:
                                  DemoStore.instance.parent['phone'] as String,
                              role: ParentRole.values.byName(
                                DemoStore.instance.parent['role'] as String,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const _SectionHeading('TÀI KHOẢN'),
                      _SettingsGroup(
                        children: [
                          _SettingsActionTile(
                            icon: Icons.lock_outline_rounded,
                            title: 'Đổi mật khẩu',
                            onTap: _changePassword,
                          ),
                          const _SettingsDivider(),
                          _SettingsActionTile(
                            icon: Icons.language_rounded,
                            title: 'Ngôn ngữ: Tiếng Việt',
                            onTap: _selectLanguage,
                          ),
                          const _SettingsDivider(),
                          _SettingsActionTile(
                            icon: Icons.shield_outlined,
                            title: 'Chính sách quyền riêng tư',
                            onTap: _showPrivacyPolicy,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const _SectionHeading('HỒ SƠ TRẺ'),
                      _SettingsGroup(
                        children: [
                          _SettingsActionTile(
                            icon: Icons.child_care_rounded,
                            title: 'Quản lý hồ sơ trẻ',
                            onTap: _openChildProfiles,
                          ),
                          const _SettingsDivider(),
                          _SettingsActionTile(
                            icon: Icons.add_circle_outline_rounded,
                            title: 'Thêm bé mới',
                            onTap: _openAddChildProfile,
                          ),
                          const _SettingsDivider(),
                          _SettingsActionTile(
                            icon: Icons.people_outline_rounded,
                            title: 'Hồ sơ được chia sẻ với tôi',
                            onTap: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => const ChildSharingScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const _SectionHeading('ỨNG DỤNG'),
                      _SettingsGroup(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: SwitchListTile.adaptive(
                              value: DemoStore.instance.signedIn
                                  ? DemoStore.instance.parent['notifications']
                                        as bool
                                  : _notificationsEnabled,
                              onChanged: (value) => DemoStore.instance.signedIn
                                  ? DemoStore.instance.saveParent({
                                      'notifications': value,
                                    })
                                  : setState(
                                      () => _notificationsEnabled = value,
                                    ),
                              activeThumbColor: AppColors.primary,
                              secondary: const Icon(
                                Icons.notifications_outlined,
                                color: AppColors.primary,
                              ),
                              title: const Text('Thông báo & nhắc nhở'),
                              subtitle: const Text(
                                'Mốc đánh giá, tăng trưởng và tiêm chủng',
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const _SectionHeading('QUYỀN RIÊNG TƯ & BẢO MẬT'),
                      _SettingsGroup(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: SwitchListTile.adaptive(
                              value: DemoStore.instance.signedIn
                                  ? DemoStore.instance.parent['biometric']
                                        as bool
                                  : _biometricEnabled,
                              onChanged: (value) => DemoStore.instance.signedIn
                                  ? DemoStore.instance.saveParent({
                                      'biometric': value,
                                    })
                                  : setState(() => _biometricEnabled = value),
                              activeThumbColor: AppColors.primary,
                              secondary: const Icon(
                                Icons.fingerprint_rounded,
                                color: AppColors.primary,
                              ),
                              title: const Text('Khóa ứng dụng bằng sinh trắc'),
                              subtitle: const Text('Vân tay hoặc Face ID'),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                            ),
                          ),
                          const _SettingsDivider(),
                          _SettingsActionTile(
                            icon: Icons.delete_outline_rounded,
                            title: 'Xóa tài khoản và dữ liệu',
                            destructive: true,
                            onTap: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => const DeleteAccountScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Đăng xuất'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB44545),
                            side: const BorderSide(color: Color(0xFFD57C7C)),
                            backgroundColor: AppColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                DemoDataScreen(onReset: widget.onLogout),
                          ),
                        ),
                        icon: const Icon(Icons.science_outlined),
                        label: const Text(
                          'Dữ liệu kiểm thử · chỉ lưu trên thiết bị',
                        ),
                      ),
                      Text(
                        'Bé Lớn Khôn · phiên bản 1.0.0',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    bottomNavigationBar: AppBottomNavigationBar(
      selected: 'Cá nhân',
      onTap: _onNavigationTap,
    ),
  );
}

class _ParentSummaryCard extends StatelessWidget {
  const _ParentSummaryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A23332E),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            EmptyAvatar(
              initial: (DemoStore.instance.parent['fullName'] as String)
                  .substring(0, 1),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DemoStore.instance.parent['fullName'] as String,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    DemoStore.instance.parent['email'] as String,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
          ],
        ),
      ),
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
        letterSpacing: .7,
      ),
    ),
  );
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.circular(20),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) => const Divider(
    height: 1,
    indent: 56,
    endIndent: 16,
    color: AppColors.border,
  );
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: ListTile(
      leading: Icon(
        icon,
        color: destructive ? const Color(0xFFB44545) : AppColors.primary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: destructive ? const Color(0xFFB44545) : AppColors.textPrimary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textSecondary,
      ),
      onTap: onTap,
      minVerticalPadding: 12,
    ),
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      (value?.isNotEmpty ?? false) ? null : 'Vui lòng nhập mật khẩu.';

  String? _validateNew(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu mới.';
    if (value.length < 6) return 'Mật khẩu cần có ít nhất 6 ký tự.';
    if (value == _currentController.text) {
      return 'Mật khẩu mới cần khác mật khẩu hiện tại.';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng xác nhận mật khẩu.';
    if (value != _newController.text) return 'Mật khẩu chưa trùng khớp.';
    return null;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Đổi mật khẩu'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PasswordField(
              label: 'Mật khẩu hiện tại',
              controller: _currentController,
              validator: (value) =>
                  _required(value) ??
                  (DemoStore.instance.signedIn &&
                          value != DemoStore.instance.parent['password']
                      ? 'Mật khẩu hiện tại chưa đúng.'
                      : null),
            ),
            const SizedBox(height: 14),
            _PasswordField(
              label: 'Mật khẩu mới',
              controller: _newController,
              validator: _validateNew,
            ),
            const SizedBox(height: 14),
            _PasswordField(
              label: 'Xác nhận mật khẩu mới',
              controller: _confirmController,
              validator: _validateConfirm,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.of(context).pop(_newController.text);
          }
        },
        child: const Text('Xác nhận'),
      ),
    ],
  );
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    required this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?) validator;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: _obscure,
    validator: widget.validator,
    decoration: InputDecoration(
      labelText: widget.label,
      suffixIcon: IconButton(
        tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

class _ChildProfilesSettingsScreen extends StatelessWidget {
  const _ChildProfilesSettingsScreen({required this.onAddChild});

  final VoidCallback onAddChild;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: DemoStore.instance,
    builder: (context, _) => _content(context),
  );
  Widget _content(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      title: const Text('Quản lý hồ sơ trẻ'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!DemoStore.instance.signedIn)
          const _ChildProfileSettingsTile(name: 'Bé An', age: '24 tháng'),
        for (final child in DemoStore.instance.children)
          ListTile(
            leading: const Icon(Icons.child_care_rounded),
            title: Text(child['full_name'] as String),
            subtitle: Text(DemoStore.instance.ageLabel(child)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChildProfileScreen(
                  initialFields: child,
                  onSave: (fields, avatar) => DemoStore.instance
                      .saveChild(child['id'] as String, fields)
                      .then((_) {}),
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onAddChild,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Thêm bé mới'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ChildProfileSettingsTile extends StatelessWidget {
  const _ChildProfileSettingsTile({required this.name, required this.age});

  final String name;
  final String age;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: AppColors.primarySoft,
          child: Icon(Icons.child_care_rounded, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(age, style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
      ],
    ),
  );
}
