import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'growth_velocity_interpretation.dart';
import 'growth_repository.dart' show formatGrowthValue;

/// Z-score comes from the validated calculation, never from shaded regions.
class GrowthVelocityReferenceScale extends StatelessWidget {
  const GrowthVelocityReferenceScale({
    required this.grams,
    required this.values,
    this.zScore,
    this.unit = 'g',
    this.metricName = 'cân',
    super.key,
  });
  final double grams;
  final String unit, metricName;
  final double? zScore;
  final Map<int, double> values;
  @override
  Widget build(BuildContext context) {
    final z = zScore;
    final valid = z != null && z.isFinite;
    const bandColors = [
      Color(0xFF8B72EB),
      Color(0xFF4DADF1),
      Color(0xFF48D8D0),
      Color(0xFF4DADF1),
      Color(0xFF8B72EB),
    ];
    const bandLabels = [
      'Dưới −3 SD',
      'Từ −3 đến dưới −2 SD',
      'Từ −2 đến +2 SD',
      'Trên +2 đến +3 SD',
      'Trên +3 SD',
    ];
    final markerColor = valid
        ? const Color(0xFFEA780F)
        : WeightChartColors.unknown;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3FCFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFAADEF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GrowthVelocityInterpretation(
            grams: grams,
            zScore: z,
            unit: unit,
            metricName: metricName,
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              const inset = 16.0;
              final width = constraints.maxWidth - inset * 2;
              double x(double sd) => inset + (sd + 3.5) / 7 * width;
              return Semantics(
                label: valid
                    ? 'Z-score ${formatGrowthValue(z)}; mức tăng ${formatGrowthValue(grams)} $unit'
                    : 'Chưa có Z-score hợp lệ để đánh dấu vị trí',
                child: SizedBox(
                  height: 102,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: inset,
                        right: inset,
                        top: 22,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            children: [
                              for (var i = 0; i < bandColors.length; i++)
                                Expanded(
                                  flex: const [5, 10, 40, 10, 5][i],
                                  child: Container(
                                    height: 22,
                                    color: bandColors[i],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      for (var tick = -3; tick <= 3; tick++) ...[
                        Positioned(
                          left: x(tick.toDouble()),
                          top: 16,
                          child: Container(
                            width: 1,
                            height: 30,
                            color: WeightChartColors.axis.withValues(alpha: .3),
                          ),
                        ),
                        Positioned(
                          left: x(tick.toDouble()) - 18,
                          top: 50,
                          width: 36,
                          child: Text(
                            tick > 0 ? '+$tick' : '$tick',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 12,
                              fontWeight: tick == 0
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: WeightChartColors.axis,
                            ),
                          ),
                        ),
                      ],
                      if (valid) ...[
                        Positioned(
                          left: x(z.clamp(-3.5, 3.5)) - 1,
                          top: 6,
                          child: Container(
                            width: 2,
                            height: 40,
                            color: markerColor,
                          ),
                        ),
                        Positioned(
                          left: x(z.clamp(-3.5, 3.5)) - 9,
                          top: 21,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: markerColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x40EA780F),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const Positioned(
                        left: 0,
                        right: 0,
                        top: 78,
                        child: Text(
                          'Z-score WHO',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            color: WeightChartColors.axis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (var i = 0; i < bandLabels.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: bandColors[i]),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        bandLabels[i],
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: WeightChartColors.axis,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (!valid)
            const Text(
              'Chưa có Z-score hợp lệ để đánh dấu vị trí.',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                color: WeightChartColors.muted,
              ),
            ),
          if (valid && z.abs() > 3.5)
            const Text(
              'Vị trí vượt ngoài thang hiển thị.',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                color: WeightChartColors.muted,
              ),
            ),
          if (values.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final sd in [-3, -2, 0, 2, 3])
                  if (values[sd] != null)
                    Text(
                      '${sd == 0
                          ? 'Trung vị'
                          : sd > 0
                          ? '+$sd'
                          : '$sd'}: ${formatGrowthValue(values[sd]!)}\u00A0$unit',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        color: WeightChartColors.axis,
                      ),
                    ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Các mốc là tham chiếu của đúng kỳ đo. Các khoảng trên thang chỉ mô tả vị trí Z-score, không phải nhãn phân loại dinh dưỡng.',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              height: 1.5,
              color: WeightChartColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
