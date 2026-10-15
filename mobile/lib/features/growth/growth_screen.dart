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
  final _scroll = ScrollController();
  bool _scrolled = false;
  bool _historyExpanded = false;
  Map<String, dynamic>? _selected;
  String? _savedDate;
  Map<String, dynamic>? _savedRecord;
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
    _scroll.addListener(() {
      final collapsed = _scroll.offset > 140;
      if (collapsed != _scrolled && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && collapsed != _scrolled) {
            setState(() => _scrolled = collapsed);
          }
        });
      }
    });
    _childId = DemoStore.instance.child?['id'] as String?;
    DemoStore.instance.addListener(_onDemoChanged);
    _load();
  }

  void _onDemoChanged() {
    if (!mounted || _childId == null) return;
    setState(() {
      _childId = DemoStore.instance.child?['id'] as String?;
      _records = _childId == null ? [] : DemoStore.instance.records(_childId!);
      _selected = null;
      _profileRevision++;
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
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
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) =>
          _MeasurementSheet(records: _records, isPreview: _isPreview),
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
        _selected = null;
        _savedDate = record['date'] as String;
        _savedRecord = _records.lastWhere(
          (r) => record.entries.every((e) => r[e.key] == e.value),
          orElse: () => record,
        );
        // Bring a newly saved measurement back into the visible period.
        _customRange = null;
        _months = 0;
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
    if (range != null && mounted) {
      setState(() {
        _customRange = range;
        _selected = null;
        _historyExpanded = false;
      });
    }
  }

  Duration get _motion => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 220);

  Widget _resize({
    required Widget child,
    Alignment alignment = Alignment.center,
  }) => _motion == Duration.zero
      ? child
      : AnimatedSize(duration: _motion, alignment: alignment, child: child);

  void _changeTab(int tab) => setState(() {
    _tab = tab;
    _selected = null;
    _historyExpanded = false;
  });

  @override
  Widget build(BuildContext context) {
    final all = _records.where((r) => _value(r) != null).toList();
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month - _months, now.day);
    final visible = all.where((r) {
      final d = DateUtils.dateOnly(DateTime.parse(r['date'] as String));
      return _customRange != null
          ? !d.isBefore(_customRange!.start) && !d.isAfter(_customRange!.end)
          : _months == 0 || !d.isBefore(cutoff);
    }).toList();
    final current = _selected != null && visible.contains(_selected)
        ? _selected
        : visible.lastOrNull;
    final index = current == null ? -1 : all.indexOf(current);
    final value = current == null ? null : _value(current);
    final delta = index > 0 ? value! - _value(all[index - 1])! : null;
    final start =
        _customRange?.start ??
        (visible.isEmpty
            ? null
            : DateTime.parse(visible.first['date'] as String));
    final end =
        _customRange?.end ??
        (visible.isEmpty
            ? null
            : DateTime.parse(visible.last['date'] as String));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Tăng trưởng',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Tooltip(
              message: 'Cập nhật số đo',
              child: FilledButton(
                onPressed: _loading || _loadError != null ? null : _update,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size(44, 42),
                ),
                child: _resize(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, size: 21),
                      if (!_scrolled) ...[
                        const SizedBox(width: 5),
                        const Text('Số đo'),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavigationBar(
        selected: 'Theo dõi',
        onTap: (label) {
          if (label == 'Trang chủ') {
            Navigator.of(context)
                .popUntil((r) => r.settings.name == '/home' || r.isFirst);
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
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                if (_isPreview)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.science_outlined,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Dữ liệu mẫu · 7 lần đo',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Về dữ liệu mẫu',
                          icon: const Icon(Icons.info_outline, size: 18),
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Dữ liệu mẫu'),
                              content: const Text(
                                'Các số đo minh họa sẽ được thay thế khi bạn lưu số đo đầu tiên của bé.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c),
                                  child: const Text('Đóng'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECEEE8),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: List.generate(
                      4,
                      (i) => Expanded(
                        child: Semantics(
                          selected: _tab == i,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _changeTab(i),
                            child: AnimatedContainer(
                              constraints: const BoxConstraints(minHeight: 48),
                              alignment: Alignment.center,
                              duration: _motion,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _tab == i
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: _tab == i
                                    ? [
                                        const BoxShadow(
                                          color: Color(0x09000000),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Text(
                                labels[i],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _tab == i
                                      ? AppColors.primaryDark
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                AnimatedSwitcher(
                  duration: _motion,
                  layoutBuilder: _switcherLayout,
                  child: Container(
                    key: ValueKey('metric-card-$_tab'),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: const Color(0xFFECEEE8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selected == null
                                    ? '${labels[_tab]} gần nhất'
                                    : 'Số đo đang xem',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            if (_selected != null)
                              TextButton(
                                onPressed: () =>
                                    setState(() => _selected = null),
                                child: const Text('Về mới nhất'),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  const [
                                    Icons.monitor_weight_outlined,
                                    Icons.height_rounded,
                                    Icons.face_outlined,
                                    Icons.insights_rounded,
                                  ][_tab],
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            AnimatedSwitcher(
                              duration: _motion,
                              layoutBuilder: _switcherLayout,
                              child: Text(
                                value?.toStringAsFixed(1) ?? '—',
                                key: ValueKey('value-$_tab-$value'),
                                style: const TextStyle(
                                  fontSize: 44,
                                  height: 1.15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1.5,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                            Text(
                              units[_tab],
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (delta != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} ${units[_tab]}',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          current == null
                              ? 'Chưa có số đo trong khoảng này'
                              : '${_date(current['date'] as String)} · ${delta == null ? 'Số đo đầu tiên' : 'Thay đổi so với lần đo trước'}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            for (final m in [3, 6, 0])
                              ChoiceChip(
                                backgroundColor: const Color(0xFFF4F5F0),
                                label: Text(m == 0 ? 'Tất cả' : '$m tháng'),
                                selected: _customRange == null && _months == m,
                                showCheckmark: false,
                                visualDensity: VisualDensity.compact,
                                labelStyle: const TextStyle(fontSize: 11),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                side: BorderSide.none,
                                selectedColor: AppColors.primarySoft,
                                onSelected: (_) => setState(() {
                                  _months = m;
                                  _customRange = null;
                                  _selected = null;
                                  _historyExpanded = false;
                                }),
                              ),
                            Tooltip(
                              message: 'Tùy chọn',
                              child: _customRange == null
                                  ? IconButton(
                                      onPressed: _pickRange,
                                      icon: const Icon(
                                        Icons.date_range_outlined,
                                        size: 20,
                                      ),
                                      style: IconButton.styleFrom(
                                        backgroundColor: AppColors.background,
                                      ),
                                    )
                                  : TextButton.icon(
                                      onPressed: _pickRange,
                                      icon: const Icon(
                                        Icons.date_range_outlined,
                                        size: 16,
                                      ),
                                      label: Text(
                                        '${_date(_customRange!.start.toIso8601String())} – ${_date(_customRange!.end.toIso8601String())}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (visible.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 38),
                            child: Center(
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.show_chart_rounded,
                                    size: 42,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _tab == 3
                                        ? 'Thêm cân nặng và chiều cao cùng ngày\nđể tự động tính BMI.'
                                        : 'Chưa có số đo trong khoảng này.\nChọn khoảng khác hoặc thêm số đo nhé!',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else ...[
                          GrowthChart(
                            key: ValueKey(
                              '$_tab-$_profileRevision-$_isPreview-${visible.length}-$_months-$_customRange-$_savedDate',
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
                            preview: _isPreview,
                            unit: units[_tab],
                            rangeStart: _customRange?.start,
                            rangeEnd: _customRange?.end,
                            previewAnchor: all.isEmpty
                                ? null
                                : DateTime.parse(all.last['date'] as String),
                            selectedIndex: current == null
                                ? null
                                : visible.indexOf(current),
                            highlightIndex: _savedRecord == null
                                ? null
                                : visible.lastIndexWhere(
                                    (r) => identical(r, _savedRecord),
                                  ),
                            onSelected: (i) =>
                                setState(() => _selected = visible[i]),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  _date(start!.toIso8601String()),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  start == end
                                      ? ''
                                      : _date(end!.toIso8601String()),
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Center(
                            child: Text(
                              'Chạm hoặc kéo ngang để xem từng lần đo',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                WhoBmiCard(
                  previewAnchor: all.isEmpty
                      ? null
                      : DateTime.parse(all.last['date'] as String),
                  key: ValueKey('who-card-$_tab-$_profileRevision'),
                  compact: _tab != 3,
                  onProfileChanged: () => setState(() => _profileRevision++),
                  childName: widget.childName,
                  childId: _childId,
                  preview: _isPreview,
                  measured: current == null
                      ? null
                      : DateTime.parse(current['date'] as String),
                  bmi: value,
                  measurementLabel: current == null || _tab != 3
                      ? null
                      : 'Tính từ ${current['v0']} kg · ${current['v1']} cm',
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Lịch sử số đo',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${visible.length} lần',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (visible.isEmpty)
                  const Text(
                    'Số đo trong khoảng đã chọn sẽ xuất hiện tại đây.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                _resize(
                  alignment: Alignment.topCenter,
                  child: Column(
                    children: [
                      for (final r in visible.reversed.take(
                        _historyExpanded ? visible.length : 3,
                      ))
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: r == _selected
                                  ? AppColors.primarySoft
                                  : Colors.transparent,
                            ),
                          ),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              title: Text(
                                _date(r['date'] as String),
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: identical(r, _savedRecord)
                                  ? const Text(
                                      'Vừa cập nhật',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 10,
                                      ),
                                    )
                                  : null,
                              trailing: Text(
                                '${_value(r)!.toStringAsFixed(1)} ${units[_tab]}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              onTap: () {
                                setState(() => _selected = r);
                                if (_scroll.hasClients) {
                                  if (_motion == Duration.zero) {
                                    _scroll.jumpTo(0);
                                  } else {
                                    _scroll.animateTo(
                                      0,
                                      duration: _motion,
                                      curve: Curves.easeOutCubic,
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (visible.length > 3)
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _historyExpanded = !_historyExpanded),
                    icon: Icon(
                      _historyExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                    ),
                    label: Text(
                      _historyExpanded
                          ? 'Thu gọn'
                          : 'Xem tất cả ${visible.length} lần đo',
                    ),
                  ),
              ],
            ),
    );
  }
}

// A value can reappear before its outgoing animation finishes. Keep each
// transition in its own keyed subtree so older Flutter versions cannot place
// two transitions with the same value key directly under the Stack.
Widget _switcherLayout(Widget? currentChild, List<Widget> previousChildren) =>
    Stack(
      alignment: Alignment.center,
      children: [
        for (var i = 0; i < previousChildren.length; i++)
          KeyedSubtree(key: ValueKey(i), child: previousChildren[i]),
        if (currentChild != null)
          KeyedSubtree(key: const ValueKey('current'), child: currentChild),
      ],
    );

String _date(String raw) {
  final d = DateTime.parse(raw);
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _MeasurementSheet extends StatefulWidget {
  const _MeasurementSheet({required this.records, required this.isPreview});
  final List<Map<String, dynamic>> records;
  final bool isPreview;
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

  Map<String, dynamic>? _latest(int metric) {
    final candidates =
        widget.records.where((r) => r['v$metric'] is num).toList()..sort(
          (a, b) => (a['date'] as String).compareTo(b['date'] as String),
        );
    return candidates.isEmpty ? null : candidates.last;
  }

  double? get _draftBmi {
    final weight = double.tryParse(
      _controllers[0].text.trim().replaceAll(',', '.'),
    );
    final height = double.tryParse(
      _controllers[1].text.trim().replaceAll(',', '.'),
    );
    if (weight == null ||
        height == null ||
        !weight.isFinite ||
        !height.isFinite ||
        weight <= 0 ||
        weight > 200 ||
        height <= 0 ||
        height > 250) {
      return null;
    }
    return weight / math.pow(height / 100, 2);
  }

  Duration get _motion => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 220);

  Widget _input(int i) {
    final current = _latest(i);
    final value = (current?['v$i'] as num?)?.toStringAsFixed(1);
    final entered = _controllers[i].text.trim().isNotEmpty;
    return AnimatedContainer(
      duration: _motion,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: entered
              ? AppColors.primary.withValues(alpha: .4)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  [
                    Icons.monitor_weight_outlined,
                    Icons.height_rounded,
                    Icons.face_outlined,
                  ][i],
                  color: AppColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _GrowthScreenState.labels[i],
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value == null
                          ? 'Chưa có số đo'
                          : '${widget.isPreview ? 'Mẫu' : 'Gần nhất'} · ${_date(current!['date'] as String)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (value != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '$value ${_GrowthScreenState.units[i]}',
                key: ValueKey('current-measurement-$i'),
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _controllers[i],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: i < 2
                ? TextInputAction.next
                : TextInputAction.done,
            onChanged: (_) => setState(() => _error = null),
            onFieldSubmitted: i == 2 ? (_) => _save() : null,
            decoration: InputDecoration(
              labelText: '${_GrowthScreenState.labels[i]} mới',
              suffixText: _GrowthScreenState.units[i],
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bmi = _draftBmi;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .88,
      child: AnimatedPadding(
        duration: _motion,
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Cập nhật số đo',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Đóng',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Đối chiếu số đo gần nhất và nhập chỉ số mới của bé.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Ngày đo: ${_date(_day.toIso8601String())}',
                                ),
                              ),
                            ],
                          ),
                          onPressed: () async {
                            final day = await showDatePicker(
                              context: context,
                              initialDate: _day,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (day != null && mounted) {
                              setState(() => _day = day);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        for (var i = 0; i < 3; i++) _input(i),
                        AnimatedSwitcher(
                          duration: _motion,
                          layoutBuilder: _switcherLayout,
                          child: Container(
                            key: ValueKey(bmi != null),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.insights_rounded,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    bmi == null
                                        ? 'Nhập cân nặng và chiều cao để xem BMI của lần đo này.'
                                        : 'BMI lần đo này: ${bmi.toStringAsFixed(1)} kg/m²',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      FilledButton.icon(
                        onPressed: _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Lưu số đo'),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Có thể lưu một hoặc nhiều chỉ số',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
