import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/card_container.dart';
import '../../../models/vaccination.dart';

final vaccineDateFormat = DateFormat('dd/MM/yyyy');

extension VaccineStatusColors on VaccineStatus {
  Color get color => switch (this) {
        VaccineStatus.done => AppColors.primaryDark,
        VaccineStatus.due => AppColors.amberDark,
        VaccineStatus.overdue => AppColors.danger,
        VaccineStatus.upcoming => AppColors.textSecondaryAlt,
      };

  Color get surface => switch (this) {
        VaccineStatus.done => AppColors.surfaceGreen,
        VaccineStatus.due => AppColors.amberSurface,
        VaccineStatus.overdue => AppColors.dangerSurface,
        VaccineStatus.upcoming => AppColors.background,
      };
}

/// Most urgent dose still to be given: overdue first, then due, then the
/// earliest upcoming one. Null when every dose is done.
ScheduledVaccine? mostUrgentVaccine(List<ScheduledVaccine> schedule) {
  const priority = [VaccineStatus.overdue, VaccineStatus.due, VaccineStatus.upcoming];
  final pending = schedule.where((v) => v.status != VaccineStatus.done).toList()
    ..sort((a, b) {
      final byStatus = priority.indexOf(a.status).compareTo(priority.indexOf(b.status));
      return byStatus != 0 ? byStatus : a.dueDate.compareTo(b.dueDate);
    });
  return pending.firstOrNull;
}

/// "Quá hạn 5 ngày" / "Hôm nay" / "Còn 12 ngày · 12/05/2026".
String vaccineDueText(ScheduledVaccine v, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final days = v.dueDate.difference(today).inDays;
  if (days < 0) return 'Quá hạn ${-days} ngày · ${vaccineDateFormat.format(v.dueDate)}';
  if (days == 0) return 'Đến lịch hôm nay';
  return 'Còn $days ngày · ${vaccineDateFormat.format(v.dueDate)}';
}

class VaccineStatusChip extends StatelessWidget {
  const VaccineStatusChip({super.key, required this.status});
  final VaccineStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: status.surface, borderRadius: AppRadius.pillRadius),
      child: Text(status.label, style: AppTextStyles.captionBold.copyWith(color: status.color)),
    );
  }
}

class VaccineTile extends StatelessWidget {
  const VaccineTile({super.key, required this.vaccine, this.onTap});

  final ScheduledVaccine vaccine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final record = vaccine.record;
    final status = vaccine.status;
    return CardContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      borderColor: status == VaccineStatus.overdue ? AppColors.dangerSurface : AppColors.border,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: status.surface, borderRadius: AppRadius.smallRadius),
            child: Icon(
              status == VaccineStatus.done ? Icons.check_rounded : Icons.vaccines_rounded,
              size: 20,
              color: status.color,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${vaccine.dose.name} · ${vaccine.dose.doseLabel}', style: AppTextStyles.titleMedium),
                const SizedBox(height: 2),
                Text(
                  record != null
                      ? 'Đã tiêm ${vaccineDateFormat.format(record.date)}'
                      : 'Phòng ${vaccine.dose.prevents.toLowerCase()}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          VaccineStatusChip(status: status),
        ],
      ),
    );
  }
}
