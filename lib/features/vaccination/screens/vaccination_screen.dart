import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/bottom_nav_bar.dart';
import '../../../core/widgets/card_container.dart';
import '../../../core/widgets/medical_disclaimer_banner.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/progress_bar.dart';
import '../../../models/child.dart';
import '../../../models/tooth.dart';
import '../../../models/vaccination.dart';
import '../../../services/service_locator.dart';
import '../widgets/tooth_actions.dart';
import '../widgets/tooth_chart.dart';
import '../widgets/vaccine_widgets.dart';

/// "Tiêm chủng / Mọc răng" module — 2 tabs sharing one child selector.
class VaccinationScreen extends StatefulWidget {
  const VaccinationScreen({super.key, this.childId, this.initialShowTeeth = false});

  /// Child to open with; defaults to the first child.
  final String? childId;
  final bool initialShowTeeth;

  @override
  State<VaccinationScreen> createState() => _VaccinationScreenState();
}

class _VaccinationScreenState extends State<VaccinationScreen> {
  List<Child> _children = const [];
  Child? _child;
  late int _tabIndex = widget.initialShowTeeth ? 1 : 0;

  /// Bumped after the [+] button adds something so the current tab rebuilds and reloads.
  int _reload = 0;

  Future<void> _add(Child child) async {
    await context.push('${_tabIndex == 0 ? AppRoutes.vaccineAdd : AppRoutes.toothAdd}/${child.id}');
    if (mounted) setState(() => _reload++);
  }

