import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../models/child.dart';
import '../../../models/tooth.dart';
import '../../../services/service_locator.dart';
import '../widgets/vaccine_widgets.dart';

/// Record a newly erupted tooth: pick the tooth type from those not fully
/// erupted yet, then the side (a side that already erupted is disabled).
class ToothAddScreen extends StatefulWidget {
  const ToothAddScreen({super.key, required this.childId});

  final String childId;

  @override
  State<ToothAddScreen> createState() => _ToothAddScreenState();
}

class _ToothAddScreenState extends State<ToothAddScreen> {
  Child? _child;
  Set<String> _erupted = const {};
  (Jaw, ToothType)? _type;
  JawSide? _side;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final children = await ServiceLocator.childService.getChildren();
    final child = children.firstWhere((c) => c.id == widget.childId);
    final records = await ServiceLocator.teethingService.getRecords(child);
    if (!mounted) return;
    setState(() {
      _child = child;
      _erupted = records.keys.toSet();
    });
  }

  bool _isErupted(Jaw jaw, ToothType type, JawSide side) => _erupted.contains(PrimaryTooth(jaw, side, type).id);

  /// Tooth types with at least one side still to come, in typical eruption order.
  List<(Jaw, ToothType)> get _pendingTypes => [
        for (final jaw in Jaw.values)
          for (final type in ToothType.values)
            if (JawSide.values.any((side) => !_isErupted(jaw, type, side))) (jaw, type),
      ]..sort((a, b) => PrimaryTooth(a.$1, JawSide.left, a.$2)
          .eruptionMonths
          .$1
          .compareTo(PrimaryTooth(b.$1, JawSide.left, b.$2).eruptionMonths.$1));

  String _typeLabel((Jaw, ToothType) t) => '${t.$2.label} ${t.$1 == Jaw.upper ? 'hàm trên' : 'hàm dưới'}';

  Future<void> _pickType() async {
    final picked = await showModalBottomSheet<(Jaw, ToothType)>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                child: Text('Chọn răng chưa mọc', style: AppTextStyles.h3),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final t in _pendingTypes)
                      ListTile(
                        title: Text(_typeLabel(t), style: AppTextStyles.body),
                        subtitle: Text(
                          'Thường mọc lúc ${PrimaryTooth(t.$1, JawSide.left, t.$2).eruptionLabel}',
                          style: AppTextStyles.caption,
                        ),
                        trailing: t == _type ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                        onTap: () => Navigator.pop(sheetContext, t),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _type = picked;
      // Pre-select the first side still available.
      _side = JawSide.values.where((s) => !_isErupted(picked.$1, picked.$2, s)).firstOrNull;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _child!.dob,
      lastDate: DateTime.now(),
      helpText: 'Ngày mọc răng',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final type = _type;
    final side = _side;
    if (type == null || side == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn răng và bên mọc')));
      return;
    }
    setState(() => _saving = true);
    await ServiceLocator.teethingService.saveRecord(
      ToothRecord(childId: widget.childId, toothId: PrimaryTooth(type.$1, side, type.$2).id, eruptedDate: _date),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu răng mọc')));
    context.pop(true);
  }

  Widget _field({required String text, required IconData icon, required VoidCallback onTap, bool placeholder = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smallRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: AppRadius.smallRadius,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: placeholder ? AppTextStyles.body.copyWith(color: AppColors.textMuted) : AppTextStyles.body,
              ),
            ),
            Icon(icon, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = _type;
    return Scaffold(
      appBar: AppBar(title: const Text('Ghi nhận răng mọc')),
      body: _child == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (_pendingTypes.isEmpty)
                    Text('Bé đã mọc đủ 20 răng sữa.', style: AppTextStyles.bodySecondary)
                  else ...[
                    Text('Răng đã mọc', style: AppTextStyles.bodySecondary),
                    const SizedBox(height: 6),
                    _field(
                      text: type == null ? 'Chọn răng' : _typeLabel(type),
                      icon: Icons.keyboard_arrow_down_rounded,
                      onTap: _pickType,
                      placeholder: type == null,
                    ),
                    if (type != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text('Bên', style: AppTextStyles.bodySecondary),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          for (final side in JawSide.values.reversed) // Trái trước, Phải sau
                            _sideChip(type, side),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Text('Ngày mọc', style: AppTextStyles.bodySecondary),
                    const SizedBox(height: 6),
                    _field(text: vaccineDateFormat.format(_date), icon: Icons.calendar_today_outlined, onTap: _pickDate),
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(label: 'Lưu', onPressed: _saving ? null : _save),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _sideChip((Jaw, ToothType) type, JawSide side) {
    final erupted = _isErupted(type.$1, type.$2, side);
    final label = side == JawSide.left ? 'Trái' : 'Phải';
    return AppChip(
      label: erupted ? '$label · đã mọc' : label,
      icon: erupted ? Icons.check_rounded : null,
      selected: _side == side,
      enabled: !erupted,
      onTap: () => setState(() => _side = side),
    );
  }
}
