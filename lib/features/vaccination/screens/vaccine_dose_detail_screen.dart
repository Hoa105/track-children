import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/card_container.dart';
import '../../../core/widgets/medical_disclaimer_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../../models/child.dart';
import '../../../models/vaccination.dart';
import '../../../services/service_locator.dart';
import '../widgets/vaccine_widgets.dart';

/// View a dose of the schedule and record (or un-record) that it was given.
///
/// - TCMR dose not given yet: the "mark as given" form shows straight away.
/// - Anything else opens read-only; the app bar's edit icon unlocks the form.
///   For a custom dose that also covers its own info (tên, phòng bệnh, mũi,
///   ngày/nơi hẹn, ghi chú), the same fields as the add screen.
class VaccineDoseDetailScreen extends StatefulWidget {
  const VaccineDoseDetailScreen({super.key, required this.childId, required this.doseId});

  final String childId;
  final String doseId;

  @override
  State<VaccineDoseDetailScreen> createState() => _VaccineDoseDetailScreenState();
}

class _VaccineDoseDetailScreenState extends State<VaccineDoseDetailScreen> {
  Child? _child;
  ScheduledVaccine? _vaccine;
  bool _saving = false;

  /// Editing an existing record and/or a custom dose's own info.
  bool _editing = false;

  /// Showing the form that marks a not-yet-given dose as given.
  bool _marking = false;

  // Record fields.
  DateTime _date = DateTime.now();
  final _placeCtrl = TextEditingController();
  final _reactionCtrl = TextEditingController();
  final _recordNoteCtrl = TextEditingController();

  // Custom dose fields.
  final _nameCtrl = TextEditingController();
  final _preventsCtrl = TextEditingController();
  final _doseLabelCtrl = TextEditingController();
  final _doseNoteCtrl = TextEditingController();
  final _apptPlaceCtrl = TextEditingController();
  DateTime _apptDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _placeCtrl,
      _reactionCtrl,
      _recordNoteCtrl,
      _nameCtrl,
      _preventsCtrl,
      _doseLabelCtrl,
      _doseNoteCtrl,
      _apptPlaceCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final children = await ServiceLocator.childService.getChildren();
    final child = children.firstWhere((c) => c.id == widget.childId);
    final schedule = await ServiceLocator.vaccinationService.getSchedule(child);
    final vaccine = schedule.firstWhere((v) => v.dose.id == widget.doseId);
    if (!mounted) return;
    setState(() {
      _child = child;
      _vaccine = vaccine;
      _editing = false;
      _marking = vaccine.record == null && !vaccine.dose.isCustom;
      _resetForm();
    });
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void _resetForm() {
    final vaccine = _vaccine!;
    final dose = vaccine.dose;
    final record = vaccine.record;
    _date = record?.date ?? _today;
    _placeCtrl.text = record?.place ?? '';
    _reactionCtrl.text = record?.reaction ?? '';
    _recordNoteCtrl.text = record?.note ?? '';
    _nameCtrl.text = dose.name;
    _preventsCtrl.text = dose.prevents;
    _doseLabelCtrl.text = dose.doseLabel;
    _doseNoteCtrl.text = dose.isCustom ? (dose.note ?? '') : '';
    _apptPlaceCtrl.text = dose.appointmentPlace;
    _apptDate = dose.scheduledDate ?? _today;
  }

  void _cancel() => setState(() {
        _resetForm();
        _editing = false;
        _marking = false;
      });

  /// Marking an appointment as given starts from its date (if already past) and place.
  void _startMarking() => setState(() {
        final dose = _vaccine!.dose;
        final appt = dose.scheduledDate;
        _date = appt != null && !appt.isAfter(_today) ? appt : _today;
        _placeCtrl.text = dose.appointmentPlace;
        _marking = true;
      });

