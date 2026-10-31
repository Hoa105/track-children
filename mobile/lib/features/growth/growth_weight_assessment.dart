import 'package:flutter/material.dart';

import 'growth_models.dart';
import 'growth_visuals.dart';
import 'growth_conclusion_explanation.dart';
import 'growth_conclusion_evidence.dart';
import 'growth_weight_insight_sheet.dart';
import '../../app_colors.dart';

/// Presentation fixture for review, consistent with the current mock badges.
/// This widget does not calculate a nutritional assessment or child Z-score.
class GrowthWeightAssessment extends StatelessWidget {
  const GrowthWeightAssessment({
    required this.weight,
    required this.statureLabel,
    this.easyRead = false,
    this.assessment,
    this.ageMonths,
    this.sexLabel,
    this.measuredAt,
    this.statureMeasurement,
    this.overviewOnly = false,
    super.key,
  });
  final double weight;
  final String statureLabel;
  final bool easyRead;
  final GrowthWeightAssessmentData? assessment;
  final double? ageMonths;
  final String? sexLabel;
  final DateTime? measuredAt;
  final GrowthMeasurementDraft? statureMeasurement;
  final bool overviewOnly;

  bool get _inScope =>
      ageMonths != null &&
      ageMonths!.isFinite &&
      ageMonths! >= 0 &&
      ageMonths! <= 60;
  bool get _outside =>
      ageMonths != null &&
      (!ageMonths!.isFinite || ageMonths! < 0 || ageMonths! > 60);
  GrowthIndexAssessment? _valid(GrowthIndexAssessment? value) =>
      _inScope && sexLabel != null && value?.isValid == true ? value : null;

