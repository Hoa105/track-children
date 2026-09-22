import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/card_container.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// "Xu hướng 5 lần đánh giá" sparkline card — links to history (to10).
class TrendCard extends StatelessWidget {
  const TrendCard({super.key, this.onViewDetail});
  final VoidCallback? onViewDetail;

  @override
  Widget build(BuildContext context) {
    return CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Xu hướng 5 lần đánh giá', action: 'Xem chi tiết', onActionTap: onViewDetail),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Nhóm Ngôn ngữ giảm 2 lần liên tiếp, 3 nhóm còn lại tăng đều.',
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 90,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  _line(const [6, 6, 5, 6, 6], AppColors.primary),
                  _line(const [6, 6, 5, 6, 6], AppColors.purple),
                  _line(const [5, 5, 4, 5, 4], AppColors.amber),
                  _line(const [5, 5, 4, 6, 6], AppColors.danger),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static LineChartBarData _line(List<double> values, Color color) {
    return LineChartBarData(
      spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
      isCurved: true,
      color: color,
      barWidth: 2,
      dotData: const FlDotData(show: false),
    );
  }
}