  @override
  void initState() {
    super.initState();
    ServiceLocator.childService.getChildren().then((c) {
      if (!mounted || c.isEmpty) return;
      setState(() {
        _children = c;
        _child = c.firstWhere((x) => x.id == widget.childId, orElse: () => c.first);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = _child;
    const tabLabels = ['Tiêm chủng', 'Mọc răng'];
    return AppShellScaffold(
      tab: AppTab.more,
      appBar: AppBar(title: const Text('Tiêm chủng & Mọc răng')),
      floatingActionButton: child != null
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              tooltip: _tabIndex == 0 ? 'Thêm mũi tiêm' : 'Ghi nhận răng mọc',
              onPressed: () => _add(child),
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
      body: child == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_children.length > 1)
                  SizedBox(
                    height: 52,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                      itemCount: _children.length,
                      separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (context, i) {
                        final c = _children[i];
                        return AppChip(
                          label: c.name.split(' ').last,
                          icon: Icons.child_care_rounded,
                          selected: c.id == child.id,
                          onTap: () => setState(() => _child = c),
                        );
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                  child: Row(
                    children: List.generate(tabLabels.length, (i) {
                      final active = i == _tabIndex;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _tabIndex = i),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: active ? AppColors.surfaceGreen : AppColors.surface,
                              border: Border.all(color: active ? AppColors.primary : AppColors.border),
                              borderRadius: AppRadius.smallRadius,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              tabLabels[i],
                              style: AppTextStyles.bodySecondary.copyWith(
                                color: active ? AppColors.primaryDark : AppColors.textSecondary,
                                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Expanded(
                  child: _tabIndex == 0
                      ? _VaccineTab(key: ValueKey('vaccine-${child.id}-$_reload'), child: child)
                      : _TeethingTab(key: ValueKey('teeth-${child.id}-$_reload'), child: child),
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tiêm chủng
// ---------------------------------------------------------------------------

enum _VaccineFilter { all, pending, done }

extension on _VaccineFilter {
  String get label => switch (this) {
        _VaccineFilter.all => 'Tất cả',
        _VaccineFilter.pending => 'Cần tiêm',
        _VaccineFilter.done => 'Đã tiêm',
      };

  bool matches(ScheduledVaccine v) => switch (this) {
        _VaccineFilter.all => true,
        _VaccineFilter.pending => v.status != VaccineStatus.done,
        _VaccineFilter.done => v.status == VaccineStatus.done,
      };
}

class _VaccineTab extends StatefulWidget {
  const _VaccineTab({super.key, required this.child});
  final Child child;

  @override
  State<_VaccineTab> createState() => _VaccineTabState();
}

class _VaccineTabState extends State<_VaccineTab> {
  List<ScheduledVaccine>? _schedule;
  _VaccineFilter _filter = _VaccineFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await ServiceLocator.vaccinationService.getSchedule(widget.child);
    if (mounted) setState(() => _schedule = s);
  }

  Future<void> _open(ScheduledVaccine v) async {
    await context.push('${AppRoutes.vaccineDoseDetail}/${widget.child.id}/${v.dose.id}');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final schedule = _schedule;
    if (schedule == null) return const Center(child: CircularProgressIndicator());

    final done = schedule.where((v) => v.status == VaccineStatus.done).length;
    final overdue = schedule.where((v) => v.status == VaccineStatus.overdue).length;
    final next = mostUrgentVaccine(schedule);
    final visible = schedule.where(_filter.matches).toList();

    // Group by age milestone, keeping schedule order.
    final groups = <int, List<ScheduledVaccine>>{};
    for (final v in visible) {
      groups.putIfAbsent(v.dose.ageMonths, () => []).add(v);
    }

    return ListView(
      // Extra bottom space so the [+] button doesn't cover the disclaimer.
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 88),
      children: [
        CardContainer(
          color: AppColors.surfaceGreenLighter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Đã tiêm $done/${schedule.length} mũi', style: AppTextStyles.h3)),
                  Text('TCMR', style: AppTextStyles.captionBold.copyWith(color: AppColors.primaryDark)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppProgressBar(value: done / schedule.length),
              if (next != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Mũi tiếp theo', style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text('${next.dose.name} · ${next.dose.doseLabel}', style: AppTextStyles.titleMedium),
                const SizedBox(height: 2),
                Text(
                  vaccineDueText(next, DateTime.now()),
                  style: AppTextStyles.caption.copyWith(color: next.status.color),
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(label: 'Ghi nhận mũi tiêm', onPressed: () => _open(next)),
              ],
            ],
          ),
        ),
        if (overdue > 0) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.dangerSurfaceLight,
              border: Border.all(color: AppColors.dangerSurface),
              borderRadius: AppRadius.smallRadius,
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.danger),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Có $overdue mũi đã quá hạn. Mẹ nên liên hệ cơ sở tiêm chủng để được tư vấn tiêm bù.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.dangerDark),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final f in _VaccineFilter.values)
              AppChip(label: f.label, selected: f == _filter, onTap: () => setState(() => _filter = f)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Text('Không có mũi tiêm nào.', textAlign: TextAlign.center, style: AppTextStyles.bodySecondary),
          ),
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
            child: Row(
              children: [
                Text(entry.value.first.dose.ageLabel, style: AppTextStyles.titleMedium),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    '· dự kiến ${vaccineDateFormat.format(entry.value.first.dueDate)}',
                    style: AppTextStyles.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          for (final v in entry.value)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: VaccineTile(vaccine: v, onTap: () => _open(v)),
            ),
        ],
        const SizedBox(height: AppSpacing.md),
        const MedicalDisclaimerBanner(
          text: 'Lịch tham khảo theo Chương trình Tiêm chủng mở rộng quốc gia. Lịch thực tế theo hướng dẫn của cơ sở '
              'tiêm chủng; bé cần được khám sàng lọc trước mỗi mũi tiêm.',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Mọc răng
// ---------------------------------------------------------------------------

class _TeethingTab extends StatefulWidget {
  const _TeethingTab({super.key, required this.child});
  final Child child;

  @override
  State<_TeethingTab> createState() => _TeethingTabState();
}

class _TeethingTabState extends State<_TeethingTab> {
  Map<String, ToothRecord>? _records;

  int get _ageMonths {
    final now = DateTime.now();
    final dob = widget.child.dob;
    return (now.year - dob.year) * 12 + now.month - dob.month - (now.day < dob.day ? 1 : 0);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await ServiceLocator.teethingService.getRecords(widget.child);
    if (mounted) setState(() => _records = r);
  }

  Future<void> _onToothTap(PrimaryTooth tooth) async {
    if (await showToothActions(context, child: widget.child, tooth: tooth, record: _records?[tooth.id])) _load();
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    if (records == null) return const Center(child: CircularProgressIndicator());

    final total = PrimaryTooth.all.length;
    final first = records.values.isEmpty
        ? null
        : records.values.reduce((a, b) => a.eruptedDate.isBefore(b.eruptedDate) ? a : b);
    final upcoming = PrimaryTooth.all.where((t) => !records.containsKey(t.id)).toList()
      ..sort((a, b) => a.eruptionMonths.$1.compareTo(b.eruptionMonths.$1));
    // Symmetric pairs share a window — show one entry per (jaw, type).
    final seen = <String>{};
    final nextTeeth = upcoming.where((t) => seen.add('${t.jaw.name}-${t.type.name}')).take(3).toList();

    return ListView(
      // Extra bottom space so the [+] button doesn't cover the disclaimer.
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 88),
      children: [
        CardContainer(
          color: AppColors.surfaceGreenLighter,
          onTap: () async {
            await context.push('${AppRoutes.toothList}/${widget.child.id}');
            _load();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Đã mọc ${records.length}/$total răng sữa', style: AppTextStyles.h3)),
                  const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.primaryDark),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppProgressBar(value: records.length / total),
              const SizedBox(height: AppSpacing.sm),
              Text(
                first == null
                    ? 'Bé chưa mọc răng nào · ${widget.child.ageLabel(DateTime.now())}'
                    : 'Chiếc răng đầu tiên: ${vaccineDateFormat.format(first.eruptedDate)}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        CardContainer(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.touch_app_outlined, size: 16, color: AppColors.primaryDark),
                  const SizedBox(width: 4),
                  Text(
                    'Chạm vào răng để ghi nhận hoặc sửa',
                    style: AppTextStyles.captionBold.copyWith(color: AppColors.primaryDark),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ToothChart(
                eruptedIds: records.keys.toSet(),
                ageMonths: _ageMonths,
                onToothTap: _onToothTap,
              ),
              const SizedBox(height: AppSpacing.md),
              const ToothChartLegend(),
            ],
          ),
        ),
        if (nextTeeth.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Răng sắp mọc', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.sm),
          for (final t in nextTeeth)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: CardContainer(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 20, color: AppColors.textMuted),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        '${t.type.label} ${t.jaw == Jaw.upper ? 'hàm trên' : 'hàm dưới'}',
                        style: AppTextStyles.body,
                      ),
                    ),
                    Text(t.eruptionLabel, style: AppTextStyles.caption),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.purpleSurfaceLight,
            border: Border.all(color: AppColors.purpleBorder),
            borderRadius: AppRadius.smallRadius,
          ),
          child: Text(
            'Dấu hiệu mọc răng thường gặp: chảy nhiều nước dãi, thích cắn đồ vật, lợi sưng, quấy hơn bình thường. '
            'Thời điểm mọc răng ở mỗi bé rất khác nhau.',
            style: AppTextStyles.caption.copyWith(color: AppColors.purpleBody),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const MedicalDisclaimerBanner(
          text: 'Nếu bé quá 18 tháng chưa mọc chiếc răng nào, hoặc bé sốt cao, tiêu chảy kéo dài khi mọc răng, '
              'mẹ nên đưa bé đi khám.',
        ),
      ],
    );
  }
}
