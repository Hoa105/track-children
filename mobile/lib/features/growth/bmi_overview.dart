import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'growth_repository.dart';
import 'growth_visuals.dart';
import 'bmi_insight_sheet.dart';
import 'growth_weight_velocity_header.dart';
import 'weight_chart_view.dart';

String bmiAgeLabel(double? z) => z == null || !z.isFinite
    ? 'Chưa đủ dữ liệu đánh giá'
    : z < -3
    ? 'Rất gầy'
    : z < -2
    ? 'Gầy'
    : z > 3
    ? 'Béo phì'
    : z > 2
    ? 'Thừa cân'
    : z > 1
    ? 'Nguy cơ thừa cân'
    : 'Cân đối';

class BmiOverview extends StatelessWidget {
  const BmiOverview({
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
    const name = 'BMI';
    final previous = points.length > 1 ? points[points.length - 2] : null;
    final change = previous != null ? latest.value - previous.value : null;
    final z = scoreFor(latest);
    void insight() => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BmiInsightSheet(
        measurement: latest,
        birth: birth,
        zScore: z,
        label: bmiAgeLabel(z),
      ),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BmiCurrentHeader(
            latest: latest,
            change: change,
            easyRead: easyRead,
            onUpdate: onUpdate,
          ),
          const SizedBox(height: 16),
          if (birth == null)
            const Text('Chưa có ngày sinh để hiển thị biểu đồ theo tuổi.')
          else
            WeightChartView(
              title: 'BMI theo tuổi',
              metricName: 'BMI',
              unit: 'kg/m²',
              dataColor: growthGreen,

              birth: birth,
              breakAt: weightAgeTick(24),
              explanation: bmiChartExplanation,
              curves: [
                for (final ref in [lengthReference, heightReference])
                  for (final r in ref?.rows ?? <GrowthWeightReferenceRow>[])
                    (
                      x: identical(ref, lengthReference) && r.month == 24
                          ? 730.0
                          : r.ageDays ?? weightAgeTick(r.month),
                      kg: r.weights,
                    ),
              ],
              points: [
                for (final p in points)
                  if (p.value.isFinite && p.value > 0 && p.method != null)
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
                      kg: p.value,
                      date: p.measuredAt,
                      z: scoreFor(p),
                    ),
              ],
              classificationForDate: (d) => bmiAgeLabel(
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
                    const GrowthAsset('overview-bmi', size: 48),
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
                  bmiAgeLabel(z),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cập nhật cân nặng và chiều dài/chiều cao cùng ngày để theo dõi BMI theo tuổi. Mức tăng hoặc giảm BMI cần được xem cùng tuổi và diễn tiến tăng trưởng.',
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

class BmiCurrentHeader extends StatelessWidget {
  const BmiCurrentHeader({
    required this.latest,
    required this.change,
    required this.easyRead,
    required this.onUpdate,
    super.key,
  });
  final GrowthMeasurementDraft latest;
  final double? change;
  final bool easyRead;
  final VoidCallback onUpdate;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final large = easyRead || MediaQuery.textScalerOf(context).scale(14) > 20;
      String number(double value) =>
          formatGrowthValue(double.parse(value.toStringAsFixed(2)));
      final value = Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: number(latest.value),
              style: TextStyle(
                fontSize: large
                    ? 48
                    : c.maxWidth < 330
                    ? 38
                    : 44,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.5,
                color: growthGreen,
              ),
            ),
            TextSpan(
              text: ' kg/m²',
              style: TextStyle(
                fontSize: large ? 24 : 20,
                fontWeight: FontWeight.w700,
                color: growthGreen,
              ),
            ),
          ],
        ),
        style: const TextStyle(fontFamily: 'Nunito', height: 1.12),
        maxLines: 1,
        softWrap: false,
      );
      final update = IconButton(
        tooltip: 'Cập nhật số đo để tính BMI',
        onPressed: onUpdate,
        style: IconButton.styleFrom(
          foregroundColor: WeightChartColors.heroInk,
          hoverColor: growthGreen.withValues(alpha: .1),
          highlightColor: growthGreen.withValues(alpha: .18),
          minimumSize: const Size(48, 48),
        ),
        icon: const Icon(Icons.edit_outlined, size: 20),
      );
      final compare = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (large)
            Text(
              change == null
                  ? 'Chưa có lần đo trước'
                  : change!.abs() < .0001
                  ? 'BMI không đổi'
                  : '${change! > 0 ? 'Tăng' : 'Giảm'} ${number(change!.abs())} kg/m²',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: growthGreen,
              ),
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                change == null
                    ? 'Chưa có lần đo trước'
                    : change!.abs() < .0001
                    ? 'BMI không đổi'
                    : '${change! > 0 ? 'Tăng' : 'Giảm'} ${number(change!.abs())} kg/m²',
                style: TextStyle(
                  fontFamily: large ? 'Nunito' : 'DancingScript',
                  fontSize: large ? 20 : 21,
                  fontWeight: FontWeight.w900,
                  color: growthGreen,
                ),
              ),
            ),
          if (change != null)
            Text(
              'so với lần trước',
              style: TextStyle(
                fontFamily: large ? 'Nunito' : 'DancingScript',
                fontSize: large ? 17 : 15,
                color: WeightChartColors.heroInk,
              ),
            ),
        ],
      );
      return CustomPaint(
        painter: large
            ? null
            : const GrowthWeightHeaderDoodle(color: growthGreen),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BMI hiện tại của bé',
                style: TextStyle(
                  fontFamily: large ? 'Nunito' : 'DancingScript',
                  fontSize: large ? 20 : 21,
                  fontWeight: FontWeight.w700,
                  color: WeightChartColors.heroInk,
                ),
              ),
              const SizedBox(height: 4),
              if (!large)
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: value,
                            ),
                          ),
                          update,
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: compare,
                      ),
                    ),
                  ],
                )
              else ...[
                Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: value,
                      ),
                    ),
                    update,
                  ],
                ),
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerRight, child: compare),
              ],
            ],
          ),
        ),
      );
    },
  );
}
