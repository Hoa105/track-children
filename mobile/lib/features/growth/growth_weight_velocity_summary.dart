import 'package:flutter/material.dart';

import 'growth_repository.dart';
import 'growth_visuals.dart';
import 'growth_conclusion_explanation.dart';
import 'growth_weight_velocity_data.dart';

/// Supplied by a validated assessment, never generated from the shaded band.
class GrowthVelocityWhoResult {
  const GrowthVelocityWhoResult({
    required this.from,
    required this.to,
    required this.classification,
    required this.comparison,
    required this.explanation,
    required this.sourceUrl,
    required this.version,
    this.zScore,
  });
  final DateTime from, to;
  final double? zScore;
  final String classification, comparison, explanation, sourceUrl, version;
  bool matches(GrowthWeightVelocityPoint? point) =>
      point != null &&
      DateUtils.isSameDay(from, point.from) &&
      DateUtils.isSameDay(to, point.to) &&
      point.startMonth >= 2 &&
      point.startMonth < 12 &&
      [
        classification,
        comparison,
        explanation,
        version,
      ].every((v) => v.trim().isNotEmpty) &&
      Uri.tryParse(sourceUrl)?.scheme == 'https' &&
      const [
        'www.who.int',
        'cdn.who.int',
      ].contains(Uri.tryParse(sourceUrl)?.host);
}

/// Explicit review presentation for the existing mock intervals, not WHO scoring.
GrowthVelocityWhoResult? growthVelocityReviewFixture(
  GrowthRepository repository,
  GrowthWeightVelocityPoint? point,
) {
  if (repository is! MockGrowthRepository || point == null) return null;
  final score = repository.weightVelocityDisplayZScore(point);
  if (score == null) return null;
  return GrowthVelocityWhoResult(
    from: point.from,
    to: point.to,
    zScore: score,
    classification: 'Trong khoảng tham chiếu WHO',
    comparison:
        'Z-score vận tốc: ${score > 0 ? '+' : ''}${score.toStringAsFixed(2).replaceAll('.', ',')} SD.',
    explanation: 'Mức tăng cân của bé trong kỳ đo gần nhất phù hợp với khoảng tham chiếu được áp dụng.',
    sourceUrl: 'https://www.who.int/tools/child-growth-standards/standards/weight-velocity',
    version: 'WHO Weight velocity · chu kỳ 1 tháng',
  );
}

class GrowthVelocitySummary {
  GrowthVelocitySummary(this.points);
  final List<GrowthWeightVelocityPoint> points;
  GrowthWeightVelocityPoint? get latest => points.lastOrNull;
  GrowthWeightVelocityPoint? get previous =>
      points.length > 1 &&
          points[points.length - 2].startMonth + 1 == latest!.startMonth
      ? points[points.length - 2]
      : null;
  int? get delta =>
      previous == null ? null : latest!.grams.round() - previous!.grams.round();
  bool get oscillates {
    int? lastSign;
    for (var i = 1; i < points.length; i++) {
      if (points[i].startMonth != points[i - 1].startMonth + 1) {
        lastSign = null;
        continue;
      }
      final sign = (points[i].grams.round() - points[i - 1].grams.round()).sign;
      if (sign == 0) continue;
      if (lastSign != null && lastSign != sign) return true;
      lastSign = sign;
    }
    return false;
  }

