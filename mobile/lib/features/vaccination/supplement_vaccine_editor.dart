import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../services/demo_store.dart';
import 'vaccination_style.dart';

DateTime get _today => DateUtils.dateOnly(DateTime.now());
String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';

class _DoseDraft {
  final place = TextEditingController();
  final reaction = TextEditingController();
  final note = TextEditingController();
  DateTime date = _today;
  bool given = true;
  bool expanded = true;
  void dispose() {
    for (final c in [place, reaction, note]) {
      c.dispose();
    }
  }
}

class SupplementVaccineEditor extends StatefulWidget {
  const SupplementVaccineEditor({super.key, required this.childId});
  final String childId;
  @override
  State<SupplementVaccineEditor> createState() =>
      _SupplementVaccineEditorState();
}

class _SupplementVaccineEditorState extends State<SupplementVaccineEditor> {
  final _name = TextEditingController();
  final _prevents = TextEditingController();
  final _doses = [_DoseDraft()];
  bool _saving = false;
  bool _closing = false;
  double _dragDistance = 0;
  String? _error;
  bool get _dirty =>
      _name.text.isNotEmpty ||
      _prevents.text.isNotEmpty ||
      _doses.length != 1 ||
      _doses.any(
        (d) =>
            d.place.text.isNotEmpty ||
            d.reaction.text.isNotEmpty ||
            d.note.text.isNotEmpty ||
            d.date != _today ||
            !d.given,
      );

