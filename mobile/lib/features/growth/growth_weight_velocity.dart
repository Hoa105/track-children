import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'growth_repository.dart';
import 'growth_visuals.dart';
import 'growth_chart_explanation_dialog.dart';
import 'growth_weight_velocity_data.dart';
import 'growth_weight_velocity_summary.dart';
import 'growth_weight_velocity_axes.dart';

class GrowthWeightVelocityTab extends StatefulWidget {
  const GrowthWeightVelocityTab({
    required this.repository,
    required this.readings,
    this.easyRead = false,
    this.whoResult,
    super.key,
  });
  final GrowthRepository repository;
  final List<GrowthMeasurementDraft> readings;
  final bool easyRead;
  final GrowthVelocityWhoResult? whoResult;
  @override
  State<GrowthWeightVelocityTab> createState() =>
      _GrowthWeightVelocityTabState();
}

class _GrowthWeightVelocityTabState extends State<GrowthWeightVelocityTab> {
  late Future<GrowthWeightVelocityReference?> _reference = widget.repository
      .weightVelocityReference();
  int? _selected;
  int? _ageBand;
  static const _marks = [0, 3, 6, 9, 10, 12, 36, 60];
  @override
  Widget build(BuildContext context) {
    final points = growthWeightMonthlyIncrements(
      widget.readings,
      widget.repository.dateOfBirth,
    ).toList();
    final start = _ageBand == null ? 0 : _marks[_ageBand!];
    final end = _ageBand == null ? 12 : _marks[_ageBand! + 1];
    final ticks = growthVelocityAgeTicks(
      start,
      end,
      largeText: MediaQuery.textScalerOf(context).scale(12) > 20,
    );
    points.removeWhere((p) => p.startMonth < start || p.startMonth + 1 > end);
    final summary = GrowthVelocitySummary(points);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!widget.easyRead)
                  const GrowthAsset('weight-chart-arrow-left', size: 52),
                const SizedBox(width: 4),
                Flexible(
                  child: Transform.rotate(
                    angle: widget.easyRead ? 0 : -.055,
                    child: Text(
                      'Mỗi lần đo giúp ba mẹ hiểu thêm\nvề nhịp lớn khôn của con.',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: widget.easyRead
                            ? 'Nunito'
                            : 'DancingScript',
                        fontSize: widget.easyRead ? 18 : 18,
                        height: 1.35,
                        color: const Color(0xFF20365D),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          GrowthVelocityHighlights(summary: summary, easyRead: widget.easyRead),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tốc độ tăng cân theo tháng',
                  style: TextStyle(
                    fontSize: widget.easyRead ? 20 : 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF20365D),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Giải thích tốc độ tăng cân',
                icon: const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: growthMuted,
                ),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => GrowthChartExplanationDialog(
                    title: const Text('Tốc độ tăng cân theo tháng'),
                    content: const Text(
                      'Trục ngang là tuổi theo tháng, trục dọc là mức tăng cân (g/tháng). Điểm xanh là chênh lệch giữa hai số đo cách nhau đúng một tháng tại mốc tuổi tròn.\n\nVùng xanh nhạt là khoảng −2 đến +2 SD của bảng WHO theo giới tính, chu kỳ 1 tháng, đến 12 tháng tuổi. Hai khoảng đầu của bảng là 0–4 tuần và 4 tuần–2 tháng.\n\nKhông quy đổi số đo cách nhau nhiều tháng hoặc không đúng mốc thành tốc độ theo tháng. Những khoảng đó chưa đủ cơ sở đối chiếu trên biểu đồ này.\n\nRê chuột hoặc chạm vào điểm đo để xem chi tiết. Vùng tham chiếu hỗ trợ đối chiếu, không tự tạo kết luận hay Z-score cho bé.',
                    ),
                    actions: const [],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: widget.easyRead ? 160 : 132,
                constraints: const BoxConstraints(minHeight: 40),
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE1E7EB)),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    key: const ValueKey('velocity-age-filter'),
                    value: _ageBand ?? -1,
                    isDense: true,
                    iconSize: 18,
                    isExpanded: true,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: widget.easyRead ? 18 : 12,
                      color: const Color(0xFF20365D),
                    ),
                    items: const [
                      DropdownMenuItem(value: -1, child: Text('Toàn bộ')),
                      DropdownMenuItem(value: 0, child: Text('0–3 tháng')),
                      DropdownMenuItem(value: 1, child: Text('3–6 tháng')),
                      DropdownMenuItem(value: 2, child: Text('6–9 tháng')),
                      DropdownMenuItem(value: 3, child: Text('9–10 tháng')),
                      DropdownMenuItem(value: 4, child: Text('10–12 tháng')),
                      DropdownMenuItem(value: 5, child: Text('1–3 tuổi')),
                      DropdownMenuItem(value: 6, child: Text('3–5 tuổi')),
                    ],
                    onChanged: (value) => setState(() {
                      _ageBand = value == -1 ? null : value;
                      _selected = null;
                    }),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<GrowthWeightVelocityReference?>(
            future: _reference,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 280,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final reference = start >= 12 ? null : snapshot.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final size = Size(
                        constraints.maxWidth,
                        widget.easyRead ? 340 : 280,
                      );
                      final painter = _VelocityPainter(
                        points,
                        reference,
                        MediaQuery.textScalerOf(context)
                            .scale(widget.easyRead ? 15 : 12),
                        _selected,
                        ticks,
                        widget.repository.dateOfBirth,
                      );
                      final selected =
                          _selected != null && _selected! < points.length
                          ? points[_selected!]
                          : null;
                      final result = widget.whoResult;
                      final zScore = result?.matches(selected) == true
                          ? result?.zScore
                          : selected == null
                          ? null
                          : widget.repository.weightVelocityDisplayZScore(
                              selected,
                            );
                      final tooltipSpan = selected == null
                          ? const TextSpan(text: '')
                          : growthMeasurementTooltipSpan(
                              measurement:
                                  '${formatGrowthValue(selected.grams)} g/th\u00e1ng',
                              zScore: growthTooltipZScore(zScore).replaceFirst(
                                'Z-score:',
                                'Z-score v\u1eadn t\u1ed1c:',
                              ),
                              contextLabel:
                                  '${selected.startMonth}\u2013${selected.startMonth + 1} th\u00e1ng',
                              date:
                                  '${selected.to.day.toString().padLeft(2, '0')}/${selected.to.month.toString().padLeft(2, '0')}/${selected.to.year}',
                            );
                      final width = math.min(
                        widget.easyRead ? 260.0 : 220.0,
                        size.width - 68,
                      );
                      final measure = TextPainter(
                        text: tooltipSpan,
                        textScaler: MediaQuery.textScalerOf(context),
                        textDirection: TextDirection.ltr,
                      )..layout(maxWidth: width - 20);
                      void select(Offset position, double radius) {
                        int? found;
                        var distance = radius;
                        for (var i = 0; i < points.length; i++) {
                          final d =
                              (painter.offset(
                                        points[i].startMonth + .5,
                                        points[i].grams,
                                        size,
                                      ) -
                                      position)
                                  .distance;
                          if (d < distance) {
                            found = i;
                            distance = d;
                          }
                        }
                        if (_selected != found) {
                          setState(() => _selected = found);
                        }
                      }

                      final at = selected == null
                          ? null
                          : painter.offset(
                              selected.startMonth + .5,
                              selected.grams,
                              size,
                            );
                      return Semantics(
                        label: 'Biểu đồ mức tăng cân theo tháng, đơn vị gam trên tháng',
                        child: MouseRegion(
                          onHover: (event) => select(event.localPosition, 16),
                          onExit: (_) => setState(() => _selected = null),
                          child: GestureDetector(
                            onTapUp: (event) => select(event.localPosition, 36),
                            child: SizedBox(
                              height: size.height,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(painter: painter),
                                  ),
                                  if (at != null)
                                    Positioned(
                                      left: (at.dx + 12).clamp(
                                        64,
                                        size.width - width - 4,
                                      ),
                                      top: (at.dy - measure.height - 48).clamp(
                                        4,
                                        math.max(
                                          4,
                                          size.height - measure.height - 64,
                                        ),
                                      ),
                                      width: width,
                                      child: IgnorePointer(
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFE9EDE8),
                                            ),
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
                        ),
                      );
                    },
                  ),
                  const Text(
                    'Tuổi (tháng)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF62738D)),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 18,
                    runSpacing: 10,
                    children: [
                      if (reference != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 24,
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDDEBFF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Flexible(
                              child: Text(
                                'WHO: −2 đến +2 SD',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: growthMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 10,
                            color: growthWeightOrange,
                          ),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Mức tăng của bé',
                              style: TextStyle(
                                fontSize: 13,
                                color: growthMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (points.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Column(
                        children: [
                          const GrowthAsset('insufficient-velocity', size: 64),
                          const SizedBox(height: 10),
                          Text(
                            start >= 12
                                ? 'Chưa có tham chiếu WHO chu kỳ 1 tháng cho khoảng tuổi này.'
                                : widget.repository.dateOfBirth == null
                                ? 'Chưa có ngày sinh để xác định tuổi tại ngày đo.'
                                : 'Chưa đủ hai số đo đúng mốc tháng để hiển thị mức tăng trong 2–12 tháng tuổi.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: growthMuted,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (reference == null &&
                      (points.isNotEmpty || snapshot.hasError))
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        snapshot.hasError
                            ? 'Chưa tải được tham chiếu WHO.'
                            : 'Chưa có dữ liệu tham chiếu phù hợp.',
                        style: const TextStyle(color: growthMuted),
                      ),
                    ),
                  if (snapshot.hasError)
                    TextButton(
                      onPressed: () => setState(
                        () => _reference = widget.repository
                            .weightVelocityReference(),
                      ),
                      child: const Text('Thử lại tham chiếu WHO'),
                    ),
                ],
              );
            },
          ),
          GrowthVelocityAssessment(
            summary: summary,
            readings: widget.readings,
            whoResult:
                widget.whoResult ??
                growthVelocityReviewFixture(widget.repository, summary.latest),
            easyRead: widget.easyRead,
          ),
        ],
      ),
    );
  }
}

