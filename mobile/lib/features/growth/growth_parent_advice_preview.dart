import 'package:flutter/material.dart';
import '../../app_colors.dart';
import 'growth_visuals.dart';

/// Static design preview requested for the parent advice sheet.
class GrowthParentAdvicePreview extends StatelessWidget {
  const GrowthParentAdvicePreview({super.key});

  Widget _section(String title, IconData icon, Color color, List<String> items) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 42, height: 42,
              decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 30)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontFamily: 'Nunito', fontSize: 21,
              fontWeight: FontWeight.w800, color: WeightChartColors.heroInk))),
          ]),
          const SizedBox(height: 14),
          for (final item in items) Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('•', style: TextStyle(color: WeightChartColors.axis, fontSize: 18)),
              const SizedBox(width: 12),
              Expanded(child: Text(item, style: const TextStyle(fontFamily: 'Nunito', fontSize: 15,
                height: 1.65, color: WeightChartColors.axis))),
            ])),
        ]),
      );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 26, 20, 28),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Nội dung minh họa', style: TextStyle(fontSize: 12, color: WeightChartColors.muted)),
      const SizedBox(height: 10),
      Transform.rotate(angle: -.035, child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: const Color(0xFFFFF8E2), borderRadius: BorderRadius.circular(18)),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Bé đang có cân nặng phù hợp với tuổi.\nHãy duy trì chế độ dinh dưỡng và vận động như hiện tại nhé!',
            style: TextStyle(fontFamily: 'DancingScript', fontSize: 22, height: 1.5, color: WeightChartColors.heroInk)),
          Align(alignment: Alignment.centerRight, child: GrowthAsset('heart', size: 32)),
        ]))),
      const SizedBox(height: 12),
      _section('Dinh dưỡng', Icons.ramen_dining_rounded, const Color(0xFFE69732), const [
        'Duy trì chế độ ăn đa dạng, đủ các nhóm chất và phù hợp với độ tuổi của bé.',
        'Ưu tiên thực phẩm tươi, ít chế biến sẵn, hạn chế đồ ngọt.',
      ]),
      const Divider(height: 1, color: WeightChartColors.frame),
      _section('Vận động', Icons.directions_run_rounded, const Color(0xFF29A879), const [
        'Khuyến khích bé vận động, chơi ngoài trời mỗi ngày.',
        'Tạo cơ hội cho bé bò, đi, chạy, leo trèo phù hợp với độ tuổi.',
      ]),
      const Divider(height: 1, color: WeightChartColors.frame),
      _section('Theo dõi', Icons.bar_chart_rounded, const Color(0xFF29A879), const [
        'Tiếp tục theo dõi cân nặng định kỳ theo khuyến nghị.',
        'Nếu có dấu hiệu tăng cân quá nhanh hoặc chậm, hãy tham khảo ý kiến chuyên gia.',
      ]),
      Transform.rotate(angle: -.025, child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFFEEF5FE), borderRadius: BorderRadius.circular(20)),
        child: const Row(children: [
          GrowthAsset('lightbulb', size: 38), SizedBox(width: 12),
          Expanded(child: Text('Mỗi trẻ có tốc độ tăng trưởng khác nhau. Hãy cùng theo dõi sự lớn lên của con qua từng lần đo nhé!',
            style: TextStyle(fontFamily: 'DancingScript', fontSize: 21, height: 1.5, color: WeightChartColors.heroInk))),
        ]))),
    ]),
  );
}
