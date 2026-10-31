import 'dart:math' as math;

import '../../app_colors.dart';

import 'package:flutter/material.dart';

import 'growth_repository.dart';
import 'growth_visuals.dart';
import 'growth_velocity_tooltip.dart';
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
    this.expanded = false,
    this.initialPeriod = 1,
    this.initialAgeBand,
    super.key,
  });
  final GrowthRepository repository;
  final List<GrowthMeasurementDraft> readings;
  final bool easyRead;
  final bool expanded;
  final int initialPeriod;
  final int? initialAgeBand;
  final GrowthVelocityWhoResult? whoResult;
  @override
  State<GrowthWeightVelocityTab> createState() =>
      _GrowthWeightVelocityTabState();
}

class _GrowthWeightVelocityTabState extends State<GrowthWeightVelocityTab> {
  late int _period = widget.initialPeriod;
  late Future<GrowthWeightVelocityReference?> _reference = widget.repository
      .weightVelocityPeriodReference(_period);
  int? _selected;
  late int? _ageBand = widget.initialAgeBand;
  static const _ranges = [
    (0, 4),
    (4, 7),
    (7, 10),
    (10, 13),
    (12, 48),
    (48, 60),
  ];
  late Future<List<GrowthWeightVelocityPoint>?> _intervals = widget.repository
      .weightVelocityIntervals(period: _period);
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<GrowthWeightVelocityPoint>?>(
        future: _intervals,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Center(
              child: Text(
                'Không tải được kỳ đo. Hãy mở lại màn hình để thử lại.',
              ),
            );
          if (snapshot.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          return _buildContent(context, snapshot.data);
        },
      );
  Widget _buildContent(
    BuildContext context,
    List<GrowthWeightVelocityPoint>? serverPoints,
  ) {
    final points =
        serverPoints?.toList() ??
        growthWeightPeriodIncrements(
          widget.readings,
          widget.repository.dateOfBirth,
          _period,
        ).toList();
    final start = _ageBand == null ? 0 : _ranges[_ageBand!].$1;
    final end = _ageBand == null
        ? (serverPoints == null
              ? (_period == 1 ? 12 : 24)
              : math.max(
                  _period == 1 ? 12 : 24,
                  serverPoints.fold<int>(
                    0,
                    (value, p) => math.max(value, p.endAge.ceil()),
                  ),
                ))
        : _ranges[_ageBand!].$2;
    final ticks = growthVelocityAgeTicks(
      start,
      end,
      largeText: MediaQuery.textScalerOf(context).scale(12) > 20,
    );
    final historyPoints = points.toList();
    points.removeWhere((p) => p.startAge < start || p.endAge > end);
    final birth = widget.repository.dateOfBirth;
    final recordingOnly =
        birth != null &&
        widget.readings.any(
          (p) => (growthChartAgeMonths(birth, p.measuredAt) ?? 0) > 24,
        );
    final matched = points
        .where((p) => p.hasWhoReference && p.intervalMonths == _period)
        .toList();
    final summary = GrowthVelocitySummary(
      !recordingOnly && matched.isNotEmpty
          ? historyPoints
                .where(
                  (p) =>
                      p.hasWhoReference &&
                      p.intervalMonths == _period &&
                      !p.to.isAfter(matched.last.to),
                )
                .toList()
          : points,
    );
    return SingleChildScrollView(
      padding: widget.expanded
          ? const EdgeInsets.all(8)
          : const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.expanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final period in [1, 2, 3, 4, 6])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Semantics(
                          selected: _period == period,
                          child: TextButton(
                            key: ValueKey('velocity-period-tab-$period'),
                            style: TextButton.styleFrom(
                              foregroundColor: _period == period
                                  ? WeightChartColors.positive
                                  : WeightChartColors.axis,
                              backgroundColor: _period == period
                                  ? WeightChartColors.center
                                  : Colors.transparent,
                              minimumSize: const Size(64, 44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: _period == period
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                            onPressed: () {
                              if (_period == period) return;
                              setState(() {
                                _period = period;
                                _selected = null;
                                _ageBand = null;
                                _intervals = widget.repository
                                    .weightVelocityIntervals(period: period);
                                _reference = widget.repository
                                    .weightVelocityPeriodReference(period);
                              });
                            },
                            child: Text('$period tháng'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (!widget.expanded)
            GrowthVelocityHighlights(
              summary: summary,
              easyRead: widget.easyRead,
            ),
          if (!widget.expanded) const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: widget.expanded
                ? null
                : BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: WeightChartColors.frame),
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (!widget.expanded)
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Theo\ntháng',
                            maxLines: 2,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: widget.easyRead ? 20 : 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF20365D),
                            ),
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Giải thích tốc độ tăng cân',
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 40,
                      ),
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.info_outline,
                        size: 18,
                        color: growthMuted,
                      ),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => GrowthChartExplanationDialog(
                          title: Text('Mức tăng cân trong kỳ $_period tháng'),
                          content: Text(
                            'Trục ngang là tuổi theo tháng, trục dọc là mức tăng cân thực tế trong kỳ (g). Điểm cam thể hiện chênh lệch giữa hai số cân.\n\nVùng xanh nhạt là khoảng −2 đến +2 SD, đường xanh lá là trung vị WHO theo giới tính và chu kỳ $_period tháng. Mỗi đoạn tham chiếu thuộc một khoảng đo riêng.\n\n${_period == 1 ? 'Chu kỳ một tháng có chuẩn đến 12 tháng tuổi, với hai kỳ đầu là 0–4 tuần và 4 tuần–2 tháng.' : 'Chu kỳ này có chuẩn đến 24 tháng tuổi. Không chia mức tăng của kỳ dài để đối chiếu bảng một tháng.'}\n\nChạm hoặc rê chuột lên điểm để xem kỳ đo. Kỳ không khớp chuẩn chỉ ghi nhận số liệu, không có đánh giá WHO.',
                          ),
                          actions: const [],
                        ),
                      ),
                    ),
                    if (widget.expanded) const Spacer(),
                    const SizedBox(width: 4),
                    Container(
                      width: 104,
                      constraints: const BoxConstraints(minHeight: 36),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
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
                            fontSize: 13,
                            color: const Color(0xFF20365D),
                          ),
                          items: const [
                            DropdownMenuItem(value: -1, child: Text('Toàn bộ')),
                            DropdownMenuItem(value: 0, child: Text('0–3')),
                            DropdownMenuItem(value: 1, child: Text('4–6')),
                            DropdownMenuItem(value: 2, child: Text('7–9')),
                            DropdownMenuItem(value: 3, child: Text('10–12')),
                            DropdownMenuItem(value: 4, child: Text('1–3 tuổi')),
                            DropdownMenuItem(value: 5, child: Text('4–5 tuổi')),
                          ],
                          onChanged: (value) => setState(() {
                            _ageBand = value == -1 ? null : value;
                            _selected = null;
                          }),
                        ),
                      ),
                    ),
                    if (!widget.expanded)
                      IconButton(
                        tooltip: 'Phóng to biểu đồ',
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 40,
                        ),
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.fullscreen_rounded,
                          color: WeightChartColors.axis,
                        ),
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              backgroundColor: Colors.white,
                              appBar: AppBar(
                                title: Text(
                                  'Tốc độ tăng cân · kỳ $_period tháng',
                                ),
                                backgroundColor: Colors.white,
                              ),
                              body: GrowthWeightVelocityTab(
                                repository: widget.repository,
                                readings: widget.readings,
                                easyRead: widget.easyRead,
                                whoResult: widget.whoResult,
                                expanded: true,
                                initialPeriod: _period,
                                initialAgeBand: _ageBand,
                              ),
                            ),
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
                    final reference = start >= (_period == 1 ? 12 : 24)
                        ? null
                        : snapshot.data;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final size = Size(
                              constraints.maxWidth,
                              widget.expanded
                                  ? math.max(
                                      340.0,
                                      MediaQuery.sizeOf(context).height * .55,
                                    )
                                  : widget.easyRead
                                  ? 340
                                  : 300,
                            );
                            final painter = _VelocityPainter(
                              points,
                              reference,
                              MediaQuery.textScalerOf(context)
                                  .scale(widget.easyRead ? 15 : 12),
                              _selected,
                              ticks,
                              widget.repository.dateOfBirth,
                              expanded: widget.expanded,
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
                                : growthVelocityTooltip(
                                    selected,
                                    previewZ: zScore,
                                    detailed: widget.expanded,
                                  );
                            final width = math.min(
                              widget.expanded ? 260.0 : 185.0,
                              size.width - 8,
                            );
                            void select(Offset position, double radius) {
                              int? found;
                              var distance = radius;
                              for (var i = 0; i < points.length; i++) {
                                final d =
                                    (painter.offset(
                                              points[i].midpointAge,
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
                                    selected.midpointAge,
                                    selected.grams,
                                    size,
                                  );
                            return Semantics(
                              label: 'Biểu đồ mức tăng cân theo tháng, đơn vị gam trên tháng',
                              child: MouseRegion(
                                onHover: (event) =>
                                    select(event.localPosition, 18),
                                onExit: (_) {
                                  if (_selected != null)
                                    setState(() => _selected = null);
                                },
                                child: GestureDetector(
                                  onTapUp: (event) =>
                                      select(event.localPosition, 36),
                                  onHorizontalDragUpdate: (event) =>
                                      select(event.localPosition, 36),
                                  child: SizedBox(
                                    height: size.height,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned.fill(
                                          child: CustomPaint(painter: painter),
                                        ),
                                        if (at != null)
                                          Positioned(
                                            left: (at.dx - width / 2).clamp(
                                              4,
                                              size.width - width - 4,
                                            ),
                                            bottom: size.height - at.dy + 10,
                                            width: width,
                                            child: IgnorePointer(
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFFE9EDE8,
                                                    ),
                                                  ),
                                                  boxShadow: const [
                                                    BoxShadow(
                                                      color: Color(0x14000000),
                                                      blurRadius: 10,
                                                      offset: Offset(0, 3),
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
                        const SizedBox(height: 4),
                        if (points.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'Chưa đủ dữ liệu trong khoảng đang xem.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: WeightChartColors.data,
                              ),
                            ),
                          ),
                        if (widget.expanded &&
                            reference != null &&
                            points.isNotEmpty)
                          const _VelocityLegend(),
                        if (reference == null && points.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              snapshot.hasError
                                  ? 'Chưa tải được tham chiếu WHO.'
                                  : 'Chưa có dữ liệu tham chiếu phù hợp.',
                              style: const TextStyle(color: growthMuted),
                            ),
                          ),
                        if (snapshot.hasError && points.isNotEmpty)
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
              ],
            ),
          ),
          if (!widget.expanded && summary.latest != null)
            GrowthVelocityAssessment(
              summary: summary,
              readings: widget.readings,
              whoResult:
                  widget.whoResult ??
                  growthVelocityReviewFixture(
                    widget.repository,
                    summary.latest,
                  ),
              easyRead: widget.easyRead,
            ),
        ],
      ),
    );
  }
}

