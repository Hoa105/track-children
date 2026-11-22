import 'package:flutter/material.dart';

import '../../app_colors.dart';

/// Presents the server's assessment without calculating a diagnosis locally.
class GrowthAssessmentCard extends StatelessWidget {
  const GrowthAssessmentCard({
    super.key,
    required this.kind,
    required this.assessment,
    required this.onTap,
  });

  final String kind;
  final Future<Map<String, dynamic>> assessment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: assessment,
    builder: (context, snapshot) {
      final data = snapshot.data;
      final current = data?['current'] is Map ? data!['current'] as Map : null;
      final code = current?['classificationCode'];
      final ready = current?['status'] == 'READY';
      final hasSummary =
          current?['summary'] is String &&
          (current!['summary'] as String).trim().isNotEmpty;
      final classified =
          snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError &&
          ready &&
          hasSummary;
      final color = classified
          ? switch (code) {
              'WITHIN_RANGE' => WeightChartColors.positive,
              'SEVERE_THINNESS' ||
              'OBESITY' ||
              'VERY_LOW_HC' ||
              'VERY_HIGH_HC' => WeightChartColors.critical,
              'THINNESS' ||
              'RISK_OVERWEIGHT' ||
              'OVERWEIGHT' ||
              'LOW_HC' ||
              'HIGH_HC' => WeightChartColors.attention,
              _ => WeightChartColors.unknown,
            }
          : WeightChartColors.unknown;
      final String summary;
      if (snapshot.connectionState != ConnectionState.done) {
        summary = 'Đang tải nhận xét…';
      } else if (snapshot.hasError) {
        summary = 'Chưa tải được nhận xét. Nhấn để thử lại.';
      } else if (hasSummary) {
        summary = (current['summary'] as String).trim();
      } else if (data?['preview'] == true) {
        summary = 'Đăng nhập và chọn hồ sơ bé để xem nhận xét.';
      } else {
        summary = kind == 'head'
            ? 'Cần thêm số đo vòng đầu để có nhận xét.'
            : switch (data?['missingMetric']) {
                'weight' => 'Cần thêm cân nặng để có nhận xét.',
                'height' => 'Cần thêm chiều dài/cao phù hợp để có nhận xét.',
                _ => 'Cần thêm cân nặng và chiều dài/cao để có nhận xét.',
              };
      }
      return Material(
        color: GrowthColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: GrowthColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashColor: GrowthColors.primarySoft,
          highlightColor: GrowthColors.primarySoft,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final icon = kind == 'bmi'
                    ? Icons.insights_rounded
                    : Icons.face_retouching_natural_outlined;
                final badge = Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: GrowthColors.iconBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 19, color: GrowthColors.primary),
                );
                final title = Text(
                  kind == 'bmi' ? 'Đánh giá BMI' : 'Đánh giá vòng đầu',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: GrowthColors.textPrimary,
                  ),
                );
                final comment = Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: constraints.maxWidth < 330
                      ? TextAlign.start
                      : TextAlign.end,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                    height: 1.3,
                  ),
                );
                const chevron = Icon(
                  Icons.chevron_right_rounded,
                  color: GrowthColors.textSecondary,
                );
                if (constraints.maxWidth < 330 ||
                    MediaQuery.textScalerOf(context).scale(14) > 21) {
                  return Row(
                    children: [
                      badge,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            title,
                            const SizedBox(height: 3),
                            comment,
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      chevron,
                    ],
                  );
                }
                return Row(
                  children: [
                    badge,
                    const SizedBox(width: 12),
                    title,
                    const SizedBox(width: 12),
                    Expanded(child: comment),
                    const SizedBox(width: 6),
                    chevron,
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

