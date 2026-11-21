import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/demo_store.dart';
import '../../services/push_notifications.dart';
import '../../services/notification_inbox.dart';
import 'growth_reminder_settings_screen.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  Map<String, dynamic>? _prefs;
  List<Map<String, dynamic>>? _children;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await AuthService.instance.authorizedRequest(
        'GET',
        '/notifications/preferences',
      );
      if (mounted) {
        setState(() {
          _prefs = {
            ...value,
            'send_hour': value['send_hour'] as int? ?? 8,
            'send_minute': value['send_minute'] as int? ?? 0,
          };
        });
      }
    } catch (_) {
      if (mounted) {
        final localEnabled = DemoStore.instance.signedIn
            ? DemoStore.instance.parent['notifications'] != false
            : true;
        setState(() {
          _prefs = {
            'push_enabled': localEnabled,
            'send_hour': 8,
            'send_minute': 0,
            'growth_interval_days': 30,
            'timezone_offset': DateTime.now().timeZoneOffset.inMinutes,
          };
        });
      }
    }

    List<Map<String, dynamic>> childList = [];
    try {
      final data = await AuthService.instance.authorizedRequest(
        'GET',
        '/children',
      );
      if (data['children'] is List) {
        childList = List<Map<String, dynamic>>.from(
          (data['children'] as List).map(
            (c) => Map<String, dynamic>.from(c as Map),
          ),
        );
      } else if (data['items'] is List) {
        childList = List<Map<String, dynamic>>.from(
          (data['items'] as List).map(
            (c) => Map<String, dynamic>.from(c as Map),
          ),
        );
      }
    } catch (_) {
      // Fallback local
    }

    if (childList.isEmpty) {
      childList = List<Map<String, dynamic>>.from(DemoStore.instance.children);
    }

    if (mounted) {
      setState(() => _children = childList);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final p = _prefs!;
      final pushEnabled = p['push_enabled'] == true;
      if (DemoStore.instance.signedIn) {
        await DemoStore.instance.saveParent({'notifications': pushEnabled});
      }
      await AuthService.instance.authorizedRequest(
        'PUT',
        '/notifications/preferences',
        body: {
          'push_enabled': pushEnabled,
          'send_hour': p['send_hour'] ?? 8,
          'send_minute': p['send_minute'] ?? 0,
          'growth_interval_days': p['growth_interval_days'] ?? 30,
          'timezone_offset': DateTime.now().timeZoneOffset.inMinutes,
        },
      );
      final enabled = pushEnabled
          ? await PushNotifications.instance.enable()
          : true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Đã lưu cài đặt thông báo.'
                  : 'Đã lưu lịch nhắc. Hãy kiểm tra quyền thông báo trên thiết bị.',
            ),
          ),
        );
      }
      await NotificationInbox.instance.refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu cài đặt trên thiết bị.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildChildTile(
    BuildContext context,
    Map<String, dynamic> child, {
    required bool enabled,
  }) {
    final name =
        (child['full_name'] ?? child['fullName'] ?? child['nickname'] ?? 'Bé')
            .toString();
    final childId = (child['id'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: NotificationColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NotificationColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (!enabled || _saving)
              ? null
              : () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => GrowthReminderSettingsScreen(
                      childId: childId,
                      childName: name,
                    ),
                  ),
                ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: NotificationColors.iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.child_care_rounded,
                    color: NotificationColors.ink,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: NotificationColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: NotificationColors.reminderCta,
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = _prefs != null && _children != null;
    final pushEnabled = _prefs?['push_enabled'] == true;
    final sendHour = _prefs?['send_hour'] as int? ?? 8;
    final sendMinute = _prefs?['send_minute'] as int? ?? 0;

    return Scaffold(
      backgroundColor: NotificationColors.background,
      appBar: AppBar(
        backgroundColor: NotificationColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Cài đặt thông báo',
          style: TextStyle(
            color: NotificationColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: !ready
          ? const Center(
              child: CircularProgressIndicator(
                color: NotificationColors.primary,
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // Thẻ 1: Nút Bật/Tắt thông báo (tách riêng)
                Container(
                  decoration: BoxDecoration(
                    color: NotificationColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: NotificationColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _saving
                          ? null
                          : () => setState(
                              () => _prefs!['push_enabled'] = !pushEnabled,
                            ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: pushEnabled
                                    ? NotificationColors.iconBackground
                                    : NotificationColors.border.withOpacity(
                                        0.35,
                                      ),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                pushEnabled
                                    ? Icons.notifications_active_rounded
                                    : Icons.notifications_off_outlined,
                                color: NotificationColors.ink,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Thông báo trên thiết bị',
                                style: TextStyle(
                                  color: NotificationColors.ink,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Switch.adaptive(
                              activeColor: NotificationColors.primary,
                              value: pushEnabled,
                              onChanged: _saving
                                  ? null
                                  : (v) => setState(
                                      () => _prefs!['push_enabled'] = v,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Khi tắt thông báo: các thiết lập phía dưới mờ đi và khóa tương tác
                IgnorePointer(
                  ignoring: !pushEnabled,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: pushEnabled ? 1.0 : 0.42,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Thẻ 2: Giờ nhắc hằng ngày (vùng cuộn Giờ - Phút giống chọn ngày-tháng-năm mọc răng)
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                          decoration: BoxDecoration(
                            color: NotificationColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: NotificationColors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: NotificationColors.iconBackground,
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: const Icon(
                                      Icons.schedule_rounded,
                                      size: 22,
                                      color: NotificationColors.ink,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  const Expanded(
                                    child: Text(
                                      'Giờ nhắc hằng ngày',
                                      style: TextStyle(
                                        color: NotificationColors.ink,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              NotificationTimeWheelPicker(
                                hour: sendHour,
                                minute: sendMinute,
                                onChanged: (h, m) {
                                  if (!pushEnabled || _saving) return;
                                  setState(() {
                                    _prefs!['send_hour'] = h;
                                    _prefs!['send_minute'] = m;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Phần 3: Nhắc cập nhật số đo chỉ số
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 10),
                          child: Text(
                            'Nhắc cập nhật số đo chỉ số',
                            style: TextStyle(
                              color: NotificationColors.ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),

                        if (_children!.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: NotificationColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: NotificationColors.border,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'Chưa có hồ sơ trẻ',
                                style: TextStyle(
                                  color: NotificationColors.reminderCta,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        else
                          for (final child in _children!)
                            _buildChildTile(
                              context,
                              child,
                              enabled: pushEnabled,
                            ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: !ready
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                decoration: const BoxDecoration(
                  color: NotificationColors.background,
                  border: Border(
                    top: BorderSide(color: NotificationColors.border),
                  ),
                ),
                child: SizedBox(
                  height: 54,
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: NotificationColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: Text(
                      _saving ? 'Đang lưu…' : 'Lưu cài đặt',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Vùng cuộn chọn Giờ - Phút đồng bộ thiết kế với TeethingDatePicker.
class NotificationTimeWheelPicker extends StatelessWidget {
  const NotificationTimeWheelPicker({
    super.key,
    required this.hour,
    required this.minute,
    required this.onChanged,
  });

  final int hour;
  final int minute;
  final void Function(int hour, int minute) onChanged;

  @override
  Widget build(BuildContext context) {
    final itemExtent = MediaQuery.textScalerOf(context).scale(22) + 18;

    Widget wheel(
      String label,
      int min,
      int max,
      int selected,
      ValueChanged<int> change,
    ) => Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: NotificationColors.reminderCta,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: itemExtent * 3,
            child: _TimeNumberWheel(
              key: ValueKey('$label-$min-$max'),
              label: label,
              min: min,
              max: max,
              selected: selected,
              itemExtent: itemExtent,
              onChanged: change,
            ),
          ),
        ],
      ),
    );

    return Padding(
      key: const Key('notification-time-picker'),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          wheel('Giờ', 0, 23, hour, (h) => onChanged(h, minute)),
          wheel('Phút', 0, 59, minute, (m) => onChanged(hour, m)),
        ],
      ),
    );
  }
}

class _TimeNumberWheel extends StatefulWidget {
  const _TimeNumberWheel({
    super.key,
    required this.label,
    required this.min,
    required this.max,
    required this.selected,
    required this.itemExtent,
    required this.onChanged,
  });

  final String label;
  final int min, max, selected;
  final double itemExtent;
  final ValueChanged<int> onChanged;

  @override
  State<_TimeNumberWheel> createState() => _TimeNumberWheelState();
}

class _TimeNumberWheelState extends State<_TimeNumberWheel> {
  late final _controller = FixedExtentScrollController(
    initialItem: widget.selected - widget.min,
  );

  @override
  void didUpdateWidget(covariant _TimeNumberWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final index = widget.selected - widget.min;
      final count = widget.max - widget.min + 1;
      final current = _controller.selectedItem;
      final delta = (index - current) % count;
      if (delta != 0) {
        _controller.jumpToItem(
          current + (delta > count / 2 ? delta - count : delta),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoPicker(
    key: Key('notification-time-${widget.label}'),
    scrollController: _controller,
    itemExtent: widget.itemExtent,
    diameterRatio: 1.4,
    squeeze: 1.1,
    looping: true,
    selectionOverlay: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: NotificationColors.reminderBackground.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: NotificationColors.primary.withValues(alpha: .45),
          width: 1.5,
        ),
      ),
    ),
    onSelectedItemChanged: (index) => widget.onChanged(widget.min + index),
    children: [
      for (var n = widget.min; n <= widget.max; n++)
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                n.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: n == widget.selected ? 24 : 20,
                  fontWeight: n == widget.selected
                      ? FontWeight.w800
                      : FontWeight.w400,
                  color: n == widget.selected
                      ? NotificationColors.ink
                      : NotificationColors.reminderCta,
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
