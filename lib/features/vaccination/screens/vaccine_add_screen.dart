import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/medical_disclaimer_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../models/child.dart';
import '../../../models/vaccination.dart';
import '../../../services/service_locator.dart';
import '../widgets/vaccine_widgets.dart';

/// Add a dose outside the TCMR schedule (vaccine dịch vụ, tiêm bù...) —
/// either already given or as an upcoming appointment.
class VaccineAddScreen extends StatefulWidget {
  const VaccineAddScreen({super.key, required this.childId});

  final String childId;

  @override
  State<VaccineAddScreen> createState() => _VaccineAddScreenState();
}

class _VaccineAddScreenState extends State<VaccineAddScreen> {
  Child? _child;
  bool _given = true;
  DateTime _date = DateTime.now();
  final _nameCtrl = TextEditingController();
  final _preventsCtrl = TextEditingController();
  final _doseLabelCtrl = TextEditingController();
  final _placeCtrl = TextEditingController();
  final _reactionCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    ServiceLocator.childService.getChildren().then((children) {
      if (!mounted) return;
      setState(() => _child = children.firstWhere((c) => c.id == widget.childId));
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _preventsCtrl.dispose();
    _doseLabelCtrl.dispose();
    _placeCtrl.dispose();
    _reactionCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void _setGiven(bool given) {
    setState(() {
      _given = given;
      // A given dose can't be in the future, an appointment can't be in the past.
      if (given && _date.isAfter(_today)) _date = _today;
      if (!given && _date.isBefore(_today)) _date = _today;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _given ? _child!.dob : _today,
      lastDate: _given ? _today : DateTime(_today.year + 5),
      helpText: _given ? 'Ngày tiêm' : 'Ngày hẹn tiêm',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên vaccine')));
      return;
    }
    final doseId = 'custom-${DateTime.now().microsecondsSinceEpoch}';
    final note = _noteCtrl.text.trim();
    final doseLabel = _doseLabelCtrl.text.trim();

    setState(() => _saving = true);
    await ServiceLocator.vaccinationService.addCustomDose(
      widget.childId,
      VaccineDose(
        id: doseId,
        name: name,
        prevents: _preventsCtrl.text.trim().isEmpty ? name : _preventsCtrl.text.trim(),
        doseLabel: doseLabel.isEmpty ? 'Mũi tiêm' : doseLabel,
        ageMonths: VaccineDose.monthsBetween(_child!.dob, _date),
        note: note.isEmpty ? null : note,
        scheduledDate: _date,
        // Given: the place belongs to the record below; appointment: keep it on the dose.
        appointmentPlace: _given ? '' : _placeCtrl.text.trim(),
      ),
      record: _given
          ? VaccinationRecord(
              childId: widget.childId,
              doseId: doseId,
              date: _date,
              place: _placeCtrl.text.trim(),
              reaction: _reactionCtrl.text.trim(),
            )
          : null,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm mũi tiêm')));
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm mũi tiêm')),
      body: _child == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text(
                    'Dùng cho các mũi ngoài lịch Tiêm chủng mở rộng như vaccine dịch vụ (cúm, thủy đậu, phế cầu...) '
                    'hoặc mũi tiêm bù.',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(label: 'Tên vaccine *', hint: 'VD: Cúm, Thủy đậu, Phế cầu...', controller: _nameCtrl),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(label: 'Phòng bệnh', hint: 'VD: Cúm mùa', controller: _preventsCtrl),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(label: 'Mũi', hint: 'VD: Mũi 1, Nhắc lại...', controller: _doseLabelCtrl),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Trạng thái', style: AppTextStyles.bodySecondary),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      AppChip(label: 'Đã tiêm', selected: _given, onTap: () => _setGiven(true)),
                      AppChip(label: 'Lịch hẹn', selected: !_given, onTap: () => _setGiven(false)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(_given ? 'Ngày tiêm' : 'Ngày hẹn tiêm', style: AppTextStyles.bodySecondary),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _pickDate,
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
                          Expanded(child: Text(vaccineDateFormat.format(_date), style: AppTextStyles.body)),
                          const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(label: _given ? 'Nơi tiêm' : 'Nơi hẹn tiêm', hint: 'VD: Trạm y tế phường, VNVC...', controller: _placeCtrl),
                  if (_given) ...[
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Phản ứng sau tiêm',
                      hint: 'VD: Sốt nhẹ, sưng đỏ chỗ tiêm, quấy khóc...',
                      controller: _reactionCtrl,
                      maxLines: 3,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(label: 'Ghi chú', hint: 'VD: Lô vaccine, lịch mũi tiếp theo...', controller: _noteCtrl, maxLines: 2),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(label: 'Thêm mũi tiêm', onPressed: _saving ? null : _save),
                  const SizedBox(height: AppSpacing.lg),
                  const MedicalDisclaimerBanner(
                    text: 'Lịch tiêm vaccine dịch vụ nên theo tư vấn của bác sĩ tại cơ sở tiêm chủng.',
                  ),
                ],
              ),
            ),
    );
  }
}