  String get direction => latest == null
      ? 'Chưa đủ dữ liệu'
      : previous == null
      ? 'Chưa đủ dữ liệu nhận xét xu hướng'
      : oscillates
      ? 'Dao động qua các tháng'
      : delta == 0
      ? 'Ít thay đổi'
      : delta! > 0
      ? 'Tốc độ tăng so với tháng trước'
      : 'Tốc độ giảm so với tháng trước';
  String get comment {
    if (latest == null) {
      return 'Chưa đủ dữ liệu để tính tốc độ tăng cân trong khoảng tuổi đang xem.';
    }
    final grams = latest!.grams.round();
    final recorded = grams < 0
        ? 'Bé giảm ${grams.abs()} g'
        : grams == 0
        ? 'Cân nặng của bé không đổi'
        : 'Bé tăng $grams g';
    final comparison = delta == null
        ? '. Chưa có tháng liền trước để so sánh tốc độ.'
        : delta == 0
        ? ', bằng mức tăng của tháng trước.'
        : ', ${delta! > 0 ? 'nhiều' : 'ít'} hơn ${delta!.abs()} g so với tháng trước.';
    return '$recorded trong tháng gần nhất đang xem$comparison ${oscillates ? 'Mức tăng có dao động giữa các tháng. ' : ''}Ba mẹ hãy tiếp tục theo dõi các lần đo tiếp theo nhé!';
  }

  String get history => [
    for (var i = 0; i < points.length; i++)
      '${points[i].startMonth}–${points[i].startMonth + 1} tháng tuổi: ${growthVelocitySigned(points[i].grams.round())} g/tháng${i == 0 || points[i - 1].startMonth + 1 != points[i].startMonth
          ? ' (chưa có tháng liền trước để so sánh)'
          : points[i].grams.round() == points[i - 1].grams.round()
          ? ' (không đổi tốc độ)'
          : ' (${points[i].grams > points[i - 1].grams ? 'tăng' : 'giảm'} tốc độ ${(points[i].grams.round() - points[i - 1].grams.round()).abs()} g/tháng)'}.',
  ].join('\n');
}

String growthVelocitySigned(int value) => value > 0
    ? '+$value'
    : value < 0
    ? '−${value.abs()}'
    : '0';

