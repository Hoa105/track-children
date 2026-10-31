import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'growth_repository.dart' show formatGrowthValue;
import 'growth_weight_velocity_data.dart';

TextSpan growthVelocityTooltip(
  GrowthWeightVelocityPoint point, {
  double? previewZ,
  bool detailed = true,
}) {
  String date(DateTime d) => '${d.day}/${d.month}/${d.year}';
  String kg(double? value) =>
      value == null ? 'Chưa có dữ liệu' : '${formatGrowthValue(value)} kg';
  final z = point.hasWhoReference ? point.zScore ?? previewZ : null;
  final reason = switch (point.referenceReason) {
    'OUT_OF_SCOPE_AGE' => 'Ngoài phạm vi tuổi tham chiếu WHO',
    'MISSING_REFERENCE_FILE' => 'Chưa có bảng tham chiếu',
    'REFERENCE_NOT_VERIFIED' => 'Bảng tham chiếu chưa được xác minh',
    _ => 'Kỳ đo chưa khớp bảng WHO đang chọn',
  };
  return TextSpan(
    style: const TextStyle(
      fontFamily: 'Nunito',
      fontSize: 12,
      height: 1.45,
      color: WeightChartColors.heroInk,
    ),
    children: [
      TextSpan(
        text:
            '${point.grams >= 0 ? 'Tăng' : 'Giảm'} ${formatGrowthValue(point.grams.abs())} g\n',
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: WeightChartColors.data,
        ),
      ),
      if (detailed)
        TextSpan(
          text: '${date(point.from)} → ${date(point.to)}\n',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      if (detailed)
        TextSpan(
          text: 'Đầu kỳ: ${kg(point.fromKg)}\nCuối kỳ: ${kg(point.toKg)}\n',
        ),
      if (detailed && point.hasWhoReference)
        TextSpan(text: 'Chu kỳ: ${point.intervalMonths} tháng\n'),
      if (detailed && point.elapsedDays != null)
        TextSpan(text: 'Khoảng đo: ${point.elapsedDays} ngày\n'),
      TextSpan(
        text: point.hasWhoReference ? 'Có đối chiếu WHO' : 'Chỉ ghi nhận',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: point.hasWhoReference
              ? WeightChartColors.positive
              : WeightChartColors.unknown,
        ),
      ),
      if (detailed && !point.hasWhoReference) TextSpan(text: '\n$reason'),
      if (z != null && z.isFinite)
        TextSpan(
          text: '\nZ-score vận tốc: ${formatGrowthValue(z)}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
    ],
  );
}
