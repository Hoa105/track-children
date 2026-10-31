import 'package:flutter/material.dart';

import 'growth_repository.dart' show formatGrowthValue;

/// Describes position only; these are not clinical classifications.
String growthVelocityPosition(double z) => z < 0
    ? 'Mức tăng thấp hơn trung vị tham chiếu WHO cho bé cùng giới, cùng khoảng tuổi và kỳ đo.'
    : z > 0
    ? 'Mức tăng cao hơn trung vị tham chiếu WHO cho bé cùng giới, cùng khoảng tuổi và kỳ đo.'
    : 'Mức tăng bằng trung vị tham chiếu WHO cho bé cùng giới, cùng khoảng tuổi và kỳ đo.';

class GrowthVelocityInterpretation extends StatelessWidget {
  const GrowthVelocityInterpretation({
    required this.grams,
    this.zScore,
    this.from,
    this.to,
    this.unit = 'g',
    this.metricName = 'cân',
    super.key,
  });

  final double grams;
  final String unit, metricName;
  final double? zScore;
  final DateTime? from, to;

  @override
  Widget build(BuildContext context) {
    final z = zScore;
    final valid = z != null && z.isFinite;
    String date(DateTime d) => '${d.day}/${d.month}/${d.year}';
    const body = TextStyle(
      fontFamily: 'Nunito',
      height: 1.5,
      color: Color(0xFF285574),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Mức tăng $metricName trong kỳ của bé',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              color: Color(0xFF12639A),
            ),
          ),
          if (from != null && to != null)
            Text('${date(from!)} – ${date(to!)}', style: body),
          const SizedBox(height: 6),
          Text(
            '${grams > 0 ? '+' : ''}${formatGrowthValue(grams)}\u00A0$unit${valid ? ' · Z-score: ${formatGrowthValue(z)}' : ''}',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF086DAF),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            valid
                ? growthVelocityPosition(z)
                : 'Chỉ ghi nhận mức tăng — chưa có đối chiếu WHO phù hợp.',
            style: body,
          ),
          if (valid) ...[
            const SizedBox(height: 8),
            Text(
              'Một kỳ tăng ít hơn hoặc nhiều hơn chưa đủ để kết luận bé có vấn đề tăng trưởng. Hãy xem cùng diễn tiến các kỳ trước, ${unit == 'cm' ? 'chiều dài/chiều cao' : 'cân nặng'} theo tuổi và tình trạng sức khỏe của bé.',
              style: body,
            ),
          ],
        ],
      ),
    );
  }
}
