import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'growth_models.dart';
import 'growth_repository.dart' show formatGrowthValue;
import 'growth_visuals.dart';
import 'growth_chart_explanation_dialog.dart';
import 'growth_weight_chart_legend.dart';

({double min, double max}) growthStatureDisplayRange(
  double? current,
  double? radius,
  double domainMin,
  double domainMax,
) {
  if (current == null ||
      radius == null ||
      current < domainMin ||
      current > domainMax) {
    return (min: domainMin, max: domainMax);
  }
  return (
    min: math.max(domainMin, current - radius),
    max: math.min(domainMax, current + radius),
  );
}

class GrowthWeightStatureChart extends StatefulWidget {
  const GrowthWeightStatureChart({
    required this.weights,
    required this.statures,
    required this.dateOfBirth,
    required this.useLength,
    required this.statureLabel,
    this.reference,
    this.zScoreForDate,
    this.easyReadMode = false,
    super.key,
  });
  final List<GrowthMeasurementDraft> weights, statures;
  final DateTime? dateOfBirth;
  final bool? useLength;
  final String statureLabel;
  final GrowthStatureReference? reference;
  final double? Function(DateTime)? zScoreForDate;
  final bool easyReadMode;

  @override
  State<GrowthWeightStatureChart> createState() =>
      _GrowthWeightStatureChartState();
}

class _GrowthWeightStatureChartState extends State<GrowthWeightStatureChart> {
  int? _hovered;
  double? _radiusCm;

