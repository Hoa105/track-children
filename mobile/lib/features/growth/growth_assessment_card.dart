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
      final ranges = current?['visualRanges'];
      final range = ranges is List
          ? ranges.whereType<Map>().where((r) => r['code'] == code).firstOrNull
          : null;
      final labels = current?['classificationLabels'];
      final label = range?['label'] ?? (labels is Map ? labels[code] : null);
      final classified =
          snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError &&
          ready &&
          label is String &&
          label.isNotEmpty;
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
      final String status;
      final String summary;
      if (snapshot.connectionState != ConnectionState.done) {
        status = 'Đang tải nhận xét';
        summary = 'Đang tải nhận xét…';
      } else if (snapshot.hasError) {
        status = 'Chưa tải được';
        summary = 'Chưa tải được nhận xét. Nhấn để thử lại.';
      } else if (current?['summary'] is String &&
          (current!['summary'] as String).trim().isNotEmpty) {
        status = ready && label is String && label.isNotEmpty
            ? label
            : switch (current['reason']) {
                'WHO_FLAGGED' ||
                'WHO_OUT_OF_RANGE' ||
                'INVALID_MEASURE_POSITION' => 'Cần kiểm tra lại',
                _ => 'Chưa thể đánh giá',
              };
        summary = current['summary'] as String;
      } else if (data?['preview'] == true) {
        status = 'Chưa có đánh giá';
        summary = 'Đăng nhập và chọn hồ sơ bé để xem nhận xét.';
      } else {
        status = 'Chưa đủ số đo';
        summary = kind == 'head'
            ? 'Cần thêm số đo vòng đầu để có nhận xét.'
            : switch (data?['missingMetric']) {
                'weight' => 'Cần thêm cân nặng để có nhận xét.',
                'height' => 'Cần thêm chiều dài/cao phù hợp để có nhận xét.',
                _ => 'Cần thêm cân nặng và chiều dài/cao để có nhận xét.',
              };
      }
      final action =
          !snapshot.hasError && snapshot.connectionState == ConnectionState.done
          ? (current?['action'])
          : null;
      return Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        kind == 'bmi' ? 'Đánh giá BMI' : 'Đánh giá vòng đầu',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  summary,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    height: 1.45,
                  ),
                ),
                if (action is String && action.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Nên làm gì?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    action,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
