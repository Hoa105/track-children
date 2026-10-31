import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'growth_repository.dart';
import 'growth_velocity_reference_scale.dart';
import 'stature_velocity_data.dart';
import 'weight_chart_view.dart' show weightClassificationColor;

/// Same evidence-sheet structure as weight, with stature-specific WHO content.
class StatureInsightSheet extends StatelessWidget {
  const StatureInsightSheet({
    this.measurement,
    this.birth,
    this.zScore,
    this.label,
    this.period,
    this.interval,
    this.reference,
    super.key,
  });
  final GrowthMeasurementDraft? measurement;
  final DateTime? birth;
  final double? zScore;
  final String? label;
  final int? period;
  final StatureVelocityInterval? interval;
  final StatureVelocityReference? reference;
  bool get velocity => period != null;
  static const body = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 14,
    height: 1.6,
    color: WeightChartColors.axis,
  );
  String number(double n) =>
      formatGrowthValue(double.parse(n.toStringAsFixed(2)));
  String date(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Widget heading(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'DancingScript',
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: WeightChartColors.heroInk,
        ),
      ),
    ),
  );
  Widget row(String title, String value, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(title, style: body)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: body.copyWith(
              fontWeight: FontWeight.w800,
              color: color ?? WeightChartColors.heroInk,
            ),
          ),
        ),
      ],
    ),
  );
  Widget table(List<Widget> rows) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      border: Border.all(color: WeightChartColors.frame),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          rows[i],
        ],
      ],
    ),
  );
  Widget note(String text) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF5EE),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(text, style: body),
  );

  @override
  Widget build(BuildContext context) {
    final p = interval, m = measurement;
    final z = velocity ? p?.z : zScore;
    final valid = z != null && z.isFinite;
    final age = m == null || birth == null
        ? null
        : growthChartAgeMonths(birth!, m.measuredAt);
    final source = velocity
        ? 'https://www.who.int/tools/child-growth-standards/standards/length-velocity'
        : 'https://www.who.int/tools/child-growth-standards/standards/length-height-for-age';
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .92,
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                decoration: BoxDecoration(
                  color: WeightChartColors.frame,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Quay lại',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.chevron_left,
                      color: WeightChartColors.heroInk,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Vì sao có nhận xét này?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: WeightChartColors.heroInk,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      size: 20,
                      color: WeightChartColors.heroInk,
                    ),
                  ),
                ],
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: WeightChartColors.positive,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  velocity ? 'Chu kỳ $period tháng' : 'Theo tuổi',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    color: WeightChartColors.positive,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      heading('Kết quả của bé'),
                      if (velocity)
                        table([
                          row(
                            'Bắt đầu',
                            p == null
                                ? 'Chưa có dữ liệu'
                                : date(p.from.measuredAt),
                          ),
                          row(
                            'Kết thúc',
                            p == null
                                ? 'Chưa có dữ liệu'
                                : date(p.to.measuredAt),
                          ),
                          row(
                            'Chiều dài/chiều cao đầu kỳ',
                            p == null
                                ? 'Chưa có dữ liệu'
                                : '${number(p.from.value)}\u00A0cm',
                          ),
                          row(
                            'Chiều dài/chiều cao cuối kỳ',
                            p == null
                                ? 'Chưa có dữ liệu'
                                : '${number(p.to.value)}\u00A0cm',
                          ),
                          row(
                            'Mức thay đổi',
                            p == null
                                ? 'Chưa có dữ liệu'
                                : '${p.gain > 0 ? '+' : ''}${number(p.gain)}\u00A0cm',
                            color: StatureChartColors.data,
                          ),
                          row(
                            'Z-score WHO',
                            valid ? number(z) : 'Chưa có dữ liệu',
                          ),
                          row(
                            'Đối chiếu',
                            valid
                                ? 'Có tham chiếu WHO'
                                : p != null && p.gain < 0
                                ? 'Cần kiểm tra lại số đo'
                                : 'Chỉ ghi nhận',
                            color: valid
                                ? WeightChartColors.positive
                                : WeightChartColors.unknown,
                          ),
                        ])
                      else
                        table([
                          row(
                            'Chiều dài/chiều cao',
                            m == null
                                ? 'Chưa có dữ liệu'
                                : '${number(m.value)}\u00A0cm',
                            color: StatureChartColors.data,
                          ),
                          row(
                            'Tuổi',
                            age == null
                                ? 'Chưa có dữ liệu'
                                : '${number(age)} tháng',
                          ),
                          row(
                            'Cách đo',
                            m?.method == null
                                ? 'Chưa có dữ liệu'
                                : m!.method == GrowthMeasurementMethod.recumbent
                                ? 'Đo nằm'
                                : 'Đo đứng',
                          ),
                          row(
                            'Z-score WHO',
                            valid ? number(z) : 'Chưa có dữ liệu',
                          ),
                          row(
                            'Đánh giá',
                            valid
                                ? label ?? 'Chưa đủ dữ liệu'
                                : 'Chưa đủ dữ liệu',
                            color: valid
                                ? weightClassificationColor(label)
                                : WeightChartColors.unknown,
                          ),
                          row(
                            'Ngày đo',
                            m == null ? 'Chưa có dữ liệu' : date(m.measuredAt),
                          ),
                        ]),
                      if (velocity) ...[
                        const SizedBox(height: 24),
                        heading('Cách tính trong kỳ'),
                        Text(
                          p == null
                              ? 'Cần hai số đo cùng cách đo trong kỳ.'
                              : '(${number(p.to.value)} − ${number(p.from.value)}) = ${p.gain > 0 ? '+' : ''}${number(p.gain)}\u00A0cm trong $period tháng.',
                          style: body,
                        ),
                      ],
                      const SizedBox(height: 24),
                      heading('Căn cứ đánh giá theo WHO'),
                      note(
                        velocity
                            ? p != null && p.gain < 0
                                  ? 'Số đo cuối kỳ thấp hơn đầu kỳ. Hãy kiểm tra cách đo và đo lại; không tính Z-score từ mức tăng chiều dài âm.'
                                  : valid
                                  ? 'Kỳ đo có tham chiếu WHO 2009 theo giới tính và chu kỳ $period tháng. Z-score mô tả vị trí mức tăng trong phân bố tham chiếu. Không suy ra nhãn dinh dưỡng từ một kỳ đo.'
                                  : 'Chỉ ghi nhận mức tăng — chưa có đối chiếu WHO phù hợp.'
                            : valid
                            ? 'Z-score chiều dài/chiều cao theo tuổi: ${number(z)} · $label. Nhãn mô tả riêng chỉ số theo tuổi, không kết luận sức khỏe tổng thể.'
                            : 'Chưa có Z-score hợp lệ cho lần đo này. Cần tuổi, giới tính, cách đo và kết quả đối chiếu phù hợp.',
                      ),
                      if (velocity && p != null && p.gain >= 0) ...[
                        const SizedBox(height: 20),
                        GrowthVelocityReferenceScale(
                          grams: p.gain,
                          zScore: p.z,
                          unit: 'cm',
                          metricName: 'chiều dài/chiều cao',
                          values: p.row == null
                              ? const {}
                              : {
                                  for (final sd in [-3, -2, 0, 2, 3])
                                    sd: p.row!.sd[sd + 3],
                                },
                        ),
                      ],
                      if (!velocity && valid) ...[
                        const SizedBox(height: 20),
                        _StatureAgeDistribution(z: z, label: label ?? ''),
                      ],
                      const SizedBox(height: 24),
                      heading('Chuẩn đối chiếu'),
                      Text(
                        velocity
                            ? 'WHO 2009 cung cấp mức tăng chiều dài nằm cho kỳ 2, 3, 4 và 6 tháng, từ 0 đến 24 tháng, theo giới tính${reference == null ? '' : ': ${reference!.sexLabel}'}. Mỗi kỳ có bảng riêng; không chia mức tăng kỳ dài để đối chiếu kỳ ngắn.'
                            : 'WHO 2006: chiều dài nằm theo tuổi trước 24 tháng; chiều cao đứng theo tuổi từ 24 đến 60 tháng. Hai phần đường chuẩn tách tại mốc chuyển tiếp, chênh 0,7 cm.',
                        style: body,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        velocity
                            ? 'Hai lần đo được ghép theo mốc tuổi, với sai lệch cho phép ±3 ngày trước 6 tháng, ±5 ngày từ 6 đến trước 12 tháng và ±7 ngày từ 12 đến 24 tháng. Ngoài phạm vi chuẩn chỉ ghi nhận số liệu. Luôn xem cùng các kỳ trước và chiều dài/chiều cao theo tuổi.'
                            : 'Số đo khác tư thế được quy đổi: cộng 0,7 cm khi đo đứng trước 24 tháng; trừ 0,7 cm khi đo nằm từ 24 tháng. Số đo hiển thị trong bảng là số đo gốc đã ghi nhận. Cần xem cùng các lần đo trước và tình trạng sức khỏe của bé.',
                        style: body,
                      ),
                      const SizedBox(height: 20),
                      Material(
                        color: const Color(0xFFEAF3FB),
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          leading: const Icon(
                            Icons.info_outline,
                            color: WeightChartColors.axis,
                          ),
                          title: const Text(
                            'Xem nguồn tiêu chuẩn WHO',
                            style: body,
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: WeightChartColors.axis,
                          ),
                          onTap: () => showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(
                                velocity
                                    ? 'WHO Growth Velocity Standards 2009'
                                    : 'WHO Child Growth Standards 2006',
                              ),
                              content: SelectableText(source),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Đóng'),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _StatureAgeDistribution extends StatelessWidget {
  const _StatureAgeDistribution({required this.z, required this.label});
  final double z;
  final String label;
  @override
  Widget build(BuildContext context) {
    const cuts = [-3.5, -3.0, -2.0, 3.0, 3.5];
    const colors = [
      Color(0xFFE65353),
      Color(0xFFD58A20),
      Color(0xFF23B56B),
      Color(0xFFD58A20),
    ];
    const labels = ['Rất thấp', 'Thấp', 'Phù hợp', 'Rất cao'];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Vị trí chiều dài/chiều cao của bé',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              color: WeightChartColors.heroInk,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Z-score: ${formatGrowthValue(z)} · $label',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              color: StatureChartColors.data,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final width = c.maxWidth - 24;
              double x(double value) => 12 + (value + 3.5) / 7 * width;
              return Semantics(
                label: 'Z-score ${formatGrowthValue(z)}: $label',
                child: SizedBox(
                  height: 68,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 12,
                        right: 12,
                        top: 12,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            children: [
                              for (var i = 0; i < 4; i++)
                                Expanded(
                                  flex: ((cuts[i + 1] - cuts[i]) * 10).round(),
                                  child: Container(
                                    height: 18,
                                    color: colors[i],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      for (final tick in [-3, -2, 0, 2, 3])
                        Positioned(
                          left: x(tick.toDouble()) - 14,
                          top: 38,
                          width: 28,
                          child: Text(
                            tick > 0 ? '+$tick' : '$tick',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: WeightChartColors.axis,
                            ),
                          ),
                        ),
                      Positioned(
                        left: x(z.clamp(-3.5, 3.5)) - 8,
                        top: 12,
                        child: Container(
                          width: 16,
                          height: 18,
                          decoration: BoxDecoration(
                            color: StatureChartColors.data,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
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
              for (var i = 0; i < 4; i++)
                Text(
                  '● ${labels[i]}',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    color: colors[i],
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          if (z.abs() > 3.5)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Vị trí vượt ngoài thang hiển thị.',
                style: StatureInsightSheet.body,
              ),
            ),
        ],
      ),
    );
  }
}