class GrowthVelocityHighlights extends StatelessWidget {
  const GrowthVelocityHighlights({
    required this.summary,
    this.easyRead = false,
    super.key,
  });
  final GrowthVelocitySummary summary;
  final bool easyRead;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: .9,
            child: _note(
              title: 'T\u1ed1c \u0111\u1ed9 t\u0103ng c\u00e2n th\u00e1ng g\u1ea7n nh\u1ea5t \u0111ang xem',
              value: summary.latest == null
                  ? 'Ch\u01b0a \u0111\u1ee7 d\u1eef li\u1ec7u'
                  : '${growthVelocitySigned(summary.latest!.grams.round())} g/th\u00e1ng',
              detail: summary.latest == null
                  ? null
                  : '${summary.latest!.startMonth}\u2013${summary.latest!.startMonth + 1} th\u00e1ng tu\u1ed5i \u00b7 ${_date(summary.latest!.from)} \u2013 ${_date(summary.latest!.to)}',
              color: growthWeightOrange,
              angle: -.045,
            ),
          ),
        ),
        if (!easyRead)
          const Align(
            alignment: Alignment.center,
            child: GrowthAsset('weight-note-arrow', size: 52),
          )
        else
          const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: .9,
            child: _note(
              title: 'Thay \u0111\u1ed5i t\u1ed1c \u0111\u1ed9 so v\u1edbi th\u00e1ng li\u1ec1n tr\u01b0\u1edbc',
              value: summary.delta == null
                  ? 'Ch\u01b0a \u0111\u1ee7 d\u1eef li\u1ec7u so s\u00e1nh'
                  : '${growthVelocitySigned(summary.delta!)} g/th\u00e1ng',
              color: const Color(0xFFAE652B),
              angle: .035,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _note({
    required String title,
    required String value,
    required Color color,
    required double angle,
    String? detail,
  }) => Transform.rotate(
    angle: easyRead ? 0 : angle,
    child: CustomPaint(
      painter: const GrowthNotePaperPainter(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: easyRead ? 'Nunito' : 'DancingScript',
                fontSize: 18,
                height: 1.3,
                color: const Color(0xFF20365D),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontFamily: easyRead ? 'Nunito' : 'DancingScript',
                fontSize: easyRead ? 24 : 21,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail,
                style: TextStyle(
                  fontFamily: easyRead ? 'Nunito' : 'DancingScript',
                  fontSize: easyRead ? 18 : 13,
                  height: 1.4,
                  color: growthMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

class GrowthVelocityAssessment extends StatelessWidget {
  const GrowthVelocityAssessment({
    required this.summary,
    required this.readings,
    this.whoResult,
    this.easyRead = false,
    super.key,
  });
  final GrowthVelocitySummary summary;
  final List<GrowthMeasurementDraft> readings;
  final GrowthVelocityWhoResult? whoResult;
  final bool easyRead;
  TextStyle get _body => TextStyle(
    fontSize: easyRead ? 18 : 14,
    height: 1.5,
    color: const Color(0xFF4C6585),
  );
  TextStyle get _title => TextStyle(
    fontSize: easyRead ? 20 : 17,
    fontWeight: FontWeight.w800,
    color: const Color(0xFF20365D),
  );
  @override
  Widget build(BuildContext context) {
    final latest = summary.latest;
    final who = whoResult?.matches(latest) == true ? whoResult : null;
    GrowthMeasurementDraft? readingAt(DateTime? date) => date == null
        ? null
        : readings
              .where((r) => DateUtils.isSameDay(r.measuredAt, date))
              .lastOrNull;
    final from = readingAt(latest?.from), to = readingAt(latest?.to);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1E4),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const GrowthAsset('result-smile-weight', size: 48),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'T\u1ed1c \u0111\u1ed9 c\u00e2n n\u1eb7ng c\u1ee7a b\u00e9 th\u1ebf n\u00e0o?',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: easyRead ? 20 : 18,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      color: growthWeightOrange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _section(
              _assessmentContent(
                icon: const GrowthAsset('who', size: 26),
                title: who?.classification ?? 'Ch\u01b0a \u0111\u1ee7 c\u0103n c\u1ee9 ph\u00e2n lo\u1ea1i theo WHO',
                explanation: who?.explanation,
                caption:
                    '\u0110\u00e1nh gi\u00e1 t\u1ed1c \u0111\u1ed9 hi\u1ec7n t\u1ea1i${who?.zScore?.isFinite == true ? ' \u00b7 ${who!.zScore! > 0 ? '+' : ''}${who.zScore!.toStringAsFixed(2).replaceAll('.', ',')} SD' : ''}',
              ),
              const Color(0xFFFFE8D3),
            ),
            const SizedBox(height: 12),
            _section(
              _assessmentContent(
                icon: const GrowthAsset('overview-trend', size: 26),
                title: summary.direction,
                explanation: summary.previous == null
                    ? null
                    : summary.oscillates
                    ? 'M\u1ee9c t\u0103ng c\u00e2n c\u00f3 l\u00fac t\u0103ng, c\u00f3 l\u00fac gi\u1ea3m gi\u1eefa c\u00e1c th\u00e1ng li\u1ec1n nhau.'
                    : summary.delta == 0
                    ? 'M\u1ee9c t\u0103ng c\u00e2n g\u1ea7n nh\u1ea5t b\u1eb1ng th\u00e1ng li\u1ec1n tr\u01b0\u1edbc.'
                    : 'M\u1ee9c t\u0103ng c\u00e2n g\u1ea7n nh\u1ea5t ${summary.delta! > 0 ? 'cao h\u01a1n' : 'th\u1ea5p h\u01a1n'} th\u00e1ng li\u1ec1n tr\u01b0\u1edbc ${summary.delta!.abs()} g.',
                caption: 'Xu h\u01b0\u1edbng qua c\u00e1c th\u00e1ng',
              ),
              const Color(0xFFFFF1E4),
            ),
            const SizedBox(height: 24),
            Text('Nhận xét', style: _title),
            const SizedBox(height: 8),
            Text(summary.comment, style: _body),
            const SizedBox(height: 20),
            Material(
              color: const Color(0xFFFFFEFA),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    settings: const RouteSettings(
                      name: '/growth/weight-velocity-explanation',
                    ),
                    builder: (_) => GrowthConclusionExplanationScreen(
                      easyRead: easyRead,
                      introText: 'M\u1ed7i l\u1ea7n \u0111o gi\u00fap ba m\u1eb9 hi\u1ec3u nh\u1ecbp t\u0103ng c\u00e2n c\u1ee7a con. C\u00f9ng xem d\u1eef li\u1ec7u, c\u00e1ch t\u00ednh v\u00e0 c\u0103n c\u1ee9 cho nh\u1eadn x\u00e9t n\u00e0y nh\u00e9!',
                      sources: {
                        'WHO Weight velocity': who?.sourceUrl ?? 'https://www.who.int/tools/child-growth-standards/standards/weight-velocity',
                      },
                      sections: [
                        GrowthExplanationSection(
                          '1. Dữ liệu được sử dụng',
                          latest == null || from == null || to == null
                              ? 'Chưa đủ hai số đo để giải thích cách tính.'
                              : '${_date(latest.from)}: ${formatGrowthValue(from.value)} kg → ${_date(latest.to)}: ${formatGrowthValue(to.value)} kg. Khoảng đo: đúng 1 tháng, từ ${latest.startMonth} đến ${latest.startMonth + 1} tháng tuổi.',
                        ),
                        GrowthExplanationSection(
                          '2. Cách tính',
                          latest == null || from == null || to == null
                              ? 'Cần hai số đo và khoảng thời gian hợp lệ.'
                              : 'Mức thay đổi: (${formatGrowthValue(to.value)} − ${formatGrowthValue(from.value)}) × 1.000 = ${latest.grams.round()} g.\nTốc độ trung bình: ${latest.grams.round()} g ÷ 1 tháng = ${latest.grams.round()} g/tháng.${summary.delta == null ? '' : '\nThay đổi tốc độ: ${latest.grams.round()} − ${summary.previous!.grams.round()} = ${growthVelocitySigned(summary.delta!)} g/tháng. Đây là chênh lệch tốc độ giữa hai tháng.'}',
                        ),
                        GrowthExplanationSection(
                          '3. Xu hướng qua các tháng',
                          summary.points.isEmpty
                              ? 'Chưa đủ dữ liệu nhận xét xu hướng.'
                              : '${summary.history}\n${summary.direction}. So sánh tốc độ chỉ thực hiện giữa các tháng liền nhau; chiều hướng này không phải phân loại bất thường về y khoa.',
                        ),
                        GrowthExplanationSection(
                          '4. Căn cứ WHO',
                          who == null
                              ? 'Chưa có kết quả đối chiếu WHO hợp lệ cho tháng đang đánh giá. Dải tham chiếu trên biểu đồ không đủ để tự phân loại tốc độ tăng cân chậm, nhanh hay bất thường.'
                              : 'Chỉ số: tốc độ tăng cân, chu kỳ 1 tháng.\n${who.comparison}\nPhân loại: ${who.classification}. ${who.explanation}\nBộ chuẩn: ${who.version}\nNguồn: ${who.sourceUrl}',
                        ),
                      ],
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
                          'V\u00ec sao c\u00f3 k\u1ebft lu\u1eadn n\u00e0y?',
                          style: _title,
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
          ],
        ),
      ),
    );
  }

  Widget _assessmentContent({
    required Widget icon,
    required String title,
    required String caption,
    String? explanation,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: easyRead ? 19 : 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF20365D),
              ),
            ),
          ),
        ],
      ),
      if (explanation != null) ...[
        const SizedBox(height: 6),
        Text(explanation, style: _body),
      ],
      const SizedBox(height: 8),
      Text(
        caption,
        style: TextStyle(
          fontSize: easyRead ? 16 : 13,
          height: 1.4,
          color: const Color(0xFF74817A),
        ),
      ),
    ],
  );

  Widget _section(Widget child, Color color) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(6),
        topRight: Radius.circular(22),
        bottomLeft: Radius.circular(22),
        bottomRight: Radius.circular(6),
      ),
    ),
    child: child,
  );
}
