import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'growth_models.dart';
import 'growth_parent_advice_preview.dart';
import 'growth_classification_labels.dart';
import 'growth_repository.dart' show formatGrowthValue;
import 'weight_chart_view.dart' show weightClassificationColor;

Color _assessmentLabelColor(GrowthIndexAssessment? result, bool byAge) {
  if (result == null || !result.zScore.isFinite) {
    return WeightChartColors.unknown;
  }
  final z = result.zScore;
  if (z < -3 || (!byAge && z > 3)) return const Color(0xFFE65353);
  if (z < -2 || z > (byAge ? 2 : 1)) return const Color(0xFFD58A20);
  return const Color(0xFF23B56B);
}

String _assessmentLabel(GrowthIndexAssessment? result, bool byAge) {
  if (result == null || !result.zScore.isFinite) return 'Chưa đủ dữ liệu';
  final z = result.zScore;
  final code = byAge
      ? (z < -3
            ? 'SEVERE_UNDERWEIGHT'
            : z < -2
            ? 'UNDERWEIGHT'
            : z <= 2
            ? 'WITHIN_RANGE'
            : 'HIGH_WFA')
      : (z < -3
            ? 'SEVERE_WASTING'
            : z < -2
            ? 'WASTING'
            : z <= 1
            ? 'WITHIN_RANGE'
            : z <= 2
            ? 'RISK_OVERWEIGHT'
            : z <= 3
            ? 'OVERWEIGHT'
            : 'OBESITY');
  return growthClassificationLabel(byAge ? 'WFA' : 'WFL', code)!;
}

/// Presentation only: use the selected assessment's explanation and approved advice.
class GrowthWeightInsightSheet extends StatelessWidget {
  const GrowthWeightInsightSheet({
    super.key,
    required this.adviceMode,
    required this.weight,
    required this.statureLabel,
    this.wfa,
    this.wflh,
    this.ageMonths,
    this.measuredAt,
    this.stature,
  });
  final bool adviceMode;
  final double weight;
  final String statureLabel;
  final GrowthIndexAssessment? wfa, wflh;
  final double? ageMonths;
  final DateTime? measuredAt;
  final GrowthMeasurementDraft? stature;

