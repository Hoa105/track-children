import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'growth_repository.dart' show formatGrowthValue;
import 'growth_visuals.dart';
import 'growth_weight_velocity_data.dart';
import 'growth_velocity_reference_scale.dart';

class GrowthVelocityInsightSheet extends StatelessWidget {
  const GrowthVelocityInsightSheet({
    required this.adviceMode,
    this.point,
    this.fromKg,
    this.toKg,
    this.previewExplanation,
    this.previewZ,
    this.comparison,
    super.key,
  });
  final bool adviceMode;
  final GrowthWeightVelocityPoint? point;
  final double? fromKg, toKg, previewZ;
  final String? previewExplanation, comparison;
  static const _ink = WeightChartColors.heroInk;
  static const _body = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 14,
    height: 1.6,
    color: WeightChartColors.axis,
  );
  String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';
  Widget _heading(String title) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'DancingScript',
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
      ),
    ),
  );
  Widget _note(String text, {bool blue = false}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: blue ? const Color(0xFFEAF3FB) : const Color(0xFFFFF9E9),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: 'DancingScript',
        fontSize: 21,
        height: 1.5,
        color: _ink,
      ),
    ),
  );
  Widget _row(String label, String value, {Color color = _ink}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: _body)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: _body.copyWith(fontWeight: FontWeight.w800, color: color),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = point;
    final first = p?.fromKg ?? fromKg, last = p?.toKg ?? toKg;
    final z = p?.hasWhoReference == true ? p?.zScore ?? previewZ : null;
    final advice =
        p?.advice.where((text) => text.trim().isNotEmpty).toSet().toList() ??
        <String>[];
    final explanation = p?.explanation ?? previewExplanation;
    final fact = p == null
        ? 'Chưa có đủ số đo cho kỳ đang xem.'
        : 'Trong kỳ ${_date(p.from)} – ${_date(p.to)}, cân nặng của bé ${p.grams < 0 ? 'giảm' : 'tăng'} ${formatGrowthValue(p.grams.abs())} g.';
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
                    icon: const Icon(Icons.chevron_left, color: _ink),
                  ),
                  Expanded(
                    child: Text(
                      adviceMode
                          ? 'Gợi ý cho ba mẹ'
                          : 'Vì sao có nhận xét này?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20, color: _ink),
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
                  p == null || p.intervalMonths == 0
                      ? 'Kỳ đo đang xem'
                      : 'Chu kỳ ${p.intervalMonths} tháng',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: WeightChartColors.positive,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (adviceMode) ...[
                        _note(explanation ?? fact),
                        const SizedBox(height: 24),
                        const Row(
                          children: [
                            GrowthAsset('overview-trend', size: 36),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Theo dõi',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (advice.isEmpty)
                          const Text(
                            'Chưa có gợi ý đã duyệt cho kỳ đo này.',
                            style: _body,
                          ),
                        for (final text in advice)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('•  ', style: _body),
                                Expanded(child: Text(text, style: _body)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
                        _note(
                          'Nội dung gắn với kỳ đo đang xem. Mức tăng cân giữa các kỳ có thể khác nhau; cần xem cùng diễn tiến cân nặng và chiều dài/chiều cao của bé.',
                          blue: true,
                        ),
                      ] else ...[
                        _heading('Kết quả của bé'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: WeightChartColors.frame),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              _row(
                                'Bắt đầu',
                                p == null ? 'Chưa có dữ liệu' : _date(p.from),
                              ),
                              const Divider(height: 1),
                              _row(
                                'Kết thúc',
                                p == null ? 'Chưa có dữ liệu' : _date(p.to),
                              ),
                              const Divider(height: 1),
                              _row(
                                'Cân nặng đầu kỳ',
                                first == null
                                    ? 'Chưa có dữ liệu'
                                    : '${formatGrowthValue(first)} kg',
                              ),
                              const Divider(height: 1),
                              _row(
                                'Cân nặng cuối kỳ',
                                last == null
                                    ? 'Chưa có dữ liệu'
                                    : '${formatGrowthValue(last)} kg',
                              ),
                              const Divider(height: 1),
                              _row(
                                'Mức thay đổi',
                                p == null
                                    ? 'Chưa có dữ liệu'
                                    : '${p.grams > 0 ? '+' : ''}${formatGrowthValue(p.grams)} g',
                                color: WeightChartColors.data,
                              ),
                              const Divider(height: 1),
                              _row(
                                'Z-score WHO',
                                z == null || !z.isFinite
                                    ? 'Chưa có dữ liệu'
                                    : z.toStringAsFixed(2),
                              ),
                              const Divider(height: 1),
                              _row(
                                'Đối chiếu',
                                p?.hasWhoReference == true
                                    ? 'Có tham chiếu WHO'
                                    : 'Chỉ ghi nhận',
                                color: p?.hasWhoReference == true
                                    ? WeightChartColors.positive
                                    : WeightChartColors.unknown,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _heading('Cách tính trong kỳ'),
                        Text(
                          first == null || last == null || p == null
                              ? 'Cần đủ số cân ở hai đầu kỳ để giải thích phép tính.'
                              : '(${formatGrowthValue(last)} - ${formatGrowthValue(first)}) × 1.000 = ${formatGrowthValue(p.grams)} g.',
                          style: _body,
                        ),
                        if (comparison != null) ...[
                          const SizedBox(height: 8),
                          Text(comparison!, style: _body),
                        ],
                        const SizedBox(height: 24),
                        _heading('Căn cứ đánh giá theo WHO'),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF5EE),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            explanation ??
                                (p?.hasWhoReference == true
                                    ? 'Kỳ đo khớp tham chiếu WHO 2009 theo giới tính và chu kỳ đã chọn. Dải màu và chênh lệch giữa các kỳ không tự xác định phân loại sức khỏe.'
                                    : 'Chỉ ghi nhận mức tăng — chưa có đối chiếu WHO phù hợp.'),
                            style: _body,
                          ),
                        ),
                        if (p?.hasWhoReference == true) ...[
                          const SizedBox(height: 20),
                          GrowthVelocityReferenceScale(
                            grams: p!.grams,
                            zScore: z,
                            values: p.referenceValues,
                          ),
                        ],
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
                              style: _body,
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: WeightChartColors.axis,
                            ),
                            onTap: () => showDialog<void>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text(
                                  'WHO Growth Velocity Standards 2009',
                                ),
                                content: const SelectableText(
                                  'https://www.who.int/tools/child-growth-standards/standards/weight-velocity',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c),
                                    child: const Text('Đóng'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: WeightChartColors.positive,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Đã hiểu'),
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