  @override
  Widget build(BuildContext context) {
    final pairs = <({double cm, double kg, DateTime date})>[];
    if (widget.dateOfBirth != null && widget.useLength != null) {
      for (final weight in widget.weights) {
        final age = growthChartAgeMonths(
          widget.dateOfBirth!,
          weight.measuredAt,
        );
        if (age == null || (age < 24) != widget.useLength) continue;
        for (final stature in widget.statures) {
          if (!DateUtils.isSameDay(weight.measuredAt, stature.measuredAt)) {
            continue;
          }
          final expected = widget.useLength!
              ? GrowthMeasurementMethod.recumbent
              : GrowthMeasurementMethod.standing;
          if (stature.method != expected) continue;
          final rows = widget.reference?.rows;
          if (rows != null &&
              (stature.value < rows.first[0] || stature.value > rows.last[0])) {
            continue;
          }
          pairs.add((
            cm: stature.value,
            kg: weight.value,
            date: weight.measuredAt,
          ));
          break;
        }
      }
    }
    final eligibleStatures = widget.statures.where((point) {
      if (widget.dateOfBirth == null || widget.useLength == null) return false;
      final age = growthChartAgeMonths(widget.dateOfBirth!, point.measuredAt);
      return age != null &&
          (age < 24) == widget.useLength &&
          point.method ==
              (widget.useLength!
                  ? GrowthMeasurementMethod.recumbent
                  : GrowthMeasurementMethod.standing);
    }).toList()..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    final currentCm = eligibleStatures.lastOrNull?.value;
    final domainMin =
        widget.reference?.rows.first[0] ??
        (pairs.isEmpty
            ? 45.0
            : (pairs.map((p) => p.cm).reduce(math.min) / 5).floor() * 5.0 - 5);
    final domainMax =
        widget.reference?.rows.last[0] ??
        (pairs.isEmpty
            ? 110.0
            : (pairs.map((p) => p.cm).reduce(math.max) / 5).ceil() * 5.0 + 5);
    final range = growthStatureDisplayRange(
      currentCm,
      _radiusCm,
      domainMin,
      domainMax,
    );
    pairs.removeWhere((p) => p.cm < range.min || p.cm > range.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Cân nặng theo ${widget.statureLabel}',
                style: TextStyle(
                  fontSize: widget.easyReadMode ? 20 : 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF20365D),
                ),
              ),
            ),
            IconButton(
              tooltip:
                  'Giải thích biểu đồ cân nặng theo ${widget.statureLabel}',
              icon: const Icon(
                Icons.info_outline,
                size: 18,
                color: Color(0xFF62738D),
              ),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => GrowthChartExplanationDialog(
                  title: Text('Cân nặng theo ${widget.statureLabel}'),
                  content: SingleChildScrollView(
                    child: Text(
                      'Trục ngang thể hiện ${widget.statureLabel} (cm), trục dọc thể hiện cân nặng (kg). Các điểm xanh là cặp số đo cùng ngày; rê chuột lên điểm để xem chi tiết.\n\n'
                      'Các đường −3, −2, 0, +2, +3 SD lấy từ bảng WHO theo giới tính. Vùng xanh nằm giữa −2 và +2 SD; vùng vàng nằm giữa −3 và −2 SD hoặc +2 và +3 SD.\n\n'
                      'Bộ lọc lấy số đo ${widget.statureLabel} mới nhất làm tâm: ±5 cm nghĩa là từ số đo hiện tại − 5 cm đến số đo hiện tại + 5 cm. Khoảng hiển thị được giới hạn trong miền bảng WHO.\n\n'
                      'Dưới 24 tháng dùng chiều dài nằm, từ 24 tháng dùng chiều cao đứng. Biểu đồ hỗ trợ theo dõi, không thay thế đánh giá chuyên môn.',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Đóng'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: widget.easyReadMode ? 140 : 112,
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE1E7EB)),
                borderRadius: BorderRadius.circular(24),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<double>(
                  key: const ValueKey('stature-range-filter'),
                  value: _radiusCm ?? 0,
                  isDense: true,
                  iconSize: 18,
                  isExpanded: true,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: widget.easyReadMode ? 18 : 12,
                    color: const Color(0xFF20365D),
                  ),
                  items: [
                    for (final radius in [5.0, 10.0, 20.0, 0.0])
                      DropdownMenuItem(
                        value: radius,
                        enabled: radius == 0 || currentCm != null,
                        child: Text(
                          radius == 0
                              ? 'To\u00e0n b\u1ed9'
                              : '\u00b1${radius.toInt()} cm',
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _radiusCm = value == 0 ? null : value;
                    _hovered = null;
                  }),
                ),
              ),
            ),
          ],
        ),
        if (_radiusCm != null && currentCm != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${formatGrowthValue(range.min)}–${formatGrowthValue(range.max)} cm · Số đo hiện tại: ${formatGrowthValue(currentCm)} cm',
              style: const TextStyle(fontSize: 13, color: growthMuted),
            ),
          ),
        const SizedBox(height: 12),
        if (pairs.isEmpty && widget.reference != null)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Chưa có cặp số đo phù hợp trong khoảng lọc này.',
              style: TextStyle(fontSize: 13, color: growthMuted),
            ),
          ),
        if (pairs.isEmpty && widget.reference == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Chưa có cặp số đo cùng ngày với cách đo phù hợp để hiển thị biểu đồ.',
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final minCm = range.min;
              final maxCm = range.max;
              final childHigh = pairs.map((p) => p.kg).fold(0.0, math.max);
              final referenceHigh = widget.reference?.rows.last.last ?? 0.0;
              final maxKg = math
                  .max(
                    5,
                    ((math.max(childHigh, referenceHigh) + 1) / 5).ceil() * 5,
                  )
                  .toDouble();
              final size = Size(
                constraints.maxWidth,
                widget.easyReadMode ? 300 : 230,
              );
              final labelSize = MediaQuery.textScalerOf(context)
                  .scale(widget.easyReadMode ? 15 : 12);
              final offsets = pairs
                  .map(
                    (p) => Offset(
                      62 + (p.cm - minCm) / (maxCm - minCm) * (size.width - 76),
                      12 + (1 - p.kg / maxKg) * (size.height - 56),
                    ),
                  )
                  .toList();
              final selected = _hovered != null && _hovered! < pairs.length
                  ? _hovered
                  : null;
              final tooltipWidth = math.min(
                widget.easyReadMode ? 260.0 : 220.0,
                size.width - 68,
              );
              final reading = selected == null ? null : pairs[selected];
              final tooltipSpan = reading == null
                  ? const TextSpan(text: '')
                  : growthMeasurementTooltipSpan(
                      measurement: '${formatGrowthValue(reading.kg)} kg',
                      zScore: growthTooltipZScore(
                        widget.zScoreForDate?.call(reading.date),
                      ),
                      contextLabel: '${formatGrowthValue(reading.cm)} cm',
                      date:
                          '${reading.date.day.toString().padLeft(2, '0')}/${reading.date.month.toString().padLeft(2, '0')}/${reading.date.year}',
                    );
              final tooltipMeasure = TextPainter(
                text: tooltipSpan,
                textScaler: MediaQuery.textScalerOf(context),
                textDirection: TextDirection.ltr,
              )..layout(maxWidth: tooltipWidth - 20);
              void select(Offset position) {
                int? nearest;
                var distance = 16.0;
                for (var i = 0; i < offsets.length; i++) {
                  final d = (offsets[i] - position).distance;
                  if (d < distance) {
                    nearest = i;
                    distance = d;
                  }
                }
                if (nearest != _hovered) setState(() => _hovered = nearest);
              }

              return MouseRegion(
                onHover: (event) => select(event.localPosition),
                onExit: (_) => setState(() => _hovered = null),
                child: GestureDetector(
                  onTapUp: (event) => select(event.localPosition),
                  child: SizedBox(
                    height: size.height,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _StaturePainter(
                              offsets,
                              minCm,
                              maxCm,
                              maxKg,
                              widget.statureLabel,
                              widget.reference,
                              labelSize,
                              selected,
                            ),
                          ),
                        ),
                        if (selected != null)
                          Positioned(
                            left: (offsets[selected].dx + 12).clamp(
                              64,
                              size.width - tooltipWidth - 4,
                            ),
                            top:
                                (offsets[selected].dy -
                                        tooltipMeasure.height -
                                        30)
                                    .clamp(
                                      4,
                                      math.max(
                                        4,
                                        size.height -
                                            tooltipMeasure.height -
                                            64,
                                      ),
                                    ),
                            width: tooltipWidth,
                            child: IgnorePointer(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: const Color(0xFFE9EDE8),
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x10000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text.rich(tooltipSpan),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        Text(
          '${widget.statureLabel[0].toUpperCase()}${widget.statureLabel.substring(1)} (cm)',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Color(0xFF62738D)),
        ),
        const SizedBox(height: 8),
        if (widget.reference != null) ...[
          const GrowthWeightReferenceLegend(seriesColor: growthWeightOrange),
        ] else
          const Text(
            'Chưa có đường tham chiếu WHO cho biểu đồ này.',
            style: TextStyle(fontSize: 13, color: growthMuted),
          ),
      ],
    );
  }
}

