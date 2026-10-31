import 'package:flutter/material.dart';

import 'growth_repository.dart';
import 'growth_weight_velocity_header.dart';
import 'growth_visuals.dart';
import 'growth_velocity_insight_sheet.dart';
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
  GrowthVelocitySummary(List<GrowthWeightVelocityPoint> points)
    : points = [...points]
        ..sort((a, b) {
          final end = a.to.compareTo(b.to);
          return end == 0 ? a.from.compareTo(b.from) : end;
        });
  final List<GrowthWeightVelocityPoint> points;
  GrowthWeightVelocityPoint? get latest => points.lastOrNull;
  GrowthWeightVelocityPoint? get previous => _previousFor(latest);
  GrowthWeightVelocityPoint? _previousFor(GrowthWeightVelocityPoint? current) {
    if (current == null ||
        !current.hasWhoReference ||
        current.intervalMonths <= 0)
      return null;
    // The two neonatal rows have distinct durations, so do not compare them.
    if (current.intervalMonths == 1 && current.startMonth < 2) return null;
    for (final point in points.reversed) {
      if (point.hasWhoReference &&
          point.intervalMonths == current.intervalMonths &&
          !(point.intervalMonths == 1 && point.startMonth < 2) &&
          DateUtils.isSameDay(point.to, current.from))
        return point;
    }
    return null;
  }

  int? get delta =>
      previous == null ? null : (latest!.grams - previous!.grams).round();
  bool get oscillates {
    final signs = <GrowthWeightVelocityPoint, int>{};
    for (final point in points) {
      final previous = _previousFor(point);
      if (previous == null) continue;
      final sign = (point.grams - previous.grams).sign.toInt();
      final lastSign = signs[previous];
      if (sign != 0 && lastSign != null && lastSign != sign) return true;
      if (sign != 0 || lastSign != null)
        signs[point] = sign == 0 ? lastSign! : sign;
    }
    return false;
  }

  String get direction => latest == null
      ? 'Chưa đủ dữ liệu'
      : previous == null
      ? 'Chưa đủ dữ liệu nhận xét xu hướng'
      : oscillates
      ? 'Dao động qua các kỳ'
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
        ? '. Chưa có kỳ liền trước cùng độ dài để so sánh.'
        : delta == 0
        ? ', bằng mức tăng của kỳ trước.'
        : ', ${delta! > 0 ? 'nhiều' : 'ít'} hơn ${delta!.abs()} g so với kỳ trước.';
    return '$recorded trong kỳ gần nhất đang xem$comparison ${oscillates ? 'Mức tăng có dao động giữa các kỳ. ' : ''}Ba mẹ hãy tiếp tục theo dõi các lần đo tiếp theo nhé!';
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
  Widget build(BuildContext context) => GrowthWeightVelocityHeader(
    grams: summary.latest?.grams.round(),
    delta: summary.delta,
    easyRead: easyRead,
    recordingOnly: summary.latest != null && !summary.latest!.hasWhoReference,
    period: summary.latest?.intervalMonths ?? 1,
  );
}

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
    fontSize: easyRead ? 20 : 16,
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
    void openInsight(bool adviceMode) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GrowthVelocityInsightSheet(
        adviceMode: adviceMode,
        point: latest,
        fromKg: from?.value,
        toKg: to?.value,
        previewExplanation: who?.explanation,
        previewZ: who?.zScore,
        comparison: summary.delta == null
            ? null
            : '${growthVelocitySigned(summary.delta!)} g so với kỳ liền trước cùng độ dài.',
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Container(
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
                Expanded(
                  child: Text(
                    'T\u1ed1c \u0111\u1ed9 c\u00e2n n\u1eb7ng c\u1ee7a b\u00e9 th\u1ebf n\u00e0o?',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: easyRead ? 20 : 18,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      color: growthGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(summary.comment, style: _body),
            const SizedBox(height: 12),
            Material(
              color: const Color(0xFFFFFEFA),
              borderRadius: BorderRadius.circular(18),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                leading: const GrowthAsset('lightbulb', size: 36),
                title: Text('Vì sao có nhận xét này', style: _title),
                subtitle: Text(
                  'Kết quả của bé và căn cứ đánh giá WHO',
                  style: _body,
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF315B87),
                ),
                onTap: () => openInsight(false),
              ),
            ),
            const SizedBox(height: 12),
            Material(
              color: const Color(0xFFFFFEFA),
              borderRadius: BorderRadius.circular(18),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                leading: const GrowthAsset('heart', size: 36),
                title: Text('Gợi ý cho ba mẹ', style: _title),
                subtitle: Text('Theo dõi các kỳ đo của bé', style: _body),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF315B87),
                ),
                onTap: () => openInsight(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