  @override
  void dispose() {
    _name.dispose();
    _prevents.dispose();
    for (final d in _doses) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _close() async {
    if (_saving || _closing) return;
    if (!_dirty) {
      Navigator.pop(context);
      return;
    }
    _closing = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Bỏ thay đổi chưa lưu?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text('Các mũi vừa nhập sẽ không được lưu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tiếp tục nhập'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bỏ thay đổi'),
          ),
        ],
      ),
    );
    _closing = false;
    if (discard == true && mounted) Navigator.pop(context);
  }

  Future<void> _pick(_DoseDraft draft) async {
    final child = DemoStore.instance.childById(widget.childId);
    if (child == null) return;
    final first = DateUtils.dateOnly(
      DateTime.parse(child['date_of_birth'] as String),
    );
    final last = draft.given ? _today : DateTime(_today.year + 5);
    final picked = await showDatePicker(
      context: context,
      initialDate: draft.date.isAfter(last)
          ? last
          : draft.date.isBefore(first)
          ? first
          : draft.date,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null && mounted) setState(() => draft.date = picked);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Nhập tên vắc-xin.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final group = 'custom-${DateTime.now().microsecondsSinceEpoch}';
    try {
      await DemoStore.instance.saveVaccinations(widget.childId, [
        for (final (i, d) in _doses.indexed)
          {
            'id': '$group-$i',
            'groupId': group,
            'custom': true,
            'name': _name.text.trim(),
            'prevents': _prevents.text.trim(),
            'doseLabel': 'Mũi ${i + 1}',
            'given': d.given,
            'date': d.date.toIso8601String(),
            'place': d.place.text.trim(),
            'reaction': d.given ? d.reaction.text.trim() : '',
            'note': d.note.text.trim(),
          },
      ]);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Chưa lưu được. Kiểm tra ngày của từng mũi và thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool multiline = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: controller,
      enabled: !_saving,
      minLines: multiline ? 3 : 1,
      maxLines: multiline ? 5 : 1,
      maxLength: multiline ? 500 : null,
      keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: AppColors.primaryDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        alignLabelWithHint: multiline,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving && !_dirty,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _close();
    },
    child: Material(
      color: AppColors.background,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          GestureDetector(
            key: const ValueKey('supplement-drag-header'),
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: (_) => _dragDistance = 0,
            onVerticalDragUpdate: (details) =>
                _dragDistance += details.delta.dy,
            onVerticalDragEnd: (details) {
              if (_dragDistance > 70 || (details.primaryVelocity ?? 0) > 700) {
                _close();
              }
              _dragDistance = 0;
            },
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Thêm vắc-xin bổ sung',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Đóng biểu mẫu',
                        onPressed: _saving ? null : _close,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            fit: FlexFit.tight,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Thông tin vắc-xin',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _field('Tên vaccine', _name),
                        _field('Phòng bệnh', _prevents),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  for (final (i, d) in _doses.indexed)
                    Padding(
                      key: ObjectKey(d),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: d.given
                            ? VaccinationColors.recordedSoft
                            : VaccinationColors.plannedSoft,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(text: 'Mũi ${i + 1}'),
                                          if (!d.expanded)
                                            TextSpan(
                                              text: ' · ${_date(d.date)}',
                                              style: TextStyle(
                                                color: d.given
                                                    ? AppColors.primaryDark
                                                    : VaccinationColors.planned,
                                              ),
                                            ),
                                        ],
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: d.expanded
                                        ? 'Thu gọn mũi ${i + 1}'
                                        : 'Mở mũi ${i + 1}',
                                    onPressed: _saving
                                        ? null
                                        : () => setState(
                                            () => d.expanded = !d.expanded,
                                          ),
                                    icon: Icon(
                                      d.expanded
                                          ? Icons.expand_less_rounded
                                          : Icons.expand_more_rounded,
                                    ),
                                  ),
                                  if (_doses.length > 1)
                                    IconButton(
                                      tooltip: 'Bỏ mũi ${i + 1}',
                                      onPressed: _saving
                                          ? null
                                          : () {
                                              setState(() => _doses.remove(d));
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback(
                                                    (_) => d.dispose(),
                                                  );
                                            },
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    ),
                                ],
                              ),
                              if (d.expanded) ...[
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('Đã tiêm'),
                                      labelStyle: const TextStyle(
                                        color: VaccinationColors.recorded,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      checkmarkColor:
                                          VaccinationColors.recorded,
                                      selected: d.given,
                                      onSelected: _saving
                                          ? null
                                          : (_) => setState(() {
                                              d.given = true;
                                              if (d.date.isAfter(_today)) {
                                                d.date = _today;
                                              }
                                            }),
                                    ),
                                    ChoiceChip(
                                      label: const Text('Dự kiến'),
                                      selected: !d.given,
                                      selectedColor: const Color(0xFFD8C6EE),
                                      labelStyle: const TextStyle(
                                        color: AppColors.purpleText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      checkmarkColor: AppColors.purpleText,
                                      side: BorderSide(
                                        color: d.given
                                            ? AppColors.border
                                            : AppColors.purpleText,
                                      ),
                                      onSelected: _saving
                                          ? null
                                          : (_) =>
                                                setState(() => d.given = false),
                                    ),
                                  ],
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    d.given ? 'Ngày tiêm' : 'Ngày dự kiến',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _date(d.date),
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: d.given
                                          ? VaccinationColors.recorded
                                          : AppColors.purpleText,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.calendar_month_outlined,
                                    color: AppColors.primary,
                                  ),
                                  onTap: _saving ? null : () => _pick(d),
                                ),
                                ExpansionTile(
                                  key: ValueKey(
                                    'extra-${identityHashCode(d)}-${d.given}',
                                  ),
                                  tilePadding: EdgeInsets.zero,
                                  shape: const Border(),
                                  collapsedShape: const Border(),
                                  title: const Text(
                                    'Thêm thông tin',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  children: [
                                    _field(
                                      d.given ? 'Nơi tiêm' : 'Nơi hẹn tiêm',
                                      d.place,
                                    ),
                                    if (d.given)
                                      _field(
                                        'Phản ứng sau tiêm',
                                        d.reaction,
                                        multiline: true,
                                      ),
                                    _field('Ghi chú', d.note, multiline: true),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  TextButton.icon(
                    key: const ValueKey('supplement-add-dose'),
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                            for (final draft in _doses) {
                              draft.expanded = false;
                            }
                            _doses.add(_DoseDraft());
                          }),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Thêm mũi tiêm'),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52),
                  ),
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(
                    _saving
                        ? 'Đang lưu…'
                        : _doses.length == 1
                        ? 'Lưu mũi tiêm'
                        : 'Lưu ${_doses.length} mũi tiêm',
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
