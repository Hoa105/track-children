import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/bottom_nav_bar.dart';
import '../../../core/widgets/card_container.dart';
import '../../../models/assessment_domain.dart';
import '../../../models/assessment_result.dart';
import '../../../services/service_locator.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<AssessmentResult>? _history;
  bool _chartTab = true;

  @override
  void initState() {
    super.initState();
    ServiceLocator.assessmentService.getHistory('c1').then((h) => setState(() => _history = h));
  }

  @override
  Widget build(BuildContext context) {
    final history = _history;
    return AppShellScaffold(
      tab: AppTab.tracking,
      appBar: AppBar(title: const Text('Lịch sử & biểu đồ xu hướng')),
      body: history == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                  child: Row(
                    children: [
                      Expanded(child: _tab('Biểu đồ', true)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: _tab('Danh sách', false)),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: _chartTab ? _ChartView(history: history) : _ListView(history: history),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _tab(String label, bool value) {
    final active = _chartTab == value;
    return GestureDetector(
      onTap: () => setState(() => _chartTab = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.surfaceGreen : AppColors.surface,
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
          borderRadius: AppRadius.smallRadius,
        ),
        alignment: Alignment.center,
        child: Text(label, style: AppTextStyles.bodySecondary.copyWith(
          color: active ? AppColors.primaryDark : AppColors.textSecondary,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        )),
      ),
    );
  }
}

class _ChartView extends StatelessWidget {
  const _ChartView({required this.history});
  final List<AssessmentResult> history;

  @override
  Widget build(BuildContext context) {
    final sorted = history.reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Xu hướng theo lĩnh vực', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    lineTouchData: const LineTouchData(enabled: false),
                    lineBarsData: [
                      for (final domain in AssessmentDomain.values)
                        LineChartBarData(
                          isCurved: true,
                          barWidth: 2,
                          color: domain.color,
                          dotData: const FlDotData(show: false),
                          spots: [
                            for (var i = 0; i < sorted.length; i++)
                              FlSpot(i.toDouble(), sorted[i].domainScores[domain]!.achieved.toDouble()),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: 6,
                children: [
                  for (final domain in AssessmentDomain.values) _legendItem(domain),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Nhóm Ngôn ngữ giảm 2 lần liên tiếp, 3 nhóm còn lại tăng đều.',
          style: AppTextStyles.bodySecondary,
        ),
      ],
    );
  }

  Widget _legendItem(AssessmentDomain domain) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: domain.color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(domain.label, style: AppTextStyles.caption),
      ],
    );
  }
}

class _ListView extends StatelessWidget {
  const _ListView({required this.history});
  final List<AssessmentResult> history;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final result in history)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: CardContainer(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${result.date.day}/${result.date.month}/${result.date.year}',
                            style: AppTextStyles.titleMedium),
                        const SizedBox(height: 2),
                        Text('${result.totalAchieved}/${result.totalPossible} mốc', style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  _StatusBadge(status: result.overallStatus),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final AssessmentStatus status;

  @override
  Widget build(BuildContext context) {
    final isGood = status == AssessmentStatus.good;
    final color = isGood ? AppColors.primaryDark : AppColors.amberDark;
    final bg = isGood ? AppColors.surfaceGreen : AppColors.amberSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(status.label, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}
