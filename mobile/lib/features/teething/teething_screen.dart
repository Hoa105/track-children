import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../models/tooth.dart';
import '../../services/demo_store.dart';
import 'tooth_chart.dart';

String toothDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

class TeethingScreen extends StatelessWidget {
  const TeethingScreen({super.key, required this.childId});
  final String childId;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: DemoStore.instance,
    builder: (context, _) {
      final store = DemoStore.instance;
      final child = store.childById(childId);
      if (child == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Mọc răng')),
          body: const Center(child: Text('Không tìm thấy hồ sơ bé.')),
        );
      }
      final records = store.teeth(childId);
      final dates = records.values.toList()..sort();
      final dob = DateTime.parse(child['date_of_birth'] as String);
      final now = DateTime.now();
      final months =
          (now.year - dob.year) * 12 +
          now.month -
          dob.month -
          (now.day < dob.day ? 1 : 0);
      final pending =
          PrimaryTooth.all.where((t) => !records.containsKey(t.id)).toList()
            ..sort(
              (a, b) => a.eruptionMonths.$1.compareTo(b.eruptionMonths.$1),
            );
      final seen = <String>{};
      final upcoming = pending
          .where((t) => seen.add('${t.jaw}-${t.type}'))
          .take(3);
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Nụ cười của bé'),
          backgroundColor: AppColors.background,
          scrolledUnderElevation: 0,
        ),
        body: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width > 650
                ? (MediaQuery.sizeOf(context).width - 600) / 2
                : 16,
            vertical: 16,
          ),
          children: [
            Card(
              elevation: 0,
              color: AppColors.primarySoft,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(20),
                leading: const SizedBox(
                  width: 42,
                  height: 48,
                  child: ToothIllustration(),
                ),
                title: Text(
                  'Đã mọc ${records.length}/20 răng sữa',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
                subtitle: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: records.length / 20),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 400),
                      builder: (_, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(8),
                        backgroundColor: Colors.white70,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dates.isEmpty
                          ? 'Bé chưa mọc răng nào'
                          : 'Chiếc răng đầu tiên: ${toothDate(dates.first)}',
                    ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ToothListScreen(childId: childId),
                  ),
                ),
              ),
            ),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      'Những chiếc răng xinh',
                      style: TextStyle(
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
                      ageMonths: months,
                      onToothTap: (t) =>
                          _openEditor(context, childId, tooth: t),
                    ),
                    const ToothChartLegend(),
                    const SizedBox(height: 8),
                    const Text(
                      'Trái/phải theo phía của bé. Tuổi mọc chỉ mang tính tham khảo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (pending.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Răng sắp mọc',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final t in upcoming)
                Card(
                  child: ListTile(
                    leading: SizedBox(
                      width: 36,
                      height: 40,
                      child: ToothIllustration(
                        type: t.type,
                        erupted: false,
                        expected: true,
                      ),
                    ),
                    title: Text(
                      '${t.type.label} ${t.jaw == Jaw.upper ? 'hàm trên' : 'hàm dưới'}',
                    ),
                    subtitle: Text('Tham khảo: ${t.eruptionLabel}'),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            const SizedBox(height: 12),
            const _ParentHandbook(),
          ],
        ),
      );
    },
  );
}

class _ParentHandbook extends StatelessWidget {
  const _ParentHandbook();

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
              const SizedBox(height: 8),
              const Text(
                'Thông tin tham khảo dành cho ba mẹ',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              for (final item in [
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(
                      item.$1,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    children: [
                      Text(
                        item.$2,
                        style: const TextStyle(
                          height: 1.6,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              const Text(
                'Nguồn tham khảo',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const SelectableText(
                'American Dental Association · MouthHealthy\nhttps://www.mouthhealthy.org/all-topics-a-z/eruption-charts\nhttps://www.mouthhealthy.org/all-topics-a-z/teething',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFDCE8DE)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.lightbulb_outline_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Mẹo nhỏ cho ba mẹ',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Mỗi bé có nhịp mọc răng riêng. Các mốc tuổi trên sơ đồ chỉ mang tính tham khảo.',
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _showDetails(context),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          ),
          child: const Text(
            'Tìm hiểu thêm →',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
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
        appBar: AppBar(title: Text('Răng đã mọc (${teeth.length}/20)')),
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
                          fontWeight: FontWeight.w600,
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
                          width: 48,
                          height: 54,
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(14),
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
                            Text(
                              'Mọc ngày ${toothDate(records[t.id]!)}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
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
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: AppColors.background,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .9,
      maxWidth: 640,
    ),
    child: _ToothEditor(childId: childId, tooth: tooth),
  ),
);

class _ToothEditor extends StatefulWidget {
  const _ToothEditor({required this.childId, this.tooth});
  final String childId;
  final PrimaryTooth? tooth;
  @override
  State<_ToothEditor> createState() => _ToothEditorState();
}

class _ToothEditorState extends State<_ToothEditor> {
  String? _toothId;
  late DateTime _date;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _toothId = widget.tooth?.id;
    _date =
        DemoStore.instance.teeth(widget.childId)[_toothId] ??
        DateUtils.dateOnly(DateTime.now());
  }

  Future<void> _save({bool remove = false}) async {
    if (_toothId == null) {
      setState(() => _error = 'Vui lòng chọn răng.');
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
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editing ? 'Sửa răng đã mọc' : 'Ghi nhận răng mọc',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (selected != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 82,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: ToothIllustration(
                        type: selected.type,
                        erupted: editing,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      selected.type.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${selected.jaw == Jaw.upper ? 'Hàm trên' : 'Hàm dưới'} · ${selected.side == JawSide.left ? 'Bên trái' : 'Bên phải'}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      editing
                          ? 'Đã ghi nhận mọc răng'
                          : 'Chưa ghi nhận mọc răng',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
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
            if (_toothId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Thường mọc: ${PrimaryTooth.all.firstWhere((t) => t.id == _toothId).eruptionLabel}',
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryDark,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.calendar_today),
              label: Text('Ngày mọc: ${toothDate(_date)}'),
              onPressed: _busy || child == null
                  ? null
                  : () async {
                      final first = DateUtils.dateOnly(
                        DateTime.parse(child['date_of_birth'] as String),
                      );
                      final last = DateUtils.dateOnly(DateTime.now());
                      if (first.isAfter(last)) {
                        setState(
                          () => _error = 'Vui lòng kiểm tra ngày sinh của bé.',
                        );
                        return;
                      }
                      final date = await showDatePicker(
                        context: context,
                        firstDate: first,
                        lastDate: last,
                        initialDate: _date.isBefore(first)
                            ? first
                            : (_date.isAfter(last) ? last : _date),
                      );
                      if (date != null && mounted) setState(() => _date = date);
                    },
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _busy ? null : () => _save(),
              child: Text(_busy ? 'Đang lưu…' : 'Lưu'),
            ),
            if (editing)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFB65D5D),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _busy ? null : () => _save(remove: true),
                child: const Text('Bỏ đánh dấu'),
              ),
          ],
        ),
      ),
    );
  }
}