  Widget _note(String text, {bool blue = false}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: blue ? const Color(0xFFEAF3FB) : const Color(0xFFFFF9E9),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: 'DancingScript',
        fontSize: 20,
        height: 1.5,
        color: WeightChartColors.heroInk,
      ),
    ),
  );
  Widget _heading(String text) => Align(
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

  Widget _row(String name, String value, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            name,
            style: const TextStyle(color: WeightChartColors.axis),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color ?? WeightChartColors.heroInk,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _content(
    BuildContext context,
    GrowthIndexAssessment? result,
    bool byAge,
  ) {
    if (adviceMode) return const GrowthParentAdvicePreview();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...[
            _heading('Kết quả của bé'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                border: Border.all(color: WeightChartColors.frame),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _row('Cân nặng', '${formatGrowthValue(weight)} kg'),
                  const Divider(height: 1),
                  _row(
                    'Tuổi',
                    ageMonths == null
                        ? 'Chưa có dữ liệu'
                        : '${formatGrowthValue(ageMonths!)} tháng',
                  ),
                  const Divider(height: 1),
                  if (!byAge) ...[
                    _row(
                      'Chiều dài/chiều cao',
                      stature == null
                          ? 'Chưa có số đo cùng ngày'
                          : '${formatGrowthValue(stature!.value)} cm',
                    ),
                    const Divider(height: 1),
                  ],
                  _row(
                    'Z-score WHO',
                    result == null
                        ? 'Chưa có dữ liệu'
                        : result.zScore.toStringAsFixed(2),
                  ),
                  const Divider(height: 1),
                  _row(
                    'Đánh giá',
                    _assessmentLabel(result, byAge),
                    color: _assessmentLabelColor(result, byAge),
                  ),
                  if (measuredAt != null) ...[
                    const Divider(height: 1),
                    _row(
                      'Ngày đo',
                      '${measuredAt!.day}/${measuredAt!.month}/${measuredAt!.year}',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            _heading('Căn cứ đánh giá theo WHO'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: weightClassificationColor(result?.classification)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                result?.explanation ?? 'Chưa có kết quả tính hợp lệ; không xác định phân loại từ vị trí trên biểu đồ.',
                style: const TextStyle(
                  color: WeightChartColors.heroInk,
                  height: 1.7,
                ),
              ),
            ),
            if (result != null && result.zScore.isFinite) ...[
              const SizedBox(height: 20),
              _ZScoreDistribution(result: result, byAge: byAge),
            ],
            const SizedBox(height: 20),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              tileColor: const Color(0xFFEAF3FB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              leading: const Icon(
                Icons.info_outline,
                color: WeightChartColors.axis,
              ),
              title: const Text(
                'Xem nguồn tiêu chuẩn WHO',
                style: TextStyle(color: WeightChartColors.axis),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: WeightChartColors.axis,
              ),
              onTap: () => showDialog<void>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('WHO Child Growth Standards'),
                  content: SelectableText(
                    'WHO 2006 · ${byAge ? 'Weight-for-age' : 'Weight-for-length/height'}\nhttps://www.who.int/tools/child-growth-standards/standards/${byAge ? 'weight-for-age' : 'weight-for-length-height'}',
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
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: SizedBox(
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
              TabBar(
                labelColor: WeightChartColors.positive,
                unselectedLabelColor: WeightChartColors.axis,
                indicatorColor: WeightChartColors.positive,
                tabs: [
                  const Tab(text: 'Theo tuổi'),
                  Tab(text: 'Theo $statureLabel'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _content(context, wfa, true),
                    _content(context, wflh, false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The scale visualizes the existing assessment; it does not classify the child.
class _ZScoreDistribution extends StatelessWidget {
  const _ZScoreDistribution({required this.result, required this.byAge});
  final GrowthIndexAssessment result;
  final bool byAge;

  @override
  Widget build(BuildContext context) {
    final z = result.zScore;
    final clipped = z.clamp(-3.5, 3.5);
    final cuts = byAge
        ? [-3.5, -3.0, -2.0, 2.0, 3.5]
        : [-3.5, -3.0, -2.0, 1.0, 2.0, 3.0, 3.5];
    final labels = byAge
        ? ['Rất nhẹ cân', 'Nhẹ cân', 'Phù hợp', 'Nặng cân']
        : [
            'Rất gầy',
            'Gầy',
            'Cân đối',
            'Nguy cơ thừa cân',
            'Thừa cân',
            'Béo phì',
          ];
    final colors = byAge
        ? [
            const Color(0xFFE65353),
            const Color(0xFFD58A20),
            const Color(0xFF23B56B),
            const Color(0xFFD58A20),
          ]
        : [
            const Color(0xFFE65353),
            const Color(0xFFD58A20),
            const Color(0xFF23B56B),
            const Color(0xFFD58A20),
            const Color(0xFFD58A20),
            const Color(0xFFE65353),
          ];
    final color = _assessmentLabelColor(result, byAge);
    return Semantics(
      label: 'Vị trí Z-score ${z.toStringAsFixed(2)}: ${result.classification}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: WeightChartColors.frame),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Vị trí Z-score của bé',
              style: const TextStyle(
                color: WeightChartColors.heroInk,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment((clipped / 3.5), 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${z < -3.5 ? '← ' : ''}${z.toStringAsFixed(2)}${z > 3.5 ? ' →' : ''}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                double x(double value) => (value + 3.5) / 7 * width;
                return SizedBox(
                  height: 66,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: 18,
                        left: 0,
                        right: 0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            children: [
                              for (var i = 0; i < labels.length; i++)
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
                      for (var tick = -3; tick <= 3; tick++) ...[
                        Positioned(
                          left: x(tick.toDouble()),
                          top: 16,
                          child: Container(
                            width: 1,
                            height: tick == 0 ? 28 : 24,
                            color: WeightChartColors.axis.withValues(
                              alpha: tick == 0 ? .45 : .18,
                            ),
                          ),
                        ),
                        Positioned(
                          left: x(tick.toDouble()) - 14,
                          top: 44,
                          width: 28,
                          child: Text(
                            tick > 0 ? '+$tick' : '$tick',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: tick == 0
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: tick == 0
                                  ? WeightChartColors.heroInk
                                  : WeightChartColors.axis,
                            ),
                          ),
                        ),
                      ],
                      Positioned(
                        left: x(clipped) - 1,
                        top: 0,
                        child: Container(width: 2, height: 40, color: color),
                      ),
                      Positioned(
                        left: x(clipped) - 10,
                        top: 17,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: .25),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (var i = 0; i < labels.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 3,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 8, color: colors[i]),
                        const SizedBox(width: 5),
                        Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors[i],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (z < -3.5 || z > 3.5)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Kết quả nằm ngoài phần thang đang hiển thị.',
                  style: TextStyle(
                    fontSize: 12,
                    color: WeightChartColors.muted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
