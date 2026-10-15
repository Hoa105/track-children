import '../../services/demo_store.dart';

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_colors.dart';
import '../navigation/app_bottom_navigation_bar.dart';
import '../settings/settings_screen.dart';
import 'who_bmi_card.dart';
import 'growth_chart.dart';

class GrowthScreen extends StatefulWidget {
  const GrowthScreen({
    required this.childName,
    this.onLogout,
    this.initialMetric = 0,
    this.openMeasurement = false,
    super.key,
  });
  final String childName;
  final int initialMetric;
  final bool openMeasurement;
  final VoidCallback? onLogout;
  @override
  State<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends State<GrowthScreen> {
  static const labels = ['Cân nặng', 'Chiều cao', 'Vòng đầu', 'BMI'];
  static const units = ['kg', 'cm', 'cm', 'kg/m²'];
  List<Map<String, dynamic>> _records = [];
  String? _childId;
  int _tab = 0;
  int _profileRevision = 0;
  int _months = 6;
  DateTimeRange? _customRange;
  bool _loading = true;
  bool _isPreview = false;
  String? _loadError;
  String get _key => 'growth_v1_${widget.childName}';
  @override
  void initState() {
    super.initState();
    _tab = widget.initialMetric.clamp(0, 3);
    _childId = DemoStore.instance.child?['id'] as String?;
    DemoStore.instance.addListener(_onDemoChanged);
    _load();
  }

  void _onDemoChanged() {
    if (!mounted || _childId == null) return;
    setState(() {
      _childId = DemoStore.instance.child?['id'] as String?;
      _records = _childId == null ? [] : DemoStore.instance.records(_childId!);
      _profileRevision++;
    });
  }

  @override
  void dispose() {
    DemoStore.instance.removeListener(_onDemoChanged);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _childId == null
          ? jsonDecode(prefs.getString(_key) ?? '[]') as List
          : DemoStore.instance.records(_childId!);
      if (mounted) {
        setState(() {
          _isPreview = _childId == null && data.isEmpty;
          _records = _isPreview
              ? _previewRecords()
              : data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _loadError =
              'Chưa thể đọc số đo đã lưu. Vui lòng mở lại màn hình.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        if (widget.openMeasurement && _loadError == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _update();
          });
        }
      }
    }
  }

  List<Map<String, dynamic>> _previewRecords() {
    final today = DateTime.now();
    const measurements = [
      [6.5, 62.0, 40.5],
      [6.9, 63.5, 41.2],
      [7.2, 65.0, 41.8],
      [7.6, 66.2, 42.3],
      [7.9, 67.4, 42.8],
      [8.1, 68.0, 43.2],
      [8.4, 69.5, 43.7],
    ];
    return List.generate(measurements.length, (i) {
      final date = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: (measurements.length - 1 - i) * 28));
      return <String, dynamic>{
        'date': date.toIso8601String(),
        'v0': measurements[i][0],
        'v1': measurements[i][1],
        'v2': measurements[i][2],
      };
    });
  }

  double? _value(Map<String, dynamic> r) {
    if (_tab < 3) return (r['v$_tab'] as num?)?.toDouble();
    final w = (r['v0'] as num?)?.toDouble();
    final h = (r['v1'] as num?)?.toDouble();
    return w == null || h == null ? null : w / math.pow(h / 100, 2);
  }

  Future<void> _update() async {
    if (_loading || _loadError != null) return;
    final record = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      builder: (_) => const _MeasurementSheet(),
    );
    if (record == null || !mounted) return;
    final next = [if (!_isPreview) ..._records, record]
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    try {
      final prefs = await SharedPreferences.getInstance();
      bool saved;
      if (_childId != null) {
        await DemoStore.instance.addRecord(_childId!, record);
        saved = true;
      } else {
        saved = await prefs.setString(_key, jsonEncode(next));
      }
      if (!saved) throw StateError('save failed');
      if (!mounted) return;
      setState(() {
        _records = _childId == null
            ? next
            : DemoStore.instance.records(_childId!);
        _isPreview = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã lưu số đo của bé')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa lưu được số đo. Vui lòng thử lại.'),
          ),
        );
      }
    }
  }

  Future<void> _pickRange() async {
    final today = DateUtils.dateOnly(DateTime.now());
    var first = DateTime(2000);
    for (final record in _records) {
      final date = DateUtils.dateOnly(DateTime.parse(record['date'] as String));
      if (date.isBefore(first)) first = date;
    }
    final proposedStart = DateTime(
      today.year,
      today.month - (_months == 0 ? 6 : _months),
      today.day,
    );
    final range = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: today,
      initialDateRange:
          _customRange ??
          DateTimeRange(
            start: proposedStart.isBefore(first) ? first : proposedStart,
            end: today,
          ),
      helpText: 'Chọn khoảng thời gian xem',
      saveText: 'Áp dụng',
      cancelText: 'Hủy',
      confirmText: 'Áp dụng',
      fieldStartLabelText: 'Từ ngày',
      fieldEndLabelText: 'Đến ngày',
      errorInvalidRangeText: 'Ngày kết thúc phải từ ngày bắt đầu trở đi.',
    );
    if (range != null && mounted) setState(() => _customRange = range);
  }

  @override
  Widget build(BuildContext context) {
    final all = _records.where((r) => _value(r) != null).toList();
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month - _months, now.day);
    final visible = all.where((r) {
      final date = DateUtils.dateOnly(DateTime.parse(r['date'] as String));
      if (_customRange != null) {
        return !date.isBefore(_customRange!.start) &&
            !date.isAfter(_customRange!.end);
      }
      return _months == 0 || !date.isBefore(cutoff);
    }).toList();
    final latest = all.isEmpty ? null : _value(all.last);
    final delta = all.length < 2
        ? null
        : latest! - _value(all[all.length - 2])!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Theo dõi tăng trưởng'),
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        selected: 'Theo dõi',
        onTap: (label) {
          if (label == 'Trang chủ') {
            Navigator.of(context).popUntil(
              (route) => route.settings.name == '/home' || route.isFirst,
            );
          } else if (label == 'Cá nhân') {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(
                  onLogout: widget.onLogout,
                  childName: widget.childName,
                ),
              ),
            );
          } else if (label == 'Tạo ghi chép') {
            _update();
          } else if (label != 'Theo dõi') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Khám phá sẽ sớm ra mắt.')),
            );
          }
        },
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(child: Text(_loadError!))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                if (_isPreview) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.science_outlined, color: AppColors.primary),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Dữ liệu mẫu · 7 lần đo trong 6 tháng.\nKhi lưu số đo đầu tiên, dữ liệu mẫu sẽ được thay thế.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                FilledButton.icon(
                  onPressed: _update,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Cập nhật số đo'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: List.generate(
                      4,
                      (i) => Expanded(
                        child: Semantics(
                          selected: _tab == i,
                          child: TextButton(
                            onPressed: () => setState(() => _tab = i),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              minimumSize: Size.zero,
                              backgroundColor: _tab == i
                                  ? Colors.white
                                  : Colors.transparent,
                              foregroundColor: _tab == i
                                  ? AppColors.primaryDark
                                  : AppColors.textSecondary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              labels[i],
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tab == 3 ? 'BMI của bé' : '${labels[_tab]} mới nhất',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        children: [
                          Text(
                            latest == null ? '—' : latest.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                              height: 1.2,
                            ),
                          ),
                          Text(
                            units[_tab],
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      if (delta != null)
                        Text(
                          '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} ${units[_tab]} so với lần trước',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final m in [3, 6, 0])
                            ChoiceChip(
                              label: Text(m == 0 ? 'Tất cả' : '$m tháng'),
                              selected: _customRange == null && _months == m,
                              onSelected: (_) => setState(() {
                                _months = m;
                                _customRange = null;
                              }),
                              showCheckmark: false,
                            ),
                          ChoiceChip(
                            avatar: const Icon(
                              Icons.date_range_rounded,
                              size: 18,
                            ),
                            label: const Text('Tùy chọn'),
                            selected: _customRange != null,
                            onSelected: (_) => _pickRange(),
                            showCheckmark: false,
                          ),
                        ],
                      ),
                      if (_customRange != null)
                        TextButton.icon(
                          onPressed: _pickRange,
                          icon: const Icon(
                            Icons.edit_calendar_outlined,
                            size: 16,
                          ),
                          label: Text(
                            '${_date(_customRange!.start.toIso8601String())} – ${_date(_customRange!.end.toIso8601String())}',
                          ),
                        ),
                      const SizedBox(height: 24),
                      if (visible.isEmpty)
                        SizedBox(
                          height: 190,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.insights_rounded,
                                  size: 42,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _tab == 3
                                      ? 'Thêm cân nặng và chiều cao cùng ngày\nđể tự động tính BMI.'
                                      : 'Chưa có số đo trong khoảng này.\nThêm số đo đầu tiên của bé nhé!',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        GrowthChart(
                          key: ValueKey(
                            '$_tab-$_profileRevision-$_isPreview-${visible.length}-$_months-$_customRange',
                          ),
                          values: visible.map((r) => _value(r)!).toList(),
                          dates: visible
                              .map(
                                (r) => DateUtils.dateOnly(
                                  DateTime.parse(r['date'] as String),
                                ),
                              )
                              .toList(),
                          metric: const [
                            'weight',
                            'height',
                            'head',
                            'bmi',
                          ][_tab],
                          childName: widget.childName,
                          childId: _childId,
                          rangeStart: _customRange?.start,
                          rangeEnd: _customRange?.end,
                          previewAnchor: all.isEmpty
                              ? null
                              : DateTime.parse(all.last['date'] as String),
                          preview: _isPreview,
                          unit: units[_tab],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _date(
                                (_customRange?.start ??
                                        DateTime.parse(
                                          visible.first['date'] as String,
                                        ))
                                    .toIso8601String(),
                              ),
                            ),
                            Text(
                              visible.length > 1 || _customRange != null
                                  ? _date(
                                      (_customRange?.end ??
                                              DateTime.parse(
                                                visible.last['date'] as String,
                                              ))
                                          .toIso8601String(),
                                    )
                                  : '',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Chạm vào biểu đồ để xem số đo',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ...[
                  const SizedBox(height: 16),
                  WhoBmiCard(
                    key: ValueKey('who-card-$_tab-$_profileRevision'),
                    compact: _tab != 3,
                    onProfileChanged: () => setState(() => _profileRevision++),
                    childName: widget.childName,
                    childId: _childId,
                    preview: _isPreview,
                    measured: all.isEmpty
                        ? null
                        : DateTime.parse(all.last['date'] as String),
                    bmi: latest,
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Lịch sử số đo',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Text(
                      '${all.length} lần',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (all.isEmpty)
                  const Text(
                    'Số đo đã lưu sẽ xuất hiện tại đây.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                for (final r in all.reversed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primarySoft,
                      child: Icon(
                        Icons.timeline_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(_date(r['date'] as String)),
                    trailing: Text(
                      '${_value(r)!.toStringAsFixed(1)} ${units[_tab]}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
    );
  }
}

String _date(String raw) {
  final d = DateTime.parse(raw);
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

Widget _panel(Widget child) => Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
  ),
  child: child,
);

class _MeasurementSheet extends StatefulWidget {
  const _MeasurementSheet();
  @override
  State<_MeasurementSheet> createState() => _MeasurementSheetState();
}

class _MeasurementSheetState extends State<_MeasurementSheet> {
  final _form = GlobalKey<FormState>();
  final _controllers = List.generate(3, (_) => TextEditingController());
  DateTime _day = DateTime.now();
  String? _error;
  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    if (_controllers.every((c) => c.text.trim().isEmpty)) {
      setState(() => _error = 'Nhập ít nhất một số đo nhé.');
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'date': DateTime(_day.year, _day.month, _day.day).toIso8601String(),
      for (int i = 0; i < 3; i++)
        if (_controllers[i].text.trim().isNotEmpty)
          'v$i': double.parse(_controllers[i].text.trim().replaceAll(',', '.')),
    });
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      24,
      20,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Cập nhật số đo',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                tooltip: 'Đóng',
              ),
            ],
          ),
          const Text(
            'Có thể nhập một hoặc nhiều chỉ số.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text('Ngày đo: ${_date(_day.toIso8601String())}'),
            onPressed: () async {
              final day = await showDatePicker(
                context: context,
                initialDate: _day,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (day != null && mounted) setState(() => _day = day);
            },
          ),
          for (int i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextFormField(
                controller: _controllers[i],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _GrowthScreenState.labels[i],
                  suffixText: _GrowthScreenState.units[i],
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (raw) {
                  if (raw == null || raw.trim().isEmpty) return null;
                  final v = double.tryParse(raw.trim().replaceAll(',', '.'));
                  if (v == null ||
                      !v.isFinite ||
                      v <= 0 ||
                      v > [200, 250, 100][i]) {
                    return 'Vui lòng nhập số đo hợp lệ';
                  }
                  return null;
                },
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Lưu số đo'),
          ),
        ],
      ),
    ),
  );
}