  void _openInsight(BuildContext context, bool advice) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GrowthWeightInsightSheet(
        adviceMode: advice,
        weight: weight,
        statureLabel: statureLabel,
        wfa: _valid(assessment?.wfa),
        wflh: _valid(assessment?.wflh),
        ageMonths: ageMonths,
        measuredAt: measuredAt,
        stature: DateUtils.isSameDay(measuredAt, statureMeasurement?.measuredAt)
            ? statureMeasurement
            : null,
      ),
    );
  }

  Widget _overview(BuildContext context) {
    final wfa = _valid(assessment?.wfa), wflh = _valid(assessment?.wflh);
    final selected = wflh ?? wfa;
    final parts = <String>[
      if (wfa != null &&
          wflh != null &&
          wfa.zScore < -2 &&
          wfa.overview?.isNotEmpty == true)
        wfa.overview!,
      if (selected?.overview?.isNotEmpty == true)
        selected!.overview!
      else if (selected != null)
        selected.explanation,
      ...?selected?.advice.where((text) => text.trim().isNotEmpty),
    ];
    final summary = parts.isEmpty
        ? 'Chưa đủ dữ liệu đánh giá'
        : parts.toSet().join('\n\n');
    Widget action(String title, String subtitle, String asset, bool advice) =>
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Material(
            color: const Color(0xFFFFFEFA),
            borderRadius: BorderRadius.circular(18),
            child: ListTile(
              onTap: () => _openInsight(context, advice),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              leading: GrowthAsset(asset, size: 36),
              title: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF20365D),
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF4C6585),
                  ),
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: WeightChartColors.axis,
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5E9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const GrowthAsset('result-smile', size: 48),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Cân nặng của bé thế nào?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: growthGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            summary,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF4C6585),
            ),
          ),
          const SizedBox(height: 8),
          action(
            'Vì sao có nhận xét này',
            'Kết quả của bé và căn cứ đánh giá WHO',
            'lightbulb',
            false,
          ),
          action(
            'Gợi ý cho ba mẹ',
            'Xem gợi ý theo từng chỉ số',
            'heart',
            true,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => overviewOnly
      ? _overview(context)
      : Container(
          decoration: BoxDecoration(
            color: overviewOnly ? Colors.white : const Color(0xFFFFF1E4),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!overviewOnly)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      const GrowthAsset('result-smile-weight', size: 48),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Cân nặng của bé thế nào?',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: easyRead ? 20 : 18,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF9A4D1D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_outside)
                      Text(
                        'Ngo\u00e0i \u0111\u1ed9 tu\u1ed5i \u00e1p d\u1ee5ng WHO (0\u201360 th\u00e1ng). Kh\u00f4ng s\u1eed d\u1ee5ng b\u1ea3ng chu\u1ea9n n\u00e0y \u0111\u1ec3 \u0111\u00e1nh gi\u00e1.',
                        style: _body,
                      ),
                    if (!overviewOnly) ...[
                      _index('WFA', 'Theo tu\u1ed5i', _valid(assessment?.wfa)),
                      const SizedBox(height: 12),
                      _index(
                        'WFLH',
                        'Theo $statureLabel',
                        _valid(assessment?.wflh),
                      ),
                      const SizedBox(height: 18),
                    ],
                    Text(
                      overviewOnly
                          ? 'Nhận xét tổng quan'
                          : 'Nh\u1eadn x\u00e9t',
                      style: _heading,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _valid(assessment?.wfa) != null &&
                              _valid(assessment?.wflh) != null &&
                              assessment?.combinedSummary?.isNotEmpty == true
                          ? assessment!.combinedSummary!
                          : 'Ch\u01b0a \u0111\u1ee7 d\u1eef li\u1ec7u \u0111\u00e1nh gi\u00e1',
                      style: _body,
                    ),
                    const SizedBox(height: 18),
                    Material(
                      color: const Color(0xFFFFFEFA),
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            settings: const RouteSettings(
                              name: '/growth/weight-explanation',
                            ),
                            builder: (_) => GrowthConclusionExplanationScreen(
                              easyRead: easyRead,
                              evidence: GrowthConclusionEvidence(
                                ageMonths: ageMonths,
                                sex: sexLabel,
                                weight: weight,
                                measuredAt: measuredAt,
                                statureLabel: statureLabel,
                                stature:
                                    DateUtils.isSameDay(
                                      measuredAt,
                                      statureMeasurement?.measuredAt,
                                    )
                                    ? statureMeasurement?.value
                                    : null,
                                method:
                                    DateUtils.isSameDay(
                                          measuredAt,
                                          statureMeasurement?.measuredAt,
                                        ) &&
                                        statureMeasurement?.method != null
                                    ? statureMeasurement!.method ==
                                              GrowthMeasurementMethod.recumbent
                                          ? 'Đo nằm'
                                          : 'Đo đứng'
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const GrowthAsset('lightbulb', size: 26),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  overviewOnly ? 'Vì sao có nhận xét này' : 'V\u00ec sao c\u00f3 k\u1ebft lu\u1eadn n\u00e0y?',
                                  style: TextStyle(
                                    fontSize: easyRead ? 19 : 16,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF20365D),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFF20365D),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (overviewOnly) ...[
                      const SizedBox(height: 18),
                      Text('Gợi ý cho cha mẹ', style: _heading),
                      const SizedBox(height: 6),
                      Text(
                        {
                              ...?_valid(assessment?.wfa)?.advice,
                              ...?_valid(assessment?.wflh)?.advice,
                            }.isEmpty
                            ? 'Chưa có gợi ý cho lần đo này.'
                            : {
                                ...?_valid(assessment?.wfa)?.advice,
                                ...?_valid(assessment?.wflh)?.advice,
                              }.join('\n\n'),
                        style: _body,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
  TextStyle get _body => TextStyle(
    fontSize: easyRead ? 18 : 14,
    height: 1.5,
    color: const Color(0xFF4C6585),
  );
  TextStyle get _heading => TextStyle(
    fontSize: easyRead ? 19 : 16,
    fontWeight: FontWeight.w800,
    color: const Color(0xFF20365D),
  );

  Widget _index(
    String code,
    String title,
    GrowthIndexAssessment? data,
  ) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: code == 'WFA' ? const Color(0xFFFFE8D3) : const Color(0xFFFFF5E9),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(6),
        topRight: Radius.circular(22),
        bottomLeft: Radius.circular(22),
        bottomRight: Radius.circular(6),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GrowthAsset(
              code == 'WFA' ? 'overview-trend' : 'overview-height',
              size: 26,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                data?.classification ?? 'Ch\u01b0a \u0111\u1ee7 d\u1eef li\u1ec7u \u0111\u00e1nh gi\u00e1',
                style: _heading,
              ),
            ),
          ],
        ),
        if (data != null) ...[
          const SizedBox(height: 6),
          Text(data.explanation, style: _body),
          const SizedBox(height: 8),
          Text(
            '$title \u00b7 ${data.zScore > 0 ? '+' : ''}${data.zScore.toStringAsFixed(2).replaceAll('.', ',')} SD',
            style: TextStyle(
              fontSize: easyRead ? 16 : 13,
              height: 1.4,
              color: const Color(0xFF74817A),
            ),
          ),
        ] else ...[
          const SizedBox(height: 6),
          Text(title, style: _body),
        ],
      ],
    ),
  );
}