  Future<DateTime?> _pickDate(DateTime initial, {required String help, bool allowFuture = false}) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _child!.dob,
      lastDate: allowFuture ? DateTime(_today.year + 5) : _today,
      helpText: help,
    );
  }

  VaccinationRecord _recordFromForm() => VaccinationRecord(
        childId: widget.childId,
        doseId: widget.doseId,
        date: _date,
        place: _placeCtrl.text.trim(),
        reaction: _reactionCtrl.text.trim(),
        note: _vaccine!.dose.isCustom ? '' : _recordNoteCtrl.text.trim(),
      );

  Future<void> _saveMark() async {
    final dose = _vaccine!.dose;
    setState(() => _saving = true);
    await ServiceLocator.vaccinationService.saveRecord(_recordFromForm());
    if (dose.isCustom) {
      // A custom dose sits in the list by its date — move it to the day it was given.
      await ServiceLocator.vaccinationService.updateCustomDose(
        widget.childId,
        dose.copyWith(scheduledDate: _date, ageMonths: VaccineDose.monthsBetween(_child!.dob, _date)),
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu mũi tiêm')));
    context.pop(true);
  }

  Future<void> _saveEdit() async {
    final vaccine = _vaccine!;
    final dose = vaccine.dose;
    final hasRecord = vaccine.record != null;
    if (dose.isCustom) {
      final name = _nameCtrl.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên vaccine')));
        return;
      }
      final date = hasRecord ? _date : _apptDate;
      final note = _doseNoteCtrl.text.trim();
      final prevents = _preventsCtrl.text.trim();
      final doseLabel = _doseLabelCtrl.text.trim();
      setState(() => _saving = true);
      await ServiceLocator.vaccinationService.updateCustomDose(
        widget.childId,
        VaccineDose(
          id: dose.id,
          name: name,
          prevents: prevents.isEmpty ? name : prevents,
          doseLabel: doseLabel.isEmpty ? 'Mũi tiêm' : doseLabel,
          ageMonths: VaccineDose.monthsBetween(_child!.dob, date),
          note: note.isEmpty ? null : note,
          scheduledDate: date,
          appointmentPlace: hasRecord ? dose.appointmentPlace : _apptPlaceCtrl.text.trim(),
        ),
      );
    } else {
      setState(() => _saving = true);
    }
    if (hasRecord) await ServiceLocator.vaccinationService.saveRecord(_recordFromForm());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu thay đổi')));
    await _load();
    if (mounted) setState(() => _saving = false);
  }

  Future<bool> _confirm(String title, String content, String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _remove() async {
    if (!await _confirm(
      'Bỏ đánh dấu đã tiêm?',
      'Thông tin ngày tiêm, nơi tiêm, phản ứng sau tiêm và ghi chú sẽ bị xóa.',
      'Bỏ đánh dấu',
    )) {
      return;
    }
    await ServiceLocator.vaccinationService.removeRecord(widget.childId, widget.doseId);
    if (!mounted) return;
    context.pop(true);
  }

  Future<void> _deleteCustom() async {
    if (!await _confirm('Xóa mũi tiêm?', 'Mũi tiêm này và toàn bộ thông tin đã ghi nhận sẽ bị xóa.', 'Xóa')) return;
    await ServiceLocator.vaccinationService.removeCustomDose(widget.childId, widget.doseId);
    if (!mounted) return;
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final vaccine = _vaccine;
    final canEdit = vaccine != null && (vaccine.record != null || vaccine.dose.isCustom) && !_marking;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Sửa mũi tiêm' : 'Chi tiết mũi tiêm'),
        actions: [
          if (canEdit)
            IconButton(
              icon: Icon(_editing ? Icons.close_rounded : Icons.edit_outlined),
              tooltip: _editing ? 'Hủy sửa' : 'Sửa',
              onPressed: _editing ? _cancel : () => setState(() => _editing = true),
            ),
        ],
      ),
      body: vaccine == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (_editing && vaccine.dose.isCustom) ..._doseForm(vaccine) else _doseCard(vaccine),
                  const SizedBox(height: AppSpacing.xl),
                  ..._recordSection(vaccine),
                  const SizedBox(height: AppSpacing.lg),
                  const MedicalDisclaimerBanner(
                    text: 'Trước mỗi mũi tiêm, bé cần được khám sàng lọc (QĐ 1575/QĐ-BYT). Theo dõi bé ít nhất 30 phút '
                        'tại điểm tiêm và 24–48 giờ tại nhà; đưa bé đi khám ngay nếu sốt cao, co giật, khó thở hoặc tím tái.',
                  ),
                ],
              ),
            ),
    );
  }

  Widget _doseCard(ScheduledVaccine vaccine) {
    final dose = vaccine.dose;
    final planned = dose.isCustom && vaccine.record == null;
    return CardContainer(
      color: AppColors.surfaceGreenLighter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: vaccine.status.surface, borderRadius: AppRadius.smallRadius),
                child: Icon(Icons.vaccines_rounded, color: vaccine.status.color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dose.name, style: AppTextStyles.h3),
                    const SizedBox(height: 2),
                    Text(dose.doseLabel, style: AppTextStyles.caption),
                  ],
                ),
              ),
              VaccineStatusChip(status: vaccine.status),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(label: 'Phòng bệnh', value: dose.prevents),
          if (dose.isCustom)
            const _InfoRow(label: 'Nguồn', value: 'Mẹ tự thêm (ngoài lịch TCMR)')
          else ...[
            _InfoRow(label: 'Mốc tuổi', value: dose.ageLabel),
            _InfoRow(label: 'Ngày dự kiến', value: vaccineDateFormat.format(vaccine.dueDate)),
          ],
          if (planned) ...[
            _InfoRow(label: 'Ngày hẹn', value: vaccineDateFormat.format(vaccine.dueDate)),
            _InfoRow(label: 'Nơi hẹn tiêm', value: _orDash(dose.appointmentPlace)),
          ],
          if (dose.isCustom)
            _InfoRow(label: 'Ghi chú', value: _orDash(dose.note ?? ''))
          else if (dose.note != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(dose.note!, style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }

  /// Custom dose's own info, same fields as the add screen.
  List<Widget> _doseForm(ScheduledVaccine vaccine) {
    final planned = vaccine.record == null;
    return [
      Text('Thông tin vaccine', style: AppTextStyles.h3),
      const SizedBox(height: AppSpacing.md),
      AppTextField(label: 'Tên vaccine *', hint: 'VD: Cúm, Thủy đậu, Phế cầu...', controller: _nameCtrl),
      const SizedBox(height: AppSpacing.lg),
      AppTextField(label: 'Phòng bệnh', hint: 'VD: Cúm mùa', controller: _preventsCtrl),
      const SizedBox(height: AppSpacing.lg),
      AppTextField(label: 'Mũi', hint: 'VD: Mũi 1, Nhắc lại...', controller: _doseLabelCtrl),
      if (planned) ...[
        const SizedBox(height: AppSpacing.lg),
        _DateField(
          label: 'Ngày hẹn tiêm',
          date: _apptDate,
          onTap: () async {
            final picked = await _pickDate(_apptDate, help: 'Ngày hẹn tiêm', allowFuture: true);
            if (picked != null) setState(() => _apptDate = picked);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(label: 'Nơi hẹn tiêm', hint: 'VD: Trạm y tế phường, VNVC...', controller: _apptPlaceCtrl),
      ],
      const SizedBox(height: AppSpacing.lg),
      AppTextField(label: 'Ghi chú', hint: 'VD: Lô vaccine, lịch mũi tiếp theo...', controller: _doseNoteCtrl, maxLines: 2),
      if (planned) ...[
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(label: 'Lưu thay đổi', onPressed: _saving ? null : _saveEdit),
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(label: 'Xóa mũi tiêm', color: AppColors.danger, onPressed: _deleteCustom),
      ],
    ];
  }

  List<Widget> _recordSection(ScheduledVaccine vaccine) {
    final record = vaccine.record;
    final isCustom = vaccine.dose.isCustom;

    // Custom appointment, not given yet.
    if (record == null && !_marking) {
      if (_editing) return const [];
      return [PrimaryButton(label: 'Đánh dấu đã tiêm', onPressed: _startMarking)];
    }

    // Read-only record.
    if (record != null && !_editing) {
      return [
        Text('Thông tin mũi tiêm', style: AppTextStyles.h3),
        const SizedBox(height: AppSpacing.md),
        CardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(label: 'Ngày tiêm', value: vaccineDateFormat.format(record.date)),
              _InfoRow(label: 'Nơi tiêm', value: _orDash(record.place)),
              _InfoRow(label: 'Phản ứng sau tiêm', value: _orDash(record.reaction)),
              if (!isCustom) _InfoRow(label: 'Ghi chú', value: _orDash(record.note)),
            ],
          ),
        ),
      ];
    }

    // Form: marking as given, or editing the record.
    return [
      Text('Thông tin mũi tiêm', style: AppTextStyles.h3),
      const SizedBox(height: AppSpacing.md),
      _DateField(
        label: 'Ngày tiêm',
        date: _date,
        onTap: () async {
          final picked = await _pickDate(_date, help: 'Ngày tiêm');
          if (picked != null) setState(() => _date = picked);
        },
      ),
      const SizedBox(height: AppSpacing.lg),
      AppTextField(label: 'Nơi tiêm', hint: 'VD: Trạm y tế phường, VNVC...', controller: _placeCtrl),
      const SizedBox(height: AppSpacing.lg),
      AppTextField(
        label: 'Phản ứng sau tiêm',
        hint: 'VD: Sốt nhẹ, sưng đỏ chỗ tiêm, quấy khóc...',
        controller: _reactionCtrl,
        maxLines: 3,
      ),
      if (!isCustom) ...[
        const SizedBox(height: AppSpacing.lg),
        AppTextField(label: 'Ghi chú', hint: 'VD: Lô vaccine, bé quấy tối hôm đó...', controller: _recordNoteCtrl, maxLines: 2),
      ],
      const SizedBox(height: AppSpacing.xl),
      if (record == null) ...[
        PrimaryButton(label: 'Đánh dấu đã tiêm', onPressed: _saving ? null : _saveMark),
        if (isCustom) ...[
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(label: 'Hủy', onPressed: _cancel),
        ],
      ] else ...[
        PrimaryButton(label: 'Lưu thay đổi', onPressed: _saving ? null : _saveEdit),
        const SizedBox(height: AppSpacing.sm),
        isCustom
            ? SecondaryButton(label: 'Xóa mũi tiêm', color: AppColors.danger, onPressed: _deleteCustom)
            : SecondaryButton(label: 'Bỏ đánh dấu đã tiêm', color: AppColors.danger, onPressed: _remove),
      ],
    ];
  }
}

String _orDash(String s) => s.isEmpty ? '—' : s;

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.date, required this.onTap});
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodySecondary),
        const SizedBox(height: 6),
        InkWell(
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
                Expanded(child: Text(vaccineDateFormat.format(date), style: AppTextStyles.body)),
                const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: AppTextStyles.caption)),
          Expanded(child: Text(value, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}
