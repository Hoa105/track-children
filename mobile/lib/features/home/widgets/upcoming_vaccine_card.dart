import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/card_container.dart';
import '../../../models/child.dart';
import '../../../models/vaccination.dart';
import '../../../services/service_locator.dart';
import '../../vaccination/widgets/vaccine_widgets.dart';

/// "Mũi tiêm tiếp theo" card — hidden once every dose is recorded.
class UpcomingVaccineCard extends StatefulWidget {
  const UpcomingVaccineCard({super.key, required this.child, this.onTap});

  final Child child;
  final VoidCallback? onTap;

  @override
  State<UpcomingVaccineCard> createState() => _UpcomingVaccineCardState();
}

class _UpcomingVaccineCardState extends State<UpcomingVaccineCard> {
  ScheduledVaccine? _next;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(UpcomingVaccineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child.id != widget.child.id) _load();
  }

  Future<void> _load() async {
    final schedule = await ServiceLocator.vaccinationService.getSchedule(widget.child);
    if (mounted) setState(() => _next = mostUrgentVaccine(schedule));
  }

  @override
  Widget build(BuildContext context) {
    final next = _next;
    if (next == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: CardContainer(
        onTap: widget.onTap,
        borderColor: next.status == VaccineStatus.overdue ? AppColors.dangerSurface : AppColors.border,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: next.status.surface, borderRadius: AppRadius.smallRadius),
              child: Icon(Icons.vaccines_rounded, size: 20, color: next.status.color),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mũi tiêm tiếp theo: ${next.dose.name}', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${next.dose.doseLabel} · ${vaccineDueText(next, DateTime.now())}',
                    style: AppTextStyles.caption.copyWith(
                      color: next.status == VaccineStatus.upcoming ? null : next.status.color,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
