import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/bottom_nav_bar.dart';
import '../../../core/widgets/card_container.dart';
import '../../../models/growth_record.dart';
import '../../../services/service_locator.dart';
import '../widgets/bmi_widgets.dart';

/// History of past measurements for a single growth metric (weight, height
/// or head circumference) — kept separate from the assessment domain
/// [HistoryScreen] since the two track unrelated data.
class GrowthHistoryScreen extends StatefulWidget {
  const GrowthHistoryScreen({super.key, required this.initialType, this.initialShowBmi = false});
  final GrowthMetricType initialType;
  final bool initialShowBmi;

  /// Route `extra` that opens this screen on the BMI tab.
  static const bmiTabExtra = 'bmi';

  @override
  State<GrowthHistoryScreen> createState() => _GrowthHistoryScreenState();
}

class _GrowthHistoryScreenState extends State<GrowthHistoryScreen> {
  late GrowthMetricType _type;
  bool _showBmi = false;
  List<GrowthRecord>? _records;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _showBmi = widget.initialShowBmi;
    _load();
  }

  void _load() {
    _records = null;
    ServiceLocator.growthService.getRecords('c1', _type).then((r) => setState(() => _records = r));
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    return AppShellScaffold(
      tab: AppTab.tracking,
      appBar: AppBar(title: const Text('Lịch sử tăng trưởng')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: Row(
              children: List.generate(GrowthMetricType.values.length + 1, (i) {
                // The BMI tab sits after the measured-metric tabs.
                final isBmi = i == GrowthMetricType.values.length;
                final type = isBmi ? null : GrowthMetricType.values[i];
                final active = isBmi ? _showBmi : !_showBmi && type == _type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _showBmi = isBmi;
                      if (type != null) {
                        _type = type;
                        _load();
                      }
                    }),
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
                        type?.label ?? 'BMI',
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
          if (_showBmi)
            const Expanded(child: BmiHistoryList())
          else
            Expanded(
              child: records == null
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CardContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Xu hướng ${_type.label.toLowerCase()}', style: AppTextStyles.h3),
                                const SizedBox(height: AppSpacing.md),
                                SizedBox(height: 160, child: _TrendChart(records: records)),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text('Các lần đo', style: AppTextStyles.h3),
                          const SizedBox(height: AppSpacing.md),
                          for (final record in records)
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.md),
                              child: CardContainer(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${record.date.day}/${record.date.month}/${record.date.year}',
                                            style: AppTextStyles.titleMedium,
                                          ),
                                          const SizedBox(height: 2),
                                          Text('${record.value} ${_type.unit}', style: AppTextStyles.caption),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceGreen,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '${record.percentile}th',
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.primaryDark,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.records});
  final List<GrowthRecord> records;

  @override
  Widget build(BuildContext context) {
    final sorted = records.reversed.toList();
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < sorted.length; i++) FlSpot(i.toDouble(), sorted[i].value)],
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: AppColors.surfaceGreen.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}
