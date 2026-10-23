import 'vaccination_style.dart';

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../models/vaccination.dart';
import '../../services/vaccination_schedule.dart';

String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';

class VaccineDetailSheet extends StatelessWidget {
  const VaccineDetailSheet({super.key, required this.vaccine});
  final ScheduledVaccine vaccine;

  @override
  Widget build(BuildContext context) {
    final v = vaccine;
    final record = v.record;
    final place = record?.place ?? v.appointmentPlace;
    final late = record?.daysFromSchedule;
    final note = record?.note ?? v.dose.note ?? '';
    final product = vaccineCatalog
        .vaccine(v.dose.vaccineCode)
        ?.product(record?.product ?? v.plannedProduct);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetHeading(title: 'Chi tiết mũi tiêm'),
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Card(
                      color: record != null
                          ? VaccinationColors.recordedSoft
                          : VaccinationColors.plannedSoft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.dose.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                v.dose.doseLabel,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: record != null
                                      ? AppColors.primary
                                      : VaccinationColors.planned,
                                ),
                              ),
                              _Status(vaccine: v),
                              if (!v.dose.isCustom)
                                Text(
                                  v.dose.isTcmr ? 'TCMR · miễn phí' : 'Dịch vụ',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: VaccinationColors.secondary,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_month_outlined,
                                size: 20,
                                color: record != null
                                    ? AppColors.primaryDark
                                    : VaccinationColors.planned,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${record != null
                                      ? "Ngày tiêm"
                                      : v.hasAppointment
                                      ? "Ngày hẹn"
                                      : "Dự kiến"} · ${_date(record?.date ?? v.dueDate)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: record != null
                                        ? AppColors.primaryDark
                                        : VaccinationColors.planned,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (record?.scheduledDate != null ||
                        (v.hasAppointment && !v.dose.isCustom)) ...[
                      const SizedBox(height: 10),
                      _Card(
                        child: _Info(
                          icon: Icons.event_outlined,
                          text: record != null
                              ? 'Ngày hẹn: ${_date(record.scheduledDate!)}'
                                    '${record.appointmentPlace.isEmpty ? '' : ' · ${record.appointmentPlace}'}'
                                    ' · ${late == 0
                                        ? 'tiêm đúng hẹn'
                                        : late! > 0
                                        ? 'tiêm trễ $late ngày'
                                        : 'tiêm sớm ${-late} ngày'}'
                              : 'Ngày dự kiến theo lịch: ${_date(v.expectedDate ?? v.dueDate)}',
                        ),
                      ),
                    ],
                    if (place.isNotEmpty ||
                        record != null ||
                        product != null ||
                        v.dose.prevents.isNotEmpty ||
                        note.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (place.isNotEmpty)
                              _Info(
                                icon: Icons.location_on_outlined,
                                text:
                                    '${record == null ? "Nơi hẹn tiêm" : "Nơi tiêm"}: $place',
                              ),
                            if (place.isNotEmpty && record != null)
                              const SizedBox(height: 10),
                            if (product != null) ...[
                              _Info(
                                icon: Icons.vaccines_outlined,
                                text: 'Loại vắc-xin: ${product.name}',
                              ),
                              const SizedBox(height: 10),
                            ],
                            if (record != null)
                              _Info(
                                icon: Icons.favorite_border_rounded,
                                text:
                                    'Phản ứng: ${record.reaction.isEmpty ? "Chưa ghi nhận" : record.reaction}',
                              ),
                            if (v.dose.prevents.isNotEmpty || note.isNotEmpty)
                              ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                childrenPadding: const EdgeInsets.only(
                                  bottom: 4,
                                ),
                                shape: const Border(),
                                collapsedShape: const Border(),
                                title: const Text(
                                  'Phòng bệnh & ghi chú',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                children: [
                                  if (v.dose.prevents.isNotEmpty)
                                    _Info(
                                      icon: Icons.shield_outlined,
                                      text: 'Phòng bệnh: ${v.dose.prevents}',
                                    ),
                                  if (v.dose.prevents.isNotEmpty &&
                                      note.isNotEmpty)
                                    const SizedBox(height: 10),
                                  if (note.isNotEmpty)
                                    _Info(
                                      icon: Icons.notes_rounded,
                                      text: 'Ghi chú: $note',
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.pop(
                      context,
                      record == null ? 'mark' : 'edit',
                    ),
                    icon: Icon(
                      record == null
                          ? Icons.check_rounded
                          : Icons.edit_outlined,
                    ),
                    label: Text(
                      record == null ? 'Ghi nhận đã tiêm' : 'Sửa thông tin',
                    ),
                  ),
                  if (record == null && v.dose.isCustom)
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'edit'),
                      child: const Text('Sửa thông tin'),
                    ),
                  if (record == null && !v.dose.isCustom)
                    TextButton.icon(
                      key: const ValueKey('vaccine-appointment'),
                      onPressed: () => Navigator.pop(context, 'appointment'),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Sửa thông tin'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VaccineDosesSheet extends StatelessWidget {
  const VaccineDosesSheet({
    super.key,
    required this.title,
    required this.doses,
  });
  final String title;
  final List<ScheduledVaccine> doses;

  @override
  Widget build(BuildContext context) {
    final sameVaccine = doses.map((v) => v.dose.name).toSet().length == 1;
    final done = doses.where((v) => v.record != null).length;
    return FractionallySizedBox(
      heightFactor: .85,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _SheetHeading(title: title),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  if (sameVaccine) ...[
                    _Card(
                      color: AppColors.primarySoft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '$done/${doses.length}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const Text(
                            'mũi đã ghi nhận',
                            style: TextStyle(color: AppColors.primaryDark),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: doses.isEmpty ? 0 : done / doses.length,
                              minHeight: 6,
                              color: AppColors.primary,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          if (doses.first.dose.prevents.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              'Phòng bệnh: ${doses.first.dose.prevents}',
                              style: const TextStyle(
                                height: 1.5,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  for (final (i, v) in doses.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: v.record != null
                            ? VaccinationColors.recordedSoft
                            : VaccinationColors.plannedSoft,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => Navigator.pop(context, v),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: v.record != null
                                        ? VaccinationColors.recordedSoft
                                        : VaccinationColors.plannedSoft,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: v.record != null
                                      ? const Icon(
                                          Icons.check_rounded,
                                          color: VaccinationColors.recorded,
                                          size: 20,
                                        )
                                      : Text(
                                          '${i + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sameVaccine
                                            ? v.dose.doseLabel
                                            : '${v.dose.name} · ${v.dose.doseLabel}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      _Status(vaccine: v),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${v.record != null
                                            ? "Đã tiêm"
                                            : v.hasAppointment
                                            ? "Ngày hẹn"
                                            : "Dự kiến"} · ${_date(v.record?.date ?? v.dueDate)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: v.record != null
                                              ? AppColors.primaryDark
                                              : VaccinationColors.planned,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: VaccinationColors.secondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  const Text(
                    'Theo lịch tham khảo · Đối chiếu với cơ sở tiêm',
                    style: TextStyle(
                      fontSize: 12,
                      color: VaccinationColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHeading extends StatelessWidget {
  const _SheetHeading({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Đóng chi tiết',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.color = AppColors.surface});
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(22),
    ),
    child: child,
  );
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: AppColors.primary),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(height: 1.5, color: VaccinationColors.ink),
        ),
      ),
    ],
  );
}

class _Status extends StatelessWidget {
  const _Status({required this.vaccine});
  final ScheduledVaccine vaccine;
  @override
  Widget build(BuildContext context) {
    final now = DateUtils.dateOnly(DateTime.now());
    final review = vaccine.record == null && !vaccine.dueDate.isAfter(now);
    final color = vaccine.record != null
        ? VaccinationColors.recorded
        : review
        ? VaccinationColors.attention
        : VaccinationColors.planned;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: review ? const Color(0xFFFFF0D8) : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        vaccine.record != null
            ? 'Đã ghi nhận'
            : vaccine.hasAppointment
            ? 'Lịch hẹn đã lưu'
            : review
            ? 'Chưa ghi nhận'
            : 'Sắp tới',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
