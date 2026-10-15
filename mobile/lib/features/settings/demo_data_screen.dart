import 'package:flutter/material.dart';

import '../../services/demo_store.dart';

class DemoDataScreen extends StatelessWidget {
  const DemoDataScreen({super.key, this.onReset});
  final VoidCallback? onReset;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Dữ liệu kiểm thử')),
    body: ListenableBuilder(
      listenable: DemoStore.instance,
      builder: (context, _) {
        final store = DemoStore.instance;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Tài khoản test',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const SelectableText(
              'Mẹ: demo@trackchildren.vn\nBố: bo@trackchildren.vn\nMật khẩu mẫu: TreXanh123\nOTP mẫu: xem hướng dẫn trong hộp xác minh.',
            ),
            const SizedBox(height: 16),
            Text(
              'Đang đăng nhập: ${store.parent['fullName']}\nEmail: ${store.parent['email']}',
            ),
            const Divider(height: 32),
            for (final c in store.children)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${c['full_name']} · ${store.ageLabel(c)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'ID: ${c['id']}\nNgày sinh: ${c['date_of_birth'].toString().split('T').first}\nGiới tính: ${c['gender'] == 'male' ? 'Bé trai' : 'Bé gái'}\nSố đo: ${store.records(c['id'] as String).length} lần\nRăng đã mọc: ${store.teeth(c['id'] as String).length}/20\nThành viên: ${(c['members'] as List).length} · Lời mời: ${(c['pending'] as List).length}',
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Kiểm tra: đổi bé → sửa hồ sơ → nhập số đo → quay về Home → đăng xuất/đăng nhập lại. Home, hồ sơ, WHO và lịch sử phải cùng dữ liệu. Tài khoản bố thuộc gia đình riêng để kiểm tra không lẫn hồ sơ.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Dữ liệu lưu cục bộ trên thiết bị. OTP, gửi lời mời, chuyển quyền, xóa tài khoản và sinh trắc chưa nối dịch vụ thật. Mọc răng đã hỗ trợ ghi chép cục bộ; các mục chăm sóc khác/nhật ký hiện có dữ liệu tổng quan mẫu.',
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.restart_alt),
              label: const Text('Khôi phục bộ dữ liệu test'),
              onPressed: () async {
                final yes = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Khôi phục dữ liệu test?'),
                    content: const Text(
                      'Các thay đổi trong bộ dữ liệu test cục bộ sẽ được thay bằng dữ liệu mẫu ban đầu. Các khóa dữ liệu cũ ngoài bộ test này được giữ lại.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Hủy'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
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