class _VelocityPainter extends CustomPainter {
  _VelocityPainter(
    this.points,
    this.reference,
    this.labelSize,
    this.selected,
    this.ticks,
    this.birth,
  );
  final List<int> ticks;
  final DateTime? birth;
  List<({double start, double end, double low, double high})> get bands =>
      reference?.bands(
        ticks.first.toDouble(),
        ticks.last.toDouble(),
        birth == null
            ? null
            : growthChartAgeMonths(
                birth!,
                DateTime(birth!.year, birth!.month, birth!.day + 28),
              ),
      ) ??
      const [];

  double fraction(double month) =>
      (month - ticks.first) / (ticks.last - ticks.first);

  final List<GrowthWeightVelocityPoint> points;
  final GrowthWeightVelocityReference? reference;
  final double labelSize;
  final int? selected;
  GrowthVelocityValueAxis get valueAxis => growthVelocityValueAxis([
    ...points.map((p) => p.grams),
    ...bands.expand((b) => [b.low, b.high]),
  ]);
  double get low => valueAxis.min;
  double get high => valueAxis.max;
  Offset offset(double month, double grams, Size size) => Offset(
    62 + fraction(month) * (size.width - 76),
    12 + (high - grams) / (high - low) * (size.height - 56),
  );
  void label(Canvas canvas, String value, Offset at, {bool centered = false}) {
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: labelSize,
          color: const Color(0xFF62738D),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset(centered ? at.dx - text.width / 2 : at.dx, at.dy),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0x709BAAB0)
      ..strokeWidth = .7;
    for (final grams in valueAxis.ticks) {
      final y = offset(ticks.first.toDouble(), grams, size).dy;
      canvas.drawLine(Offset(62, y), Offset(size.width - 14, y), grid);
      label(canvas, formatGrowthValue(grams), Offset(25, y - labelSize / 2));
    }
    for (final month in ticks) {
      final at = offset(month.toDouble(), low, size);
      canvas.drawLine(Offset(at.dx, 12), at, grid);
      label(canvas, '$month', Offset(at.dx, size.height - 36), centered: true);
    }
    if (reference != null) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(62, 12, size.width - 14, size.height - 44));
      for (final band in bands) {
        final topLeft = offset(band.start, band.high, size);
        final bottomRight = offset(band.end, band.low, size);
        canvas.drawRect(
          Rect.fromPoints(topLeft, bottomRight),
          Paint()..color = const Color(0xFFDDEBFF),
        );
      }
      canvas.restore();
    }
    canvas.save();
    canvas.translate(5, size.height / 2 + 65);
    canvas.rotate(-math.pi / 2);
    label(canvas, 'Mức tăng cân (g/tháng)', Offset.zero);
    canvas.restore();
    final line = Paint()
      ..color = growthWeightOrange
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final at = offset(points[i].startMonth + .5, points[i].grams, size);
      if (i == 0 || points[i].startMonth != points[i - 1].startMonth + 1) {
        path.moveTo(at.dx, at.dy);
      } else {
        path.lineTo(at.dx, at.dy);
      }
    }
    canvas.drawPath(path, line);
    line.style = PaintingStyle.fill;
    for (var i = 0; i < points.length; i++) {
      final at = offset(points[i].startMonth + .5, points[i].grams, size);
      if (i == selected) {
        canvas.drawCircle(
          at,
          8,
          Paint()..color = growthWeightOrange.withValues(alpha: .21),
        );
      }
      canvas.drawCircle(at, 3.5, line);
    }
  }

  @override
  bool shouldRepaint(covariant _VelocityPainter old) => true;
}
