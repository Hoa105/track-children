import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../app_layout.dart';
import '../../services/app_notifications.dart';
import '../../services/demo_store.dart';
import '../vaccination/vaccination_screen.dart';

const _heading = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w700,
  color: AppColors.textPrimary,
);
const _body = TextStyle(
  fontSize: 14,
  height: 1.5,
  color: AppColors.textPrimary,
);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _unreadOnly = false, _busy = false;
  Future<bool> _markRead(Iterable<String> ids) async {
    setState(() => _busy = true);
    try {
      final store = DemoStore.instance;
      await store.saveParent({
        'readNotifications': {...readNotificationIds(store), ...ids}.toList(),
      });
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa lưu được trạng thái đã đọc. Vui lòng thử lại.'),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(CareNotification notification) async {
    if (!await _markRead([notification.id]) || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => VaccinationScreen(childId: notification.childId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: DemoStore.instance,
    builder: (context, _) {
      final store = DemoStore.instance;
      final all = careNotifications(store);
      final read = readNotificationIds(store);
      final unread = all.where((n) => !read.contains(n.id)).length;
      final entries = all
          .where((n) => !_unreadOnly || !read.contains(n.id))
          .toList();
      final enabled = store.parent['notifications'] != false;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('Thông báo', style: _heading),
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppLayout.pagePadding),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.notifications_active_outlined,
                    color: AppColors.primary,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    unread == 0
                        ? 'Bạn đã xem hết thông báo'
                        : '$unread thông báo chưa đọc',
                    style: _heading,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Theo dõi lịch dự kiến của các bé trong gia đình.',
                    style: _body,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Tất cả'),
                  selected: !_unreadOnly,
                  onSelected: (_) => setState(() => _unreadOnly = false),
                ),
                ChoiceChip(
                  label: Text('Chưa đọc ($unread)'),
                  selected: _unreadOnly,
                  onSelected: (_) => setState(() => _unreadOnly = true),
                ),
                TextButton.icon(
                  onPressed: _busy || unread == 0
                      ? null
                      : () => _markRead(all.map((n) => n.id)),
                  icon: const Icon(Icons.done_all_rounded),
                  label: const Text('Đọc tất cả'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 16,
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      size: 56,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      !enabled
                          ? 'Thông báo đang tắt'
                          : _unreadOnly
                          ? 'Không có thông báo chưa đọc'
                          : 'Chưa có thông báo mới',
                      style: _heading,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      !enabled
                          ? 'Bật Thông báo & nhắc nhở trong Cài đặt để xem lịch nhắc.'
                          : 'Lịch tiêm dự kiến trong 7 ngày tới hoặc đã qua không quá 30 ngày sẽ xuất hiện ở đây.',
                      style: _body,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: read.contains(entry.id)
                      ? Colors.white
                      : const Color(0xFFF0F5ED),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _busy ? null : () => _open(entry),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.vaccines_outlined,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  entry.title,
                                  style: _body.copyWith(
                                    fontWeight: read.contains(entry.id)
                                        ? FontWeight.w500
                                        : FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (!read.contains(entry.id))
                                const Padding(
                                  padding: EdgeInsets.only(left: 8, top: 6),
                                  child: Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: AppColors.primary,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(entry.message, style: _body),
                          const SizedBox(height: 12),
                          const Text(
                            'Xem sổ tiêm →',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Lịch dự kiến lấy từ sổ tiêm của bé. Thông báo hiện trong ứng dụng; chưa gửi khi ứng dụng đóng.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    },
  );
}
