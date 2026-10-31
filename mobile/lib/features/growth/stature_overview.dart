import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'growth_repository.dart';
import 'growth_visuals.dart';
import 'stature_insight_sheet.dart';
import 'weight_chart_view.dart';

String statureAgeLabel(double? z) => z == null || !z.isFinite
    ? 'Chưa đủ dữ liệu đánh giá'
    : z < -3
    ? 'Rất thấp'
    : z < -2
    ? 'Thấp'
    : z > 3
    ? 'Rất cao'
    : 'Phù hợp';

/// WHO 2006: retain the separate length and height curves at the transition.
List<WeightCurve> statureAgeCurves(
  GrowthWeightReference? length,
  GrowthWeightReference? height,
) => [
  for (final row in length?.rows ?? <GrowthWeightReferenceRow>[])
    (x: row.ageDays ?? weightAgeTick(row.month), kg: row.weights),
  for (final row in height?.rows ?? <GrowthWeightReferenceRow>[])
    (x: row.ageDays ?? weightAgeTick(row.month), kg: row.weights),
];

double? statureValueForAge(GrowthMeasurementDraft p, DateTime birth) {
  if (p.method == null || !p.value.isFinite || p.value <= 0) return null;
  final days = DateTime.utc(
    p.measuredAt.year,
    p.measuredAt.month,
    p.measuredAt.day,
  ).difference(DateTime.utc(birth.year, birth.month, birth.day)).inDays;
  if (days < 0 || days > 1856) return null;
  final length = days < 731;
  return p.value +
      (length && p.method == GrowthMeasurementMethod.standing
          ? .7
          : !length && p.method == GrowthMeasurementMethod.recumbent
          ? -.7
          : 0);
}

class StatureOverview extends StatelessWidget {
  const StatureOverview({
    required this.points,
    required this.repository,
    required this.lengthReference,
    required this.heightReference,
    required this.scoreFor,
    required this.onUpdate,
    required this.onRetry,
    this.failed = false,
    this.easyRead = false,
    super.key,
  });
  final List<GrowthMeasurementDraft> points;
  final GrowthRepository repository;
  final GrowthWeightReference? lengthReference, heightReference;
  final double? Function(GrowthMeasurementDraft) scoreFor;
  final VoidCallback onUpdate, onRetry;
  final bool failed, easyRead;

  @override
  Widget build(BuildContext context) {
    final latest = points.last;
    final birth = repository.dateOfBirth;
    final age = birth == null
        ? null
        : growthChartAgeMonths(birth, latest.measuredAt);
    final name = age == null
        ? 'Chiều dài/chiều cao'
        : age < 24
        ? 'Chiều dài'
        : 'Chiều cao';
    final previous = points.length > 1 ? points[points.length - 2] : null;
    final change = previous?.method != null && previous!.method == latest.method
        ? latest.value - previous.value
        : null;
    final z = scoreFor(latest);
    String date(DateTime d) => '${d.day}/${d.month}/${d.year}';
    void insight() => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatureInsightSheet(
        measurement: latest,
        birth: birth,
        zScore: z,
        label: statureAgeLabel(z),
      ),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final large =
                  easyRead || MediaQuery.textScalerOf(context).scale(14) > 20;
              final value = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$name hiện tại',
                    style: TextStyle(
                      fontFamily: large ? 'Nunito' : 'DancingScript',
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: WeightChartColors.heroInk,
                    ),
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${formatGrowthValue(latest.value)}\u00A0cm',
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: StatureChartColors.data,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cập nhật số đo',
                        onPressed: onUpdate,
                        icon: const Icon(Icons.edit_outlined, size: 20),
                      ),
                    ],
                  ),
                  Text(
                    'Ngày đo: ${date(latest.measuredAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: WeightChartColors.muted,
                    ),
                  ),
                ],
              );
              final compare = Text(
                change == null
                    ? 'Chưa có số đo cùng cách đo để so sánh'
                    : '${change >= 0 ? 'Tăng' : 'Giảm'} ${formatGrowthValue(change.abs())}\u00A0cm\nso với lần trước',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: large ? 'Nunito' : 'DancingScript',
                  fontSize: large ? 18 : 21,
                  fontWeight: FontWeight.w800,
                  color: StatureChartColors.data,
                ),
              );
              return large
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [value, compare],
                    )
                  : Row(
                      children: [
                        Expanded(child: value),
                        const SizedBox(width: 12),
                        Flexible(child: compare),
                      ],
                    );
            },
          ),
          const SizedBox(height: 16),
          if (birth == null)
            const Text('Chưa có ngày sinh để hiển thị biểu đồ theo tuổi.')
          else
            WeightChartView(
              title: 'Chiều dài/chiều cao theo tuổi',
              metricName: 'Chiều dài/chiều cao',
              unit: 'cm',
              dataColor: StatureChartColors.data,
              breakAt: weightAgeTick(24),
              birth: birth,
              curves: statureAgeCurves(lengthReference, heightReference),
              points: [
                for (final p in points)
                  if (statureValueForAge(p, birth) != null)
                    (
                      x:
                          DateTime.utc(
                                p.measuredAt.year,
                                p.measuredAt.month,
                                p.measuredAt.day,
                              )
                              .difference(
                                DateTime.utc(
                                  birth.year,
                                  birth.month,
                                  birth.day,
                                ),
                              )
                              .inDays
                              .toDouble(),
                      kg: statureValueForAge(p, birth)!,
                      date: p.measuredAt,
                      z: scoreFor(p),
                    ),
              ],
              classificationForDate: (d) => statureAgeLabel(
                scoreFor(
                  points.firstWhere(
                    (p) => DateUtils.isSameDay(p.measuredAt, d),
                  ),
                ),
              ),
            ),
          if (failed)
            TextButton(
              onPressed: onRetry,
              child: const Text('Chưa tải được đường WHO. Thử lại'),
            ),
          const SizedBox(height: 24),
          Container(
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
                    const GrowthAsset('result-smile-stature', size: 48),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$name của bé thế nào?',
                        style: const TextStyle(
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
                  statureAgeLabel(z),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Theo dõi chiều dài/chiều cao theo tuổi qua các lần đo, kết hợp cách đo và tình trạng sức khỏe của bé.',
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 12),
                Material(
                  color: const Color(0xFFFFFEFA),
                  borderRadius: BorderRadius.circular(18),
                  child: ListTile(
                    title: const Text(
                      'Vì sao có nhận xét này?',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text('Số đo và căn cứ đối chiếu WHO'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: insight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
