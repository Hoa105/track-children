import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/push_notifications.dart';
import '../../services/notification_inbox.dart';

/// Màn hình cài đặt nhắc cập nhật số đo tăng trưởng per-metric theo Green Sprout UI.
/// Tối ưu vùng chạm lớn dễ thao tác bằng 1 tay.
class GrowthReminderSettingsScreen extends StatefulWidget {
  const GrowthReminderSettingsScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  final String childId;
  final String childName;

  @override
  State<GrowthReminderSettingsScreen> createState() =>
      _GrowthReminderSettingsScreenState();
}

class _GrowthReminderSettingsScreenState
    extends State<GrowthReminderSettingsScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _saving = false;

  // Local state: mode + interval_days cho từng chỉ số
  final Map<String, String> _mode = {};      // 'age_based' | 'custom'
  final Map<String, int?> _interval = {};    // null = Tắt khi custom
  final Map<String, bool> _enabled = {};

  static const _metrics = ['weight', 'height', 'head_circumference'];
  static const _metricLabels = {
    'weight': 'Cân nặng',
    'height': 'Chiều dài / Chiều cao',
    'head_circumference': 'Vòng đầu',
  };
  static const _metricIcons = {
    'weight': Icons.monitor_weight_rounded,
    'height': Icons.straighten_rounded,
    'head_circumference': Icons.face_retouching_natural_rounded,
  };
  static const _intervalOptions = [15, 30, 60, 90, 180];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
    });
    try {
      final data = await AuthService.instance.authorizedRequest(
        'GET',
        '/notifications/growth/${widget.childId}',
      );
      if (!mounted) return;
      final metrics = data['metrics'] as Map<String, dynamic>;
      setState(() {
        _data = data;
        for (final m in _metrics) {
          final s = metrics[m] as Map<String, dynamic>? ?? {};
          _enabled[m] = s['enabled'] as bool? ?? true;
          _mode[m] = s['mode'] as String? ?? 'age_based';
          _interval[m] = s['interval_days'] as int?;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = null;
          for (final m in _metrics) {
            _enabled[m] = true;
            _mode[m] = 'age_based';
            _interval[m] = null;
          }
          _data = {
            'age_months': 8,
            'metrics': {
              'weight': {
                'enabled': true,
                'mode': 'age_based',
                'interval_days': null,
                'age_based_interval': 30,
              },
              'height': {
                'enabled': true,
                'mode': 'age_based',
                'interval_days': null,
                'age_based_interval': 60,
              },
              'head_circumference': {
                'enabled': true,
                'mode': 'age_based',
                'interval_days': null,
                'age_based_interval': 60,
              },
            },
          };
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      for (final m in _metrics) {
        await AuthService.instance.authorizedRequest(
          'PUT',
          '/notifications/growth/${widget.childId}/$m',
          body: {
            'enabled': _enabled[m] ?? true,
            'mode': _mode[m] ?? 'age_based',
            'interval_days': _interval[m],
          },
        );
      }
      await PushNotifications.instance.sync();
      await NotificationInbox.instance.refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu cài đặt nhắc số đo.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu cài đặt tạm thời trên thiết bị.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int? _ageBasedInterval(String metric) {
    final metrics = (_data?['metrics'] as Map<String, dynamic>?)?[metric];
    return (metrics as Map<String, dynamic>?)?['age_based_interval'] as int?;
  }

  String _ageBasedLabel(String metric) {
    final d = _ageBasedInterval(metric);
    if (d == null) return 'Tắt tự động (ngoài độ tuổi khuyến nghị)';
    return 'Chu kỳ tự động theo tuổi: $d ngày/lần';
  }

  Widget _modeButton({
    required String label,
    required bool selected,
    required VoidCallback? onTap,
  }) => Expanded(
    child: Material(
      color: selected ? NotificationColors.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? NotificationColors.ink
                  : NotificationColors.reminderCta,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _metricCard(String metric) {
    final label = _metricLabels[metric]!;
    final icon = _metricIcons[metric]!;
    final isEnabled = _enabled[metric] ?? true;
    final mode = _mode[metric] ?? 'age_based';
    final interval = _interval[metric];

    return Container(
      decoration: BoxDecoration(
        color: NotificationColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isEnabled
              ? NotificationColors.border
              : NotificationColors.border.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Chạm cả hàng để bật/tắt nhanh bằng 1 tay
          InkWell(
            onTap: _saving
                ? null
                : () => setState(() => _enabled[metric] = !isEnabled),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? NotificationColors.iconBackground
                          : NotificationColors.border.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: isEnabled
                          ? NotificationColors.ink
                          : NotificationColors.reminderCta,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: isEnabled
                            ? NotificationColors.ink
                            : NotificationColors.reminderCta,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: isEnabled,
                    activeTrackColor: NotificationColors.primary,
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _enabled[metric] = v),
                  ),
                ],
              ),
            ),
          ),

          if (isEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thanh chuyển chế độ lớn (48px), chia 2 nửa đều nhau dễ ấn 1 tay
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: NotificationColors.background,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: NotificationColors.border),
                    ),
                    child: Row(
                      children: [
                        _modeButton(
                          label: 'Theo độ tuổi',
                          selected: mode == 'age_based',
                          onTap: _saving
                              ? null
                              : () =>
                                    setState(() => _mode[metric] = 'age_based'),
                        ),
                        const SizedBox(width: 4),
                        _modeButton(
                          label: 'Tự điều chỉnh',
                          selected: mode == 'custom',
                          onTap: _saving
                              ? null
                              : () => setState(() {
                                  _mode[metric] = 'custom';
                                  _interval[metric] ??= 30;
                                }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (mode == 'age_based')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: NotificationColors.reminderBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: NotificationColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 18,
                            color: NotificationColors.reminderCta,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _ageBasedLabel(metric),
                              style: const TextStyle(
                                color: NotificationColors.ink,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    // Các nút chọn chu kỳ lớn dễ chạm bằng ngón cái
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final d in _intervalOptions)
                          ChoiceChip(
                            label: Text('$d ngày'),
                            selected: interval == d,
                            selectedColor: NotificationColors.accent,
                            backgroundColor: NotificationColors.background,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            labelStyle: TextStyle(
                              color: NotificationColors.ink,
                              fontWeight: interval == d
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              fontSize: 13.5,
                            ),
                            side: const BorderSide(
                              color: NotificationColors.border,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            showCheckmark: false,
                            onSelected: _saving
                                ? null
                                : (_) => setState(() => _interval[metric] = d),
                          ),
                        ChoiceChip(
                          label: const Text('Tắt'),
                          selected: interval == null,
                          selectedColor: const Color(0xFFFDE8E8),
                          backgroundColor: NotificationColors.background,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          labelStyle: TextStyle(
                            color: interval == null
                                ? const Color(0xFFB44545)
                                : NotificationColors.reminderCta,
                            fontWeight: interval == null
                                ? FontWeight.w800
                                : FontWeight.w600,
                            fontSize: 13.5,
                          ),
                          side: BorderSide(
                            color: interval == null
                                ? const Color(0xFFF9A8A8)
                                : NotificationColors.border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          showCheckmark: false,
                          onSelected: _saving
                              ? null
                              : (_) => setState(() => _interval[metric] = null),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: NotificationColors.background,
    appBar: AppBar(
      title: Text(
        'Nhắc số đo: ${widget.childName}',
        style: const TextStyle(
          color: NotificationColors.ink,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      backgroundColor: NotificationColors.background,
      surfaceTintColor: Colors.transparent,
    ),
    body: _data == null
        ? Center(
            child: _error == null
                ? const CircularProgressIndicator(
                    color: NotificationColors.primary,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: NotificationColors.reminderCta,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _load,
                        style: FilledButton.styleFrom(
                          backgroundColor: NotificationColors.primary,
                        ),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
          )
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (final m in _metrics) ...[
                _metricCard(m),
                const SizedBox(height: 12),
              ],
            ],
          ),
    bottomNavigationBar: _data == null
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
