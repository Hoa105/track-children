import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_colors.dart';
import '../../services/demo_store.dart';

class DemoDataScreen extends StatelessWidget {
  const DemoDataScreen({super.key, this.onReset});
  final VoidCallback? onReset;

  void _copy(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép $label vào bộ nhớ tạm.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SettingsColors.background,
    appBar: AppBar(
      backgroundColor: SettingsColors.background,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: SettingsColors.textPrimary),
      title: const Text(
        'Dữ liệu kiểm thử',
        style: TextStyle(
          color: SettingsColors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      centerTitle: true,
    ),
    body: ListenableBuilder(
      listenable: DemoStore.instance,
      builder: (context, _) {
        final store = DemoStore.instance;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SettingsColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: SettingsColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: SettingsColors.iconBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.science_outlined,
                          color: SettingsColors.textPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Tài khoản kiểm thử',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: SettingsColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _AccountRow(
                    role: 'Tài khoản Mẹ',
                    email: 'demo@trackchildren.vn',
                    password: 'TreXanh123',
                    onCopy: (val, label) => _copy(context, val, label),
                  ),
                  const Divider(height: 20, color: SettingsColors.border),
                  _AccountRow(
                    role: 'Tài khoản Bố',
                    email: 'bo@trackchildren.vn',
                    password: 'TreXanh123',
                    onCopy: (val, label) => _copy(context, val, label),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SettingsColors.primarySoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: SettingsColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_circle_outlined,
                    color: SettingsColors.textPrimary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Đang đăng nhập: ${store.parent['fullName']} (${store.parent['email']})',
                      style: const TextStyle(
                        color: SettingsColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'DANH SÁCH HỒ SƠ TRẺ LOCAL (${store.children.length})',
                style: const TextStyle(
                  color: SettingsColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: .6,
                ),
              ),
            ),
            for (final c in store.children)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SettingsColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: SettingsColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: SettingsColors.iconBackground,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.child_care_rounded,
                            color: SettingsColors.textPrimary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${c['full_name']} · ${store.ageLabel(c)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: SettingsColors.textPrimary,
                              fontSize: 15,
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
                            c['gender'] == 'male' ? 'Bé trai' : 'Bé gái',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: SettingsColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '• Ngày sinh: ${c['date_of_birth'].toString().split('T').first}\n'
                      '• Số lần đo: ${store.records(c['id'] as String).length} lần | Răng đã mọc: ${store.teeth(c['id'] as String).length}/20\n'
                      '• Thành viên: ${(c['members'] as List).length} người | Lời mời đang chờ: ${(c['pending'] as List).length}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: SettingsColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SettingsColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: SettingsColors.border),
              ),
              child: const Text(
                'Lưu ý: Dữ liệu này chỉ được lưu trữ cục bộ trên thiết bị của bạn nhằm phục vụ kiểm thử tính năng ngoại tuyến (Offline preview).',
                style: TextStyle(
                  fontSize: 12.5,
                  color: SettingsColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text(
                'Khôi phục bộ dữ liệu test ban đầu',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: SettingsColors.primary,
                side: const BorderSide(color: SettingsColors.primary),
                backgroundColor: SettingsColors.surface,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () async {
                final yes = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: SettingsColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    title: const Text(
                      'Khôi phục dữ liệu test?',
                      style: TextStyle(
                        color: SettingsColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    content: const Text(
                      'Các thay đổi trong bộ dữ liệu test cục bộ sẽ được hoàn tác về dữ liệu mẫu ban đầu.',
                      style: TextStyle(color: SettingsColors.textPrimary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          foregroundColor: SettingsColors.textSecondary,
                        ),
                        child: const Text('Hủy'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: SettingsColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Khôi phục'),
                      ),
                    ],
                  ),
                );
                if (yes != true) return;
                try {
                  await store.resetFixtures();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    onReset?.call();
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Chưa khôi phục được dữ liệu test.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    ),
  );
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.role,
    required this.email,
    required this.password,
    required this.onCopy,
  });

  final String role;
  final String email;
  final String password;
  final void Function(String value, String label) onCopy;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              role,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: SettingsColors.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Email: $email',
              style: const TextStyle(
                color: SettingsColors.textSecondary,
                fontSize: 13,
              ),
            ),
            Text(
              'Mật khẩu: $password',
              style: const TextStyle(
                color: SettingsColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Sao chép thông tin đăng nhập',
        icon: const Icon(
          Icons.copy_rounded,
          color: SettingsColors.primary,
          size: 20,
        ),
        onPressed: () => onCopy('$email | $password', role),
      ),
    ],
  );
}
