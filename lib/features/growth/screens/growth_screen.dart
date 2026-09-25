import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/bottom_nav_bar.dart';
import '../../../core/widgets/card_container.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../models/growth_record.dart';
import '../../../services/service_locator.dart';
import '../widgets/bmi_widgets.dart';

class GrowthScreen extends StatefulWidget {
  const GrowthScreen({super.key});

  @override
  State<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends State<GrowthScreen> {
  List<GrowthMetricSeries>? _series;
  int _tabIndex = 0;
  final _valueCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    ServiceLocator.growthService.getSeriesForChild('c1').then((s) => setState(() => _series = s));
  }

  @override
  Widget build(BuildContext context) {
    final series = _series;
    // The BMI tab sits after the measured-metric tabs.
    final tabLabels = [...?series?.map((s) => s.type.label), 'BMI'];
    return AppShellScaffold(
      tab: AppTab.tracking,
      appBar: AppBar(title: const Text('Theo dõi tăng trưởng')),
      body: series == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
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
                if (_tabIndex == series.length)
                  const Expanded(child: BmiTab())
                else
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CurrentValueCard(series: series[_tabIndex]),
                          const SizedBox(height: AppSpacing.lg),
                          CardContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Biểu đồ bách phân vị WHO', style: AppTextStyles.h3),
                                const SizedBox(height: AppSpacing.md),
                                SizedBox(height: 160, child: _PercentileChart(series: series[_tabIndex])),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          CardContainer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Ghi nhận số đo mới', style: AppTextStyles.h3),
                                const SizedBox(height: AppSpacing.md),
                                AppTextField(
                                  label: series[_tabIndex].type.inputLabel,
                                  hint: 'Nhập số đo',
                                  controller: _valueCtrl,
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                PrimaryButton(
                                  label: 'Lưu số đo',
                                  onPressed: () {
                                    ServiceLocator.growthService.addRecord(GrowthRecord(
                                      childId: 'c1',
                                      metricType: series[_tabIndex].type,
                                      value: double.tryParse(_valueCtrl.text) ?? 0,
                                      date: DateTime.now(),
                                      percentile: series[_tabIndex].percentile,
                                    ));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Đã lưu số đo mới.')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          TextButton(
                            onPressed: () => context.push(AppRoutes.growthHistory, extra: series[_tabIndex].type),
                            child: const Text('Xem lịch sử →'),
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

class _CurrentValueCard extends StatelessWidget {
  const _CurrentValueCard({required this.series});
  final GrowthMetricSeries series;

  @override
  Widget build(BuildContext context) {
    return CardContainer(
      color: AppColors.surfaceGreenLighter,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${series.type.label} hiện tại', style: AppTextStyles.caption),
              const SizedBox(height: 4),
              Text('${series.currentValueLabel} ${series.type.unit}', style: AppTextStyles.h1),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Bách phân vị', style: AppTextStyles.caption),
              const SizedBox(height: 4),
              Text('${series.percentile}th', style: AppTextStyles.h2.copyWith(color: AppColors.primaryDark)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Renders a rising line comparable in shape to the prototype's WHO-like
/// SVG polyline (see prototype_reference.md § growth metrics). Exact pixel
/// coordinates from the prototype are not reproduced — only the shape.
class _PercentileChart extends StatelessWidget {
  const _PercentileChart({required this.series});
  final GrowthMetricSeries series;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < series.points.length; i++)
        FlSpot(i.toDouble(), 100 - series.points[i]),
    ];
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: 50,
              getTitlesWidget: (value, meta) {
                final labels = series.axisLabels;
                if (value == 0) return Text(labels[2], style: AppTextStyles.caption);
                if (value == 50) return Text(labels[1], style: AppTextStyles.caption);
                if (value == 100) return Text(labels[0], style: AppTextStyles.caption);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
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
