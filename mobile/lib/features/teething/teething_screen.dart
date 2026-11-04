import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../models/tooth.dart';
import '../../services/demo_store.dart';
import 'teething_reference_tab.dart';
import 'tooth_chart.dart';
import 'teething_date_picker.dart';
import 'teething_age_selector.dart';

String toothDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

class TeethingScreen extends StatefulWidget {
  const TeethingScreen({super.key, required this.childId});
  final String childId;

  @override
  State<TeethingScreen> createState() => _TeethingScreenState();
}

class _TeethingScreenState extends State<TeethingScreen> {
  int? _selectedMonth;
  int _mode = 0;
  String get childId => widget.childId;

  @override
  void initState() {
    super.initState();
    unawaited(DemoStore.instance.syncTeeth(childId));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: DemoStore.instance,
    builder: (context, _) {
      final store = DemoStore.instance;
      final child = store.childById(childId);
      if (child == null) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Mọc răng',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          body: const Center(child: Text('Không tìm thấy hồ sơ bé.')),
        );
      }
      final allRecords = store.teeth(childId);
      final dob = DateTime.parse(child['date_of_birth'] as String);
      final now = DateTime.now();
      final months =
          (now.year - dob.year) * 12 +
          now.month -
          dob.month -
          (now.day < dob.day ? 1 : 0);
      final currentMonth = months.clamp(0, 60);
      final selectedMonth = (_selectedMonth ?? currentMonth).clamp(
        0,
        _mode == 1 ? currentMonth : 60,
      );
      final cutoff = DateTime(dob.year, dob.month + selectedMonth + 1, 1);
      final cutoffDay = dob.day.clamp(
        1,
        DateTime(cutoff.year, cutoff.month + 1, 0).day,
      );
      final endExclusive = DateTime(cutoff.year, cutoff.month, cutoffDay);
      final records = {
        for (final entry in allRecords.entries)
          if (entry.value.isBefore(endExclusive)) entry.key: entry.value,
      };
      final pending =
          PrimaryTooth.all
              .where((tooth) => !records.containsKey(tooth.id))
              .toList()
            ..sort(
              (a, b) => a.eruptionMonths.$1.compareTo(b.eruptionMonths.$1),
            );
      final pairs = <int>{};
      final upcoming = pending
          .where((tooth) => pairs.add(tooth.pairCode))
          .take(3)
          .toList();
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Theo dõi mọc răng',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          backgroundColor: AppColors.background,
          scrolledUnderElevation: 0,
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: _TeethingModeSwitcher(
                  value: _mode,
                  onChanged: (value) => setState(() {
                    _mode = value;
                    if (_mode == 1 && selectedMonth > currentMonth) {
                      _selectedMonth = currentMonth;
                    }
                  }),
                ),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            TeethingAgeSelector(
              month: selectedMonth,
              currentMonth: currentMonth,
              maxMonth: _mode == 1 ? currentMonth : 60,
              onChanged: (month) => setState(() => _selectedMonth = month),
            ),
            Expanded(
              child: IndexedStack(
                index: _mode,
                children: [
                  TeethingReferenceTab(initialAgeMonths: selectedMonth),
                  ListView(
                    key: const PageStorageKey('child-teething-tab'),
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.sizeOf(context).width > 650
                          ? (MediaQuery.sizeOf(context).width - 600) / 2
                          : 16,
                      vertical: 16,
                    ),
                    children: [
                      Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                'Đã mọc ${records.length}/20 răng sữa',
                                key: const Key('child-teething-summary'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Chạm vào răng để ghi nhận hoặc sửa',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              ToothChart(
                                eruptedIds: records.keys.toSet(),
                                ageMonths: selectedMonth,
                                showPairNumbers: true,
                                onToothTap: (t) =>
                                    _openEditor(context, childId, tooth: t),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Material(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(22),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: const Key('erupted-teeth-list-button'),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ToothListScreen(childId: childId),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    '${allRecords.length}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Text(
                                    'Danh sách răng đã mọc',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (upcoming.isNotEmpty) ...[
                        _UpcomingTeeth(teeth: upcoming),
                        const SizedBox(height: 16),
                      ],
                      const _ParentReminder(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _TeethingModeSwitcher extends StatelessWidget {
  const _TeethingModeSwitcher({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Container(
      height: 62,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140B3D2E),
            blurRadius: 20,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedAlign(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: value == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: .5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFEAF4EE), Color(0xFFD9EADF)],
                  ),
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F286B52),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              _ModeButton(
                key: const Key('teething-tab-reference'),
                label: 'Tham khảo',
                selected: value == 0,
                onTap: () => onChanged(0),
              ),
              _ModeButton(
                key: const Key('teething-tab-child'),
                label: 'Răng của bé',
                selected: value == 1,
                onTap: () => onChanged(1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected
                        ? AppColors.primaryDark
                        : AppColors.textSecondary,
                  ),
                  child: Text(label),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _UpcomingTeeth extends StatelessWidget {
  const _UpcomingTeeth({required this.teeth});
  final List<PrimaryTooth> teeth;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Răng sắp mọc',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        for (final tooth in teeth)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 42,
                  height: 46,
                  child: ToothIllustration(type: tooth.type, erupted: false),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tooth.type.label} ${tooth.jaw == Jaw.upper ? 'hàm trên' : 'hàm dưới'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tooth.eruptionLabel,
                        style: const TextStyle(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _ParentReminder extends StatelessWidget {
  const _ParentReminder();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mẹo nhỏ cho ba mẹ',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Mỗi bé có nhịp mọc răng riêng. Các mốc tuổi chỉ mang tính tham khảo.',
          style: TextStyle(height: 1.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            showDragHandle: true,
            backgroundColor: AppColors.background,
            builder: (context) => ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .8,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Đóng',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                    const Text(
                      'Kiến thức mọc răng',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final item in const [
                      (
                        'Dấu hiệu mọc răng là gì?',
                        'Bé có thể chảy nhiều nước dãi, quấy hoặc khó ngủ khi mọc răng.',
                      ),
                      (
                        'Khi nào bé bắt đầu mọc răng?',
                        'Răng sữa thường bắt đầu mọc trong khoảng 6–12 tháng. Thời điểm mọc khác nhau ở mỗi bé; các mốc trên sơ đồ chỉ mang tính tham khảo.',
                      ),
                      (
                        'Khi nào cần liên hệ bác sĩ?',
                        'Nếu bé sốt hoặc tiêu chảy, hãy liên hệ bác sĩ; không mặc định do mọc răng.',
                      ),
                    ])
                      Card(
                        elevation: 0,
                        color: Colors.white,
                        child: ExpansionTile(
                          title: Text(
                            item.$1,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            18,
                          ),
                          children: [
                            Text(item.$2, style: const TextStyle(height: 1.5)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      'Nguồn tham khảo',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const SelectableText(
                      'American Dental Association · MouthHealthy\nhttps://www.mouthhealthy.org/all-topics-a-z/eruption-charts\nhttps://www.mouthhealthy.org/all-topics-a-z/teething',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          child: const Text('Tìm hiểu thêm →'),
        ),
      ],
    ),
  );
}

class ToothListScreen extends StatelessWidget {
  const ToothListScreen({super.key, required this.childId});
  final String childId;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: DemoStore.instance,
    builder: (context, _) {
      final records = DemoStore.instance.teeth(childId);
      final teeth =
          PrimaryTooth.all.where((t) => records.containsKey(t.id)).toList()
            ..sort((a, b) => records[b.id]!.compareTo(records[a.id]!));
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Răng đã mọc',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        body: teeth.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 64,
                        height: 72,
                        child: ToothIllustration(erupted: false),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Bé chưa mọc răng nào.',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Chạm vào răng trên sơ đồ để lưu cột mốc đầu tiên.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.sizeOf(context).width > 650
                      ? (MediaQuery.sizeOf(context).width - 600) / 2
                      : 16,
                  vertical: 20,
                ),
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${teeth.length} / 20 răng sữa',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: teeth.length / 20,
                            minHeight: 8,
                            backgroundColor: Colors.white,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final t in teeth)
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          width: 64,
                          height: 64,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft.withValues(alpha: .6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: ToothIllustration(type: t.type),
                        ),
                        title: Text(
                          t.type.label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '${t.jaw == Jaw.upper ? 'Hàm trên' : 'Hàm dưới'} · ${t.side == JawSide.left ? 'Bên trái' : 'Bên phải'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                toothDate(records[t.id]!),
                                style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.primary,
                        ),
                        onTap: () => _openEditor(context, childId, tooth: t),
                      ),
                    ),
                ],
              ),
      );
    },
  );
}

Future<void> _openEditor(
  BuildContext context,
  String childId, {
  PrimaryTooth? tooth,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    builder: (_) => ToothEditorScreen(childId: childId, tooth: tooth),
  ),
);

class ToothEditorScreen extends StatefulWidget {
  const ToothEditorScreen({super.key, required this.childId, this.tooth});
  final String childId;
  final PrimaryTooth? tooth;
  @override
  State<ToothEditorScreen> createState() => _ToothEditorState();
}

class _ToothEditorState extends State<ToothEditorScreen> {
  String? _toothId;
  late DateTime _date;
  bool _busy = false;
  // A mounted editor may predate this field after a web hot reload.
  // Fall back to the saved record until the parent makes a selection.
  bool? _markedErupted;
  bool get _isErupted =>
      _markedErupted ??
      DemoStore.instance.teeth(widget.childId).containsKey(_toothId);
  String? _error;
  @override
  void initState() {
    super.initState();
    _toothId = widget.tooth?.id;
    _date =
        DemoStore.instance.teeth(widget.childId)[_toothId] ??
        DateUtils.dateOnly(DateTime.now());
  }

  Future<void> _save() async {
    if (_toothId == null) {
      setState(() => _error = 'Vui lòng chọn răng.');
      return;
    }
    final remove =
        !_isErupted &&
        DemoStore.instance.teeth(widget.childId).containsKey(_toothId);
    if (!_isErupted && !remove) {
      Navigator.pop(context);
      return;
    }
    if (remove) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Bỏ đánh dấu răng đã mọc?'),
          content: const Text('Bản ghi ngày mọc của răng này sẽ được xóa.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Bỏ đánh dấu'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (remove) {
        await DemoStore.instance.removeTooth(widget.childId, _toothId!);
      } else {
        await DemoStore.instance.saveTooth(widget.childId, _toothId!, _date);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Chưa lưu được. Kiểm tra ngày mọc và thử lại.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = DemoStore.instance;
    final child = store.childById(widget.childId);
    final records = store.teeth(widget.childId);
    final editing = records.containsKey(_toothId);
    final selected = _toothId == null
        ? null
        : PrimaryTooth.all.firstWhere((t) => t.id == _toothId);
    final options =
        PrimaryTooth.all
            .where((t) => t.id == _toothId || !records.containsKey(t.id))
            .toList()
          ..sort((a, b) => a.eruptionMonths.$1.compareTo(b.eruptionMonths.$1));
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            editing ? 'Sửa răng đã mọc' : 'Ghi nhận răng đã mọc',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (selected != null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 88,
                                  height: 92,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: ToothIllustration(
                                    type: selected.type,
                                    erupted: _isErupted,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  selected.label,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.4,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        RadioGroup<bool>(
                          groupValue: _isErupted,
                          onChanged: (value) {
                            if (value != null && !_busy) {
                              setState(() => _markedErupted = value);
                            }
                          },
                          child: Row(
                            children: [
                              for (final status in const [
                                (true, 'Đã mọc'),
                                (false, 'Chưa mọc'),
                              ])
                                Expanded(
                                  child: InkWell(
                                    key: Key('tooth-status-${status.$1}'),
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: _busy
                                        ? null
                                        : () => setState(
                                            () => _markedErupted = status.$1,
                                          ),
                                    child: SizedBox(
                                      height: 56,
                                      child: Row(
                                        children: [
                                          Radio<bool>(
                                            value: status.$1,
                                            enabled: !_busy,
                                            activeColor: AppColors.primary,
                                          ),
                                          Expanded(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                status.$2,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.primaryDark,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (widget.tooth == null) ...[
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _toothId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Răng · hàm · bên',
                            ),
                            items: [
                              for (final t in options)
                                DropdownMenuItem(
                                  value: t.id,
                                  child: Text(t.label, maxLines: 2),
                                ),
                            ],
                            onChanged: _busy || widget.tooth != null
                                ? null
                                : (value) => setState(() => _toothId = value),
                          ),
                        ],
                        if (_isErupted) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Ngày mọc',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(
                                        () => _date = DateUtils.dateOnly(
                                          DateTime.now(),
                                        ),
                                      ),
                                child: const Text('Hôm nay'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (child != null &&
                              !DateTime.parse(child['date_of_birth'] as String)
                                  .isAfter(DateTime.now()))
                            IgnorePointer(
                              ignoring: _busy,
                              child: TeethingDatePicker(
                                value: _date,
                                firstDate: DateUtils.dateOnly(
                                  DateTime.parse(
                                    child['date_of_birth'] as String,
                                  ),
                                ),
                                lastDate: DateUtils.dateOnly(DateTime.now()),
                                onChanged: (date) =>
                                    setState(() => _date = date),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              key: const Key('tooth-editor-footer'),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null) ...[
                            Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          FilledButton(
                            key: const Key('save-tooth-button'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              minimumSize: const Size.fromHeight(56),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed: _busy ? null : () => _save(),
                            child: Text(_busy ? 'Đang lưu…' : 'Lưu'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
