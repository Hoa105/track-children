import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../models/vaccination.dart';
import '../../services/demo_store.dart';
import '../../services/vaccination_schedule.dart';
import 'vaccination_style.dart';

String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';

/// "Sửa thông tin" của một mũi trong lịch chưa tiêm: ngày hẹn, nơi tiêm, loại
/// vắc-xin dự định. Ngày chọn sẵn là ngày hẹn cũ, hoặc ngày dự kiến app tính.
/// Lưu thành bản ghi `given = false` (health.child_vaccinations.scheduled_date);
/// khi ghi nhận đã tiêm, ngày hẹn được giữ lại để so với ngày tiêm thực tế và
/// loại vắc-xin được điền sẵn.
class VaccineAppointmentSheet extends StatefulWidget {
  const VaccineAppointmentSheet({
    super.key,
    required this.childId,
    required this.vaccine,
  });
  final String childId;
  final ScheduledVaccine vaccine;
  @override
  State<VaccineAppointmentSheet> createState() =>
      _VaccineAppointmentSheetState();
}

class _VaccineAppointmentSheetState extends State<VaccineAppointmentSheet> {
  late DateTime _date0 =
      widget.vaccine.appointmentDate ??
      widget.vaccine.expectedDate ??
      widget.vaccine.dueDate;
  late final _place = TextEditingController(
    text: widget.vaccine.appointmentPlace,
  );
  late String? _product = widget.vaccine.plannedProduct;
  bool _saving = false;

  bool get _existing => widget.vaccine.hasAppointment;

  List<VaccineProduct> get _products =>
      vaccineCatalog.vaccine(widget.vaccine.dose.vaccineCode)?.products ??
      const [];

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final child = DemoStore.instance.childById(widget.childId);
    if (child == null) return;
    final dob = DateUtils.dateOnly(
      DateTime.parse(child['date_of_birth'] as String),
    );
    final last = DateTime(DateTime.now().year + 5);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date0.isBefore(dob)
          ? dob
          : _date0.isAfter(last)
          ? last
          : _date0,
      firstDate: dob,
      lastDate: last,
    );
    if (picked != null && mounted) setState(() => _date0 = picked);
  }

  Future<void> _run(Future<void> Function() action, String message) async {
    setState(() => _saving = true);
    try {
      await action();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _save() {
    final dose = widget.vaccine.dose;
    _run(
      () => DemoStore.instance.saveVaccination(widget.childId, {
        'id': dose.id,
        'custom': false,
        'name': dose.name,
        'prevents': dose.prevents,
        'doseLabel': dose.doseLabel,
        'given': false,
        'date': DateUtils.dateOnly(_date0).toIso8601String(),
        'place': _place.text.trim(),
        'product': ?_product,
      }),
      'Chưa lưu được thông tin. Vui lòng thử lại.',
    );
  }

  void _clear() => _run(
    () => DemoStore.instance.removeVaccination(
      widget.childId,
      widget.vaccine.dose.id,
    ),
    'Chưa xóa được thông tin. Vui lòng thử lại.',
  );

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
  );

  @override
  Widget build(BuildContext context) {
    final v = widget.vaccine;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sửa thông tin',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${v.dose.name} · ${v.dose.doseLabel}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Material(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              key: const ValueKey('appointment-date'),
              title: const Text(
                'Ngày hẹn tiêm',
                style: TextStyle(fontSize: 14, color: AppColors.primaryDark),
              ),
              subtitle: Text(
                _date(_date0),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: VaccinationColors.planned,
                ),
              ),
              trailing: const Icon(
                Icons.calendar_month_outlined,
                color: AppColors.primary,
              ),
              onTap: _saving ? null : _pick,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
            child: Text(
              _existing
                  ? 'Ngày dự kiến theo lịch: ${_date(v.expectedDate ?? v.dueDate)}'
                  : 'Đang chọn sẵn ngày dự kiến theo lịch — sửa lại theo ngày cơ sở tiêm hẹn.',
              style: const TextStyle(
                fontSize: 13,
                color: VaccinationColors.secondary,
              ),
            ),
          ),
          TextField(
            key: const ValueKey('appointment-place'),
            controller: _place,
            enabled: !_saving,
            maxLength: 200,
            decoration: _decoration('Nơi tiêm (tùy chọn)'),
          ),
          if (_products.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<String?>(
                key: const ValueKey('appointment-product'),
                initialValue: _product,
                isExpanded: true,
                decoration: _decoration('Loại vắc-xin (tùy chọn)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Chưa rõ')),
                  for (final p in _products)
                    DropdownMenuItem(
                      value: p.code,
                      child: Text(
                        [
                          p.name,
                          if (p.origin != null) p.origin!,
                          if (p.doseCount != null) '${p.doseCount} liều',
                        ].join(' · '),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _product = value),
              ),
            ),
          FilledButton.icon(
            key: const ValueKey('appointment-save'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(0, 52),
            ),
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(_saving ? 'Đang lưu…' : 'Lưu thông tin'),
          ),
          if (_existing)
            TextButton(
              onPressed: _saving ? null : _clear,
              child: const Text('Xóa thông tin đã lưu · dùng ngày dự kiến'),
            ),
        ],
      ),
    );
  }
}
