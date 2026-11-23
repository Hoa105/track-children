import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../services/app_notifications.dart';
import '../../services/demo_store.dart';
import '../../services/sharing_invitations.dart';
import '../sharing/shared_with_me_screen.dart';
import '../vaccination/vaccination_screen.dart';
import '../assessment/assessment_screen.dart';
import '../assessment/assessment_repository.dart';
import '../assessment/assessment_reminders.dart';
import 'notification_settings_screen.dart';
import '../../services/notification_inbox.dart';
import '../../services/auth_service.dart';
import '../growth/api_growth_repository.dart';
import '../growth/remote_growth_repository.dart';
import '../growth/growth_tracking_flow.dart';
import '../growth/growth_models.dart';

const _heading = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w800,
  color: NotificationColors.ink,
);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.initialNotificationId});
  final String? initialNotificationId;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _unreadOnly = false;
  bool _busy = false;
  String? _kind;

  @override
  void initState() {
    super.initState();
    _loadAssessment();
    SharingInvitations.instance.refresh();
    _refresh();
  }

  Future<void> _refresh() async {
    await NotificationInbox.instance.refresh();
    final id = widget.initialNotificationId;
    if (!mounted || id == null) return;
    final found = careNotifications(DemoStore.instance).where((n) => n.id == id);
    if (found.isNotEmpty) await _open(found.first);
  }

  Future<void> _growthAction(
    CareNotification entry,
    bool enabled, {
    bool snooze = true,
  }) async {
    try {
      await AuthService.instance.authorizedRequest(
        'PUT',
        '/notifications/growth/${entry.childId}/${entry.metric}',
        body: {
          'enabled': enabled,
          'snoozed_until': enabled && snooze
              ? DateTime.now()
                    .add(const Duration(days: 7))
                    .toIso8601String()
                    .split('T')
                    .first
              : null,
        },
      );
      await NotificationInbox.instance.refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa cập nhật được lịch nhắc. Vui lòng thử lại.'),
          ),
        );
      }
    }
  }

  Future<void> _loadAssessment() async {
    final repo = assessmentRepository();
    for (final child in DemoStore.instance.children) {
      try {
        await repo.overview(child['id'] as String);
      } catch (_) {
        /* Keep existing notifications available if assessment API is offline. */
      }
    }
  }

  Future<bool> _markRead(Iterable<String> ids, {bool all = false}) async {
    setState(() => _busy = true);
    try {
      final store = DemoStore.instance;
      await NotificationInbox.instance.markRead(ids, all: all);
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
    if (notification.kind == 'growth') {
      final repo = ApiGrowthRepository(
        remote: RemoteGrowthRepository(notification.childId),
      );
      try {
        await repo.refreshMeasurements();
        if (!mounted) return;
        await openTrackingEditor(
          context,
          repo,
          metric: switch (notification.metric) {
            'weight' => GrowthMetric.weight,
            'height' => GrowthMetric.lengthHeight,
            _ => GrowthMetric.headCircumference,
          },
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chưa mở được hồ sơ bé. Vui lòng thử lại.'),
            ),
          );
        }
      }
      await NotificationInbox.instance.refresh();
      return;
    }
    if (notification.kind == 'system' ||
        (notification.childId.isEmpty && notification.kind != 'sharing')) {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: NotificationColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: NotificationColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: NotificationColors.iconBackground,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: NotificationColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        notification.title,
                        style: _heading.copyWith(fontSize: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  notification.message,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: NotificationColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _formatDate(notification.date),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: NotificationColors.reminderCta,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: FilledButton.styleFrom(
                      backgroundColor: NotificationColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Đóng',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await NotificationInbox.instance.refresh();
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => switch (notification.kind) {
          'sharing' => const SharedWithMeScreen(),
          'assessment' => AssessmentScreen(
            childId: notification.childId,
            initialHistory: notification.resolved,
            initialAge: notification.ageMonths,
          ),
          _ => VaccinationScreen(childId: notification.childId),
        },
      ),
    );
    await NotificationInbox.instance.refresh();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(itemDate).inDays;

    if (diffDays == 0) return 'Hôm nay';
    if (diffDays == 1) return 'Hôm qua';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _categoryLabel(String kind) => switch (kind) {
    'growth' => 'Tăng trưởng',
    'vaccination' => 'Tiêm chủng',
    'assessment' => 'Đánh giá',
    'sharing' => 'Chia sẻ',
    'system' => 'Hệ thống',
    _ => 'Nhắc nhở',
  };

  String _ctaLabel(String kind) => switch (kind) {
    'sharing' => 'Xem lời mời',
    'assessment' => 'Xem đánh giá',
    'growth' => 'Cập nhật số đo',
    'system' => 'Xem chi tiết',
    _ => 'Xem sổ tiêm',
  };

  IconData _categoryIcon(String kind) => switch (kind) {
    'growth' => Icons.monitor_weight_rounded,
    'vaccination' => Icons.vaccines_rounded,
    'assessment' => Icons.fact_check_rounded,
    'sharing' => Icons.group_add_rounded,
    'system' => Icons.notifications_active_rounded,
    _ => Icons.notifications_rounded,
  };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      DemoStore.instance,
      AssessmentReminders.instance,
      SharingInvitations.instance,
      NotificationInbox.instance,
    ]),
    builder: (context, _) {
      final store = DemoStore.instance;
      final all = careNotifications(store);
      final read = readNotificationIds(store);
      final unread = unreadNotificationCount(store);
      final entries = all
          .where((n) => !_unreadOnly || !read.contains(n.id))
          .where((n) => _kind == null || n.kind == _kind)
          .toList();
      final enabled = store.parent['notifications'] != false;

      return Scaffold(
        backgroundColor: NotificationColors.background,
        appBar: AppBar(
          backgroundColor: NotificationColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: const Text('Thông báo', style: _heading),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                tooltip: 'Cài đặt thông báo',
                style: IconButton.styleFrom(
                  backgroundColor: NotificationColors.reminderBackground,
                  minimumSize: const Size(44, 44),
                ),
                icon: const Icon(
                  Icons.tune_rounded,
                  color: NotificationColors.ink,
                  size: 22,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationSettingsScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          color: NotificationColors.primary,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              // Thanh lọc trạng thái & nút Đọc tất cả dễ bấm bằng 1 tay
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Tất cả'),
                    selected: !_unreadOnly && _kind == null,
                    selectedColor: NotificationColors.accent,
                    backgroundColor: NotificationColors.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    labelStyle: TextStyle(
                      color: NotificationColors.ink,
                      fontWeight: !_unreadOnly && _kind == null
                          ? FontWeight.w800
                          : FontWeight.w600,
                      fontSize: 13.5,
                    ),
                    side: const BorderSide(color: NotificationColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    showCheckmark: false,
                    onSelected: (_) => setState(() {
                      _unreadOnly = false;
                      _kind = null;
                    }),
                  ),
                  ChoiceChip(
                    label: Text('Chưa đọc ($unread)'),
                    selected: _unreadOnly,
                    selectedColor: NotificationColors.accent,
                    backgroundColor: NotificationColors.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    labelStyle: TextStyle(
                      color: NotificationColors.ink,
                      fontWeight: _unreadOnly ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13.5,
                    ),
                    side: const BorderSide(color: NotificationColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    showCheckmark: false,
                    onSelected: (_) => setState(() {
                      _unreadOnly = true;
                      _kind = null;
                    }),
                  ),
                  TextButton.icon(
                    onPressed: _busy || unread == 0
                        ? null
                        : () => _markRead(all.map((n) => n.id), all: true),
                    style: TextButton.styleFrom(
                      foregroundColor: NotificationColors.primary,
                      backgroundColor: unread > 0
                          ? NotificationColors.reminderBackground
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      minimumSize: const Size(48, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text(
                      'Đọc tất cả',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Thanh lọc danh mục cuộn ngang với vùng chạm lớn
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final category in {
                      'growth': 'Tăng trưởng',
                      'vaccination': 'Tiêm chủng',
                      'assessment': 'Đánh giá',
                      'sharing': 'Chia sẻ',
                      'system': 'Hệ thống',
                    }.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category.value),
                          selected: _kind == category.key,
                          selectedColor: NotificationColors.accent,
                          backgroundColor: NotificationColors.surface,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          labelStyle: TextStyle(
                            color: NotificationColors.ink,
                            fontWeight: _kind == category.key
                                ? FontWeight.w800
                                : FontWeight.w600,
                            fontSize: 13,
                          ),
                          side: const BorderSide(color: NotificationColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          showCheckmark: false,
                          onSelected: (val) => setState(() {
                            _kind = val ? category.key : null;
                          }),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Trạng thái rỗng
              if (entries.isEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 24),
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                  decoration: BoxDecoration(
                    color: NotificationColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: NotificationColors.border),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: NotificationColors.iconBackground,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          size: 36,
                          color: NotificationColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        !enabled
                            ? 'Thông báo đang tắt'
                            : _unreadOnly
                            ? 'Không có thông báo chưa đọc'
                            : 'Chưa có thông báo mới',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: NotificationColors.ink,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        !enabled
                            ? 'Chạm vào nút cài đặt để bật lại thông báo cho bé.'
                            : 'Các lịch tiêm chủng và nhắc đo tăng trưởng sẽ xuất hiện tại đây.',
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: NotificationColors.reminderCta,
                          height: 1.45,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

              // Danh sách thẻ thông báo tối ưu chạm 1 tay
              for (final entry in entries)
                Builder(
                  builder: (context) {
                    final isUnread = !read.contains(entry.id);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isUnread
                            ? NotificationColors.cardUnread
                            : NotificationColors.cardRead,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isUnread
                              ? NotificationColors.primary.withValues(alpha: 0.35)
                              : NotificationColors.border,
                          width: isUnread ? 1.5 : 1,
                        ),
                        boxShadow: [
                          if (isUnread)
                            const BoxShadow(
                              color: Color(0x0A29451E),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _busy ? null : () => _open(entry),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Hàng 1: Icon + Tag danh mục + Thời gian + Chấm tin mới
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: NotificationColors.iconBackground,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        _categoryIcon(entry.kind),
                                        color: NotificationColors.ink,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: NotificationColors.reminderBackground,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              _categoryLabel(entry.kind),
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: NotificationColors.reminderCta,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _formatDate(entry.date),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: NotificationColors.reminderCta,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isUnread)
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: NotificationColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // Hàng 2: Tiêu đề
                                Text(
                                  entry.title,
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                                    color: NotificationColors.ink,
                                    height: 1.35,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                // Hàng 3: Nội dung
                                Text(
                                  entry.message,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    height: 1.45,
                                    color: NotificationColors.reminderCta,
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // Hàng 4: Nút thao tác dưới đáy thẻ (dễ chạm bằng ngón cái)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (entry.kind == 'growth' && !entry.resolved) ...[
                                      OutlinedButton(
                                        onPressed: () => _growthAction(entry, true),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: NotificationColors.ink,
                                          backgroundColor: NotificationColors.background,
                                          side: const BorderSide(
                                            color: NotificationColors.border,
                                          ),
                                          minimumSize: const Size(0, 40),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: const Text(
                                          'Nhắc sau 7 ngày',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => _growthAction(entry, false),
                                        style: TextButton.styleFrom(
                                          foregroundColor: NotificationColors.reminderCta,
                                          minimumSize: const Size(0, 40),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                        ),
                                        child: const Text(
                                          'Tắt nhắc',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ] else
                                      const SizedBox.shrink(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: NotificationColors.reminderBackground,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_ctaLabel(entry.kind)} →',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: NotificationColors.ink,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              if (NotificationInbox.instance.hasMore)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => NotificationInbox.instance.refresh(more: true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: NotificationColors.primary,
                        side: const BorderSide(color: NotificationColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Xem thêm thông báo cũ',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
