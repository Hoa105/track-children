import 'package:flutter/material.dart';

import 'growth_repository.dart';

const bmiChartExplanation =
    'BMI = cân nặng (kg) / chiều dài hoặc chiều cao (m)², từ hai số đo cùng ngày. Trục ngang là tuổi (tháng), trục dọc là BMI (kg/m²). Đường xanh lá đậm nối BMI của bé.\n\nWHO 2006 có hai phần chuẩn riêng theo giới tính: trước 24 tháng dùng chiều dài nằm, từ 24 tháng dùng chiều cao đứng. Không nối qua điểm chuyển tiếp. Khi khác tư thế, chiều dài/chiều cao được chuẩn hóa 0,7 cm trước khi tính BMI; không cộng hoặc trừ 0,7 vào BMI.\n\nNăm đường chuẩn là −3, −2, 0, +2 và +3 SD. Màu nền hỗ trợ đối chiếu; kết luận dùng Z-score theo tuổi và giới tính, gồm cả ngưỡng +1 SD. Không dùng ngưỡng BMI người lớn. Chạm vào điểm để xem chi tiết.';

class BmiInsightSheet extends StatelessWidget {
  const BmiInsightSheet({
    required this.measurement,
    required this.birth,
    required this.zScore,
    required this.label,
    super.key,
  });
  final GrowthMeasurementDraft measurement;
  final DateTime? birth;
  final double? zScore;
  final String label;
  @override
  Widget build(BuildContext context) {
    final age = birth == null
        ? null
        : growthChartAgeMonths(birth!, measurement.measuredAt);
    final date = measurement.measuredAt;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .9,
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Quay lại',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    const Expanded(
                      child: Text(
                        'Vì sao có nhận xét này?',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                      height: 1.6,
                      color: Color(0xFF20365D),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Kết quả của bé',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'BMI: ${formatGrowthValue(measurement.value)} kg/m²\nNgày đo: ${date.day}/${date.month}/${date.year}\nTuổi: ${age == null ? 'Chưa xác định' : '${formatGrowthValue(age)} tháng'}\nZ-score WHO: ${zScore == null ? 'Chưa có dữ liệu' : formatGrowthValue(zScore!)}\n$label',
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Cách xác định BMI',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(bmiChartExplanation),
                        const SizedBox(height: 24),
                        const Text(
                          'Căn cứ đánh giá theo WHO',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Ngưỡng BMI theo tuổi: dưới −3 SD: rất gầy; từ −3 đến dưới −2: gầy; từ −2 đến +1: cân đối; trên +1 đến +2: nguy cơ thừa cân; trên +2 đến +3: thừa cân; trên +3: béo phì. Cần xem cùng diễn tiến tăng trưởng và tình trạng sức khỏe của bé.',
                        ),
                        const SizedBox(height: 24),
                        const SelectableText(
                          'WHO Child Growth Standards 2006 · Methods and development, chương 6–7\nhttps://www.who.int/tools/child-growth-standards/standards/body-mass-index-for-age-bmi-for-age',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
