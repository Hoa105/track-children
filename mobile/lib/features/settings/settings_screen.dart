import 'dart:convert';
import 'dart:typed_data';

import '../../services/demo_store.dart';
import '../notifications/notification_settings_screen.dart';

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../account/account_settings_screen.dart';
import '../auth/parent_role.dart';
import '../child/add_child_profile_screen.dart';
import '../child/child_profile_screen.dart';
import '../navigation/app_bottom_navigation_bar.dart';
import '../sharing/shared_with_me_screen.dart';
import 'delete_account_screen.dart';
import '../growth/growth_screen.dart';
import '../explore/explore_screen.dart';
import '../journal/journal_screen.dart';
import 'demo_data_screen.dart';
import 'security_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({this.onLogout, this.childName = 'Bé An', super.key});

  final VoidCallback? onLogout;
  final String childName;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with DemoStoreBinding {
  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _selectLanguage() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: SettingsColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SettingsColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Lựa chọn ngôn ngữ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: SettingsColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: SettingsColors.background,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: SettingsColors.border),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: SettingsColors.iconBackground,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text('🇻🇳', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                      title: const Text(
                        'Tiếng Việt',
                        style: TextStyle(
                          color: SettingsColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        'Ngôn ngữ mặc định của ứng dụng',
                        style: TextStyle(
                          color: SettingsColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.check_circle_rounded,
                        color: SettingsColors.primary,
                        size: 22,
                      ),
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Divider(height: 1, color: SettingsColors.border),
                    ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: SettingsColors.border.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text('🇬🇧', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                      title: const Text(
                        'English',
                        style: TextStyle(
                          color: SettingsColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        'Tiếng Anh',
                        style: TextStyle(
                          color: SettingsColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: SettingsColors.border,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Sắp ra mắt',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: SettingsColors.textSecondary,
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        _toast('Ngôn ngữ Tiếng Anh sẽ được hỗ trợ trong phiên bản kế tiếp.');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPrivacyPolicy() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: SettingsColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: SettingsColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_rounded, color: SettingsColors.primary, size: 24),
                SizedBox(width: 8),
                Text(
                  'Chính sách quyền riêng tư',
                  style: TextStyle(
                    color: SettingsColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _privacyItem(
                      icon: Icons.child_care_rounded,
                      title: 'Bảo vệ dữ liệu của bé',
                      content:
                          'Mọi thông tin về sự phát triển của bé (chỉ số chiều cao, cân nặng theo chuẩn WHO, lịch tiêm chủng, mọc răng) chỉ phục vụ cho việc theo dõi sức khỏe và chăm sóc của gia đình bạn.',
                    ),
                    const SizedBox(height: 12),
                    _privacyItem(
                      icon: Icons.people_alt_outlined,
                      title: 'Quyền kiểm soát của phụ huynh',
                      content:
                          'Chỉ cha mẹ hoặc người thân được bạn chủ động gửi lời mời mới có quyền xem hoặc ghi nhận thông tin của bé. Bạn có toàn quyền thu hồi quyền chia sẻ bất cứ lúc nào.',
                    ),
                    const SizedBox(height: 12),
                    _privacyItem(
                      icon: Icons.lock_outline_rounded,
                      title: 'Bảo mật & Lưu trữ an toàn',
                      content:
                          'Dữ liệu được lưu trữ an toàn trên thiết bị và được mã hóa đường truyền khi đồng bộ hóa với hệ thống đám mây, đảm bảo sự riêng tư tuyệt đối cho gia đình bạn.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: SettingsColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Đã hiểu',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  static Widget _privacyItem({
    required IconData icon,
    required String title,
    required String content,
  }) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: SettingsColors.background,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: SettingsColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: SettingsColors.iconBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: SettingsColors.textPrimary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: SettingsColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: const TextStyle(
                  color: SettingsColors.textPrimary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SettingsColors.surface,
        title: const Text(
          'Đăng xuất?',
          style: TextStyle(
            color: SettingsColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'Bạn có muốn đăng xuất khỏi tài khoản này không?',
          style: TextStyle(color: SettingsColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: SettingsColors.textSecondary,
            ),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: SettingsColors.primary,
              foregroundColor: Colors.white,
            ),
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
    } else if (destination == 'Tạo ghi chép' || destination == 'Thêm nhật ký') {
      openAddJournal(context);
    } else if (destination != 'Cá nhân') {
      _toast('$destination sẽ được làm ở bước sau.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SettingsColors.background,
    appBar: AppBar(
      backgroundColor: SettingsColors.background,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: SettingsColors.textPrimary),
      title: const Text(
        'Cài đặt & Quyền riêng tư',
        style: TextStyle(
          color: SettingsColors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
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
                              onSessionExpired: widget.onLogout,
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
                                builder: (_) => const SharedWithMeScreen(),
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
                            child: ListTile(
                              leading: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: SettingsColors.iconBackground,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.notifications_outlined,
                                  color: SettingsColors.textPrimary,
                                  size: 20,
                                ),
                              ),
                              title: const Text(
                                'Thông báo & nhắc nhở',
                                style: TextStyle(
                                  color: SettingsColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: const Text(
                                'Giờ nhắc hằng ngày và chu kỳ cập nhật số đo',
                                style: TextStyle(
                                  color: SettingsColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                                color: SettingsColors.textSecondary,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const NotificationSettingsScreen(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const _SectionHeading('QUYỀN RIÊNG TƯ & BẢO MẬT'),
                      _SettingsGroup(
                        children: [
                          _SettingsActionTile(
                            icon: Icons.shield_outlined,
                            title: 'Bảo mật tài khoản',
                            subtitle:
                                'Mật khẩu, xác minh, sinh trắc học và phiên đăng nhập',
                            onTap: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) =>
                                    SecurityScreen(onDeleted: widget.onLogout),
                              ),
                            ),
                          ),
                          _SettingsActionTile(
                            icon: Icons.delete_outline_rounded,
                            title: 'Xóa tài khoản và dữ liệu',
                            subtitle:
                                'Xóa vĩnh viễn tài khoản và các hồ sơ trẻ sở hữu',
                            destructive: true,
                            onTap: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => DeleteAccountScreen(
                                  onDeleted: widget.onLogout,
                                ),
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
                          label: const Text(
                            'Đăng xuất',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB44545),
                            side: const BorderSide(color: Color(0xFFD57C7C)),
                            backgroundColor: SettingsColors.surface,
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
                        style: TextButton.styleFrom(
                          foregroundColor: SettingsColors.primary,
                        ),
                        icon: const Icon(Icons.science_outlined),
                        label: const Text(
                          'Dữ liệu kiểm thử · chỉ lưu trên thiết bị',
                        ),
                      ),
                      Text(
                        'Bé Lớn Khôn · phiên bản 1.0.0',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: SettingsColors.textSecondary,
                        ),
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
  Widget build(BuildContext context) {
    final fullName = DemoStore.instance.parent['fullName'] as String;
    final initial = fullName.isEmpty ? '?' : fullName.substring(0, 1);
    final avatarBase64 = DemoStore.instance.parent['avatar_base64'] as String?;
    Uint8List? avatarBytes;
    if (avatarBase64 != null && avatarBase64.isNotEmpty) {
      try {
        avatarBytes = base64Decode(avatarBase64);
      } catch (_) {}
    }
    return Material(
      color: SettingsColors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: SettingsColors.border),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SettingsColors.iconBackground,
                  border: Border.all(color: SettingsColors.surface, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: avatarBytes != null
                    ? Image.memory(
                        avatarBytes,
                        fit: BoxFit.cover,
                        width: 64,
                        height: 64,
                      )
                    : Text(
                        initial,
                        style: const TextStyle(
                          color: SettingsColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        color: SettingsColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DemoStore.instance.parent['email'] as String,
                      style: const TextStyle(
                        color: SettingsColors.textSecondary,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: SettingsColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
        color: SettingsColors.textSecondary,
        fontWeight: FontWeight.w800,
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
    color: SettingsColors.surface,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: SettingsColors.border),
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
    indent: 66,
    endIndent: 16,
    color: SettingsColors.border,
  );
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: destructive
              ? const Color(0xFFFDE8E8)
              : SettingsColors.iconBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: destructive
              ? const Color(0xFFB44545)
              : SettingsColors.textPrimary,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: destructive
              ? const Color(0xFFB44545)
              : SettingsColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: const TextStyle(
                color: SettingsColors.textSecondary,
                fontSize: 12.5,
              ),
            )
          : null,
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: SettingsColors.textSecondary,
      ),
      onTap: onTap,
      minVerticalPadding: 12,
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

  Widget _content(BuildContext context) {
    final children = DemoStore.instance.children;
    return Scaffold(
      backgroundColor: SettingsColors.background,
      appBar: AppBar(
        backgroundColor: SettingsColors.background,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: SettingsColors.textPrimary),
        title: const Text(
          'Quản lý hồ sơ trẻ',
          style: TextStyle(
            color: SettingsColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          if (!DemoStore.instance.signedIn && children.isEmpty)
            const _ChildProfileSettingsTile(
              name: 'Bé An',
              age: '24 tháng',
              gender: 'female',
            ),
          if (children.isEmpty && DemoStore.instance.signedIn)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: SettingsColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SettingsColors.border),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.child_care_rounded,
                    size: 40,
                    color: SettingsColors.textSecondary,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Chưa có hồ sơ bé nào.',
                    style: TextStyle(
                      color: SettingsColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Hãy thêm thông tin bé để bắt đầu theo dõi sức khỏe và phát triển.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: SettingsColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          for (final child in children) ...[
            Builder(
              builder: (context) {
                Uint8List? avatarBytes;
                final base64Str = child['avatar_base64'] as String?;
                if (base64Str != null && base64Str.isNotEmpty) {
                  try {
                    avatarBytes = base64Decode(base64Str);
                  } catch (_) {}
                }
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: SettingsColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: SettingsColors.border),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: SettingsColors.iconBackground,
                        shape: BoxShape.circle,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: avatarBytes != null
                          ? Image.memory(
                              avatarBytes,
                              fit: BoxFit.cover,
                              width: 44,
                              height: 44,
                            )
                          : const Icon(
                              Icons.child_care_rounded,
                              color: SettingsColors.textPrimary,
                              size: 24,
                            ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            child['full_name'] as String,
                            style: const TextStyle(
                              color: SettingsColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: SettingsColors.primarySoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            child['gender'] == 'male' ? 'Bé trai' : 'Bé gái',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: SettingsColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        DemoStore.instance.ageLabel(child),
                        style: const TextStyle(
                          color: SettingsColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: SettingsColors.textSecondary,
                    ),
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
                );
              },
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAddChild,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Thêm bé mới',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
        ],
      ),
    );
  }
}

class _ChildProfileSettingsTile extends StatelessWidget {
  const _ChildProfileSettingsTile({
    required this.name,
    required this.age,
    this.gender = 'female',
  });

  final String name;
  final String age;
  final String gender;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: SettingsColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: SettingsColors.border),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: SettingsColors.iconBackground,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.child_care_rounded,
            color: SettingsColors.textPrimary,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: SettingsColors.textPrimary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                age,
                style: const TextStyle(
                  color: SettingsColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.chevron_right_rounded,
          color: SettingsColors.textSecondary,
        ),
      ],
    ),
  );
}