class _StaturePainter extends CustomPainter {
  _StaturePainter(
    this.points,
    this.minCm,
    this.maxCm,
    this.maxKg,
    this.label,
    this.reference,
    this.labelSize,
    this.selected,
  );
  final GrowthStatureReference? reference;
  final List<Offset> points;
  final double minCm, maxCm, maxKg;
  final String label;
  final double labelSize;
  final int? selected;
  void text(
    Canvas canvas,
    String value,
    Offset position, {
    bool centered = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: labelSize,
          color: Color(0xFF62738D),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        centered ? position.dx - painter.width / 2 : position.dx,
        position.dy,
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0x709BAAB0)
      ..strokeWidth = .7;
    final bottom = size.height - 44;
    for (var i = 0; i <= 3; i++) {
      final y = 12 + i / 3 * (size.height - 56);
      canvas.drawLine(Offset(62, y), Offset(size.width - 14, y), grid);
      text(
        canvas,
        formatGrowthValue(maxKg * (1 - i / 3)),
        Offset(29, y - labelSize / 2),
      );
    }
    final divisions = labelSize > 20 ? 3 : 5;
    for (var i = 0; i <= divisions; i++) {
      final x = 62 + i / divisions * (size.width - 76);
      canvas.drawLine(Offset(x, 12), Offset(x, bottom), grid);
      text(
        canvas,
        formatGrowthValue(minCm + (maxCm - minCm) * i / divisions),
        Offset(x, bottom + 8),
        centered: true,
      );
    }
    canvas.save();
    canvas.translate(5, bottom / 2 + 46);
    canvas.rotate(-math.pi / 2);
    text(canvas, 'C\u00e2n n\u1eb7ng (kg)', Offset.zero);
    canvas.restore();
    if (reference != null) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(62, 12, size.width - 14, size.height - 44));
      Offset at(List<double> row, int sd) => Offset(
        62 + (row[0] - minCm) / (maxCm - minCm) * (size.width - 76),
        12 + (1 - row[sd] / maxKg) * (size.height - 56),
      );
      Path curve(int sd) {
        final path = Path();
        for (var i = 0; i < reference!.rows.length; i++) {
          final p = at(reference!.rows[i], sd);
          if (i == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        return path;
      }

      void band(int low, int high, Color color) {
        final path = curve(low);
        for (final row in reference!.rows.reversed) {
          final p = at(row, high);
          path.lineTo(p.dx, p.dy);
        }
        path.close();
        canvas.drawPath(path, Paint()..color = color);
      }

      band(1, 5, const Color(0x38F0AE52));
      band(2, 4, const Color(0x482DB878));
      const colors = [
        Color(0xFFFF8D79),
        Color(0xFFF0BE75),
        Color(0xFF79C99B),
        Color(0xFFF0BE75),
        Color(0xFFFF8D79),
      ];
      for (var i = 1; i <= 5; i++) {
        canvas.drawPath(
          curve(i),
          Paint()
            ..color = colors[i - 1]
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke,
        );
      }
      canvas.restore();
    }
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = growthWeightOrange
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
    paint.style = PaintingStyle.fill;
    for (var i = 0; i < points.length; i++) {
      if (i == selected) {
        canvas.drawCircle(
          points[i],
          8,
          Paint()..color = growthWeightOrange.withValues(alpha: .21),
        );
      }
      canvas.drawCircle(points[i], 3.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StaturePainter oldDelegate) => true;
}