class _VelocityLegend extends StatelessWidget {
  const _VelocityLegend();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Wrap(
      spacing: 16,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        for (final item in [
          ('Mức tăng của bé', WeightChartColors.data, Icons.circle),
          ('Trung vị WHO (0)', WeightChartColors.median, Icons.horizontal_rule),
          ('Mốc −2 / +2', WeightChartColors.sd2, Icons.horizontal_rule),
          ('Mốc −3 / +3', WeightChartColors.sd3, Icons.horizontal_rule),
          ('Vùng −2 đến +2', WeightChartColors.center, Icons.square),
          ('Vùng ngoài đến ±3', WeightChartColors.outer, Icons.square),
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.$3, color: item.$2, size: 16),
              const SizedBox(width: 6),
              Text(
                item.$1,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  color: WeightChartColors.ink,
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

class _VelocityPainter extends CustomPainter {
  _VelocityPainter(
    this.points,
    this.reference,
    this.labelSize,
    this.selected,
    this.ticks,
    this.birth, {
    this.expanded = false,
  });
  final bool expanded;
  double get right => expanded ? math.max(40, labelSize * 2 + 12) : 16;
  final List<int> ticks;
  final DateTime? birth;
  late final List<
    ({double start, double end, double low, double median, double high})
  >
  bands =
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
  late final GrowthVelocityValueAxis valueAxis = growthVelocityValueAxis([
    ...points.map((p) => p.grams),
    ...bands.expand((b) => [b.low, b.high]),
    ...?reference?.standardValues.entries
        .where((e) => e.key >= ticks.first && e.key <= ticks.last)
        .expand((e) => e.value.values),
  ]);
  double get low => valueAxis.min;
  double get high => valueAxis.max;
  late final double left = _measureLeft();
  double _measureLeft() {
    var width = 0.0;
    for (final tick in valueAxis.ticks) {
      final painter = TextPainter(
        text: TextSpan(
          text: tick.round().toString(),
          style: TextStyle(fontFamily: 'Nunito', fontSize: labelSize),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      width = math.max(width, painter.width);
    }
    return math.max(48, width + 12);
  }

  Offset offset(double month, double grams, Size size) => Offset(
    left + fraction(month) * (size.width - left - right),
    20 + (high - grams) / (high - low) * (size.height - 64),
  );
  void label(
    Canvas canvas,
    String value,
    Offset at, {
    bool centered = false,
    bool rightAligned = false,
  }) {
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: labelSize,
          color: WeightChartColors.axis,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset(
        rightAligned
            ? at.dx - text.width
            : centered
            ? at.dx - text.width / 2
            : at.dx,
        at.dy,
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = WeightChartColors.grid
      ..strokeWidth = .7;
    for (final grams in valueAxis.ticks) {
      final y = offset(ticks.first.toDouble(), grams, size).dy;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), grid);
      final text = TextPainter(
        text: TextSpan(
          text: grams.round().toString(),
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: labelSize,
            color: WeightChartColors.axis,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(left - 8 - text.width, y - text.height / 2));
    }
    for (final month in ticks) {
      final at = offset(month.toDouble(), low, size);
      canvas.drawLine(Offset(at.dx, 20), at, grid);
      if (expanded || month != ticks.last)
        label(
          canvas,
          '$month',
          Offset(at.dx, size.height - 36),
          centered: true,
        );
    }
    if (reference != null) {
      canvas.save();
      canvas.clipRect(
        Rect.fromLTRB(left, 20, size.width - right, size.height - 44),
      );
      for (final band in bands) {
        final topLeft = offset(band.start, band.high, size);
        final bottomRight = offset(band.end, band.low, size);
        final center = (topLeft.dx + bottomRight.dx) / 2;
        canvas.drawRect(
          reference!.explicitBands != null
              ? Rect.fromLTRB(
                  center - 5,
                  topLeft.dy,
                  center + 5,
                  bottomRight.dy,
                )
              : Rect.fromPoints(topLeft, bottomRight),
          Paint()..color = WeightChartColors.center,
        );
      }
      for (final band in bands) {
        final at = offset((band.start + band.end) / 2, band.median, size);
        canvas.drawLine(
          reference!.explicitBands != null
              ? at - const Offset(7, 0)
              : offset(band.start, band.median, size),
          reference!.explicitBands != null
              ? at + const Offset(7, 0)
              : offset(band.end, band.median, size),
          Paint()
            ..color = WeightChartColors.median
            ..strokeWidth = 1.8,
        );
      }
      final entries =
          reference!.standardValues.entries
              .where((e) => e.key >= ticks.first && e.key <= ticks.last)
              .toList()
            ..sort((a, b) => a.key.compareTo(b.key));
      for (final entry in entries) {
        final values = entry.value;
        final x = offset(entry.key, 0, size).dx;
        for (final pair in [(-3, -2), (2, 3)]) {
          if (values[pair.$1] != null && values[pair.$2] != null) {
            canvas.drawRect(
              Rect.fromLTRB(
                x - 5,
                offset(entry.key, values[pair.$2]!, size).dy,
                x + 5,
                offset(entry.key, values[pair.$1]!, size).dy,
              ),
              Paint()..color = WeightChartColors.outer,
            );
          }
        }
        for (final sd in [-3, -2, 0, 2, 3]) {
          final value = values[sd];
          if (value == null) continue;
          final color = sd == 0
              ? WeightChartColors.median
              : sd.abs() == 2
              ? WeightChartColors.sd2
              : WeightChartColors.sd3;
          final at = offset(entry.key, value, size);
          canvas.drawLine(
            at - const Offset(7, 0),
            at + const Offset(7, 0),
            Paint()
              ..color = color
              ..strokeWidth = 1.6,
          );
        }
      }
      canvas.restore();
      if (expanded && entries.isNotEmpty) {
        final last = entries.last;
        for (final sd in [-3, -2, 0, 2, 3]) {
          final value = last.value[sd];
          if (value == null) continue;
          final at = offset(last.key, value, size);
          final color = sd == 0
              ? WeightChartColors.median
              : sd.abs() == 2
              ? WeightChartColors.sd2
              : WeightChartColors.sd3;
          final text = TextPainter(
            text: TextSpan(
              text: sd > 0 ? '+$sd' : '$sd',
              style: TextStyle(
                fontSize: labelSize,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          text.paint(canvas, Offset(at.dx + 9, at.dy - text.height / 2));
        }
      }
    }
    final axis = Paint()
      ..color = WeightChartColors.axis.withValues(alpha: .5)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(left, 20), Offset(left, size.height - 44), axis);
    canvas.drawLine(
      Offset(left, size.height - 44),
      Offset(size.width - right, size.height - 44),
      axis,
    );
    label(
      canvas,
      expanded ? 'Mức tăng cân (g)' : 'g',
      Offset(left, 0),
      centered: !expanded,
    );
    label(
      canvas,
      expanded ? 'Tuổi (tháng)' : 'tháng',
      Offset(
        expanded ? math.max(left, size.width - 180) : size.width - 8,
        size.height - (expanded ? 16 : 36),
      ),
      rightAligned: !expanded,
      centered: false,
    );
    // Increments are interval observations, not a continuous growth trajectory.
    for (var i = 0; i < points.length; i++) {
      final at = offset(points[i].midpointAge, points[i].grams, size);
      if (i == selected) {
        for (double y = at.dy; y < size.height - 44; y += 7) {
          canvas.drawLine(
            Offset(at.dx, y),
            Offset(at.dx, math.min(y + 4, size.height - 44)),
            Paint()
              ..color = WeightChartColors.axis.withValues(alpha: .6)
              ..strokeWidth = 1,
          );
        }
        canvas.drawCircle(at, 7, Paint()..color = Colors.white);
        canvas.drawCircle(
          at,
          6,
          Paint()
            ..color = WeightChartColors.data
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
      canvas.drawCircle(
        at,
        i == selected ? 2 : 4,
        Paint()..color = WeightChartColors.data,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VelocityPainter old) => true;
}
