import 'growth_classification_labels.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'growth_chart_explanation_dialog.dart';

typedef WeightDatum = ({double x, double kg, DateTime date, double? z});
typedef WeightCurve = ({double x, List<double> kg});

const weightAgeRanges = <int, ({int start, int end})>{
  0: (start: 0, end: 60),
  3: (start: 0, end: 4),
  6: (start: 4, end: 7),
  9: (start: 7, end: 10),
  12: (start: 10, end: 13),
  36: (start: 12, end: 48),
  60: (start: 48, end: 60),
};

// WHO's average month is used only for tick placement; readings retain exact days.
double weightAgeTick(int month) =>
    math.min(1826, (month * 30.4375).round()).toDouble();
List<double> weightAgeTicks(int start, int end) {
  final step = end <= 13
      ? 1
      : end - start <= 36
      ? 6
      : 12;
  return [for (var m = start; m <= end; m += step) m.toDouble()];
}

({double min, double max, double step}) weightValueAxis(
  Iterable<double> values,
) {
  final data = values.where((v) => v.isFinite && v > 0).toList();
  if (data.isEmpty) return (min: 0, max: 5, step: 1);
  final min = data.reduce(math.min), max = data.reduce(math.max);
  final pad = math.max(.5, (max - min) * .08);
  final span = math.max(3.0, max - min + 2 * pad);
  final step = [
    1.0,
    2.0,
    5.0,
    10.0,
    20.0,
    50.0,
    100.0,
  ].firstWhere((s) => span / s <= 6, orElse: () => (span / 5).ceilToDouble());
  return (
    min: math.max(0, ((min - pad) / step).floor() * step),
    max: ((max + pad) / step).ceil() * step,
    step: step,
  );
}

String _number(double n) => n.toStringAsFixed(n == n.roundToDouble() ? 0 : 1);

class WeightChartView extends StatefulWidget {
  const WeightChartView({
    super.key,
    required this.title,
    required this.points,
    required this.curves,
    this.age = true,
    this.start = 0,
    this.end = 60,
    this.expanded = false,
    this.birth,
    this.classificationForDate,
    this.initialStart,
    this.initialEnd,
    this.initialRadius = 0,
    this.unit = 'kg',
    this.metricName = 'Cân nặng',
    this.breakAt,
    this.dataColor = WeightChartColors.data,
    this.explanation,
  });
  final double? initialStart, initialEnd;
  final int initialRadius;
  final DateTime? birth;
  final String? Function(DateTime)? classificationForDate;
  final String title;
  final String unit, metricName;
  final Color dataColor;
  final String? explanation;
  final double? breakAt;
  final List<WeightDatum> points;
  final List<WeightCurve> curves;
  final bool age, expanded;
  final double start, end;
  @override
  State<WeightChartView> createState() => _WeightChartViewState();
}

class _WeightChartViewState extends State<WeightChartView> {
  String get shortTitle =>
      widget.title == 'Chiều dài/chiều cao theo tuổi' ||
          widget.metricName == 'Vòng đầu' || widget.metricName == 'BMI'
      ? 'Theo tuổi'
      : widget.title.replaceFirst('Cân nặng theo ', 'Theo ');
  int? selected;
  late int radius = widget.initialRadius;
  late double start = widget.initialStart ?? widget.start,
      end = widget.initialEnd ?? widget.end;
  @override
  void didUpdateWidget(covariant WeightChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.start != widget.start || oldWidget.end != widget.end) {
      start = widget.start;
      end = widget.end;
      selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final xMin = widget.age ? weightAgeTick(start.toInt()) : start;
    final xMax = widget.age ? weightAgeTick(end.toInt()) : end;
    final points =
        widget.points.where((p) => p.x >= xMin && p.x <= xMax).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final curves =
        widget.curves.where((p) => p.x >= xMin && p.x <= xMax).toList()..sort(
          (a, b) =>
              a.x == b.x ? b.kg[2].compareTo(a.kg[2]) : a.x.compareTo(b.x),
        );
    final axis = weightValueAxis([
      ...points.map((p) => p.kg),
      ...curves.expand((p) => [p.kg.first, p.kg.last]),
    ]);
    final ticks = widget.age
        ? weightAgeTicks(start.toInt(), end.toInt())
        : ({
            for (var i = 0; i <= 4; i++)
              (start + (end - start) * i / 4).roundToDouble(),
          }.where((v) => v >= start && v <= end).toList()..sort());
    final chart = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  if (!widget.expanded)
                    Flexible(
                      child: Text(
                        shortTitle,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: MediaQuery.sizeOf(context).width < 400
                              ? 16
                              : 20,
                          fontWeight: FontWeight.w800,
                          color: WeightChartColors.axis,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Thông tin biểu đồ',
                    icon: const Icon(
                      Icons.info_outline,
                      size: 20,
                      color: WeightChartColors.axis,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 48,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => GrowthChartExplanationDialog(
                        title: Text(widget.title),
                        content: Text(
                          widget.explanation ??
                          '${widget.age ? 'Trục ngang là tuổi (tháng)' : 'Trục ngang là chiều dài/chiều cao (cm)'}, trục dọc là ${widget.metricName.toLowerCase()} (${widget.unit}). Đường ${widget.metricName == 'Vòng đầu'
                              ? 'tím'
                              : widget.unit == 'cm'
                              ? 'xanh dương'
                              : 'cam'} nối các số đo của bé.\n\nNăm đường chuẩn WHO tương ứng với −3, −2, 0, +2 và +3 theo giới tính. Đường xanh lá ở giữa là trung vị.\n\n${widget.metricName == 'Vòng đầu'
                              ? 'WHO 2007: vòng đầu theo tuổi từ sơ sinh đến 60 tháng, riêng theo giới tính. Đo bằng thước dây; không có chuyển tiếp tư thế hoặc quy đổi 0,7 cm. Tuổi được định vị theo ngày, nhãn tháng dùng 30,4375 ngày/tháng.'
                              : widget.unit == 'cm'
                              ? 'Dưới 24 tháng dùng chiều dài nằm; từ 24 tháng dùng chiều cao đứng. Hai chuẩn chênh nhau 0,7 cm tại điểm chuyển tiếp; không nối qua điểm chuyển tiếp. Số đo khác tư thế được quy đổi 0,7 cm khi đủ thông tin cách đo.'
                              : widget.age
                              ? 'Tuổi được định vị theo ngày; nhãn tháng dùng 30,4375 ngày/tháng theo quy ước WHO.'
                              : 'Cân nặng và chiều dài/chiều cao cần được đo cùng ngày.'}\n\nChạm vào điểm đo để xem chi tiết. Vùng màu hỗ trợ đối chiếu, không thay thế kết quả đánh giá của bé.',
                        ),
                        actions: const [],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: widget.age ? 104 : 90,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: WeightChartColors.frame),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: DropdownButtonHideUnderline(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.age)
                          DropdownButton<int>(
                            isExpanded: true,
                            isDense: true,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 13,
                              color: WeightChartColors.axis,
                            ),
                            value:
                                weightAgeRanges.entries
                                    .where(
                                      (e) =>
                                          e.value.start == start &&
                                          e.value.end == end,
                                    )
                                    .firstOrNull
                                    ?.key ??
                                0,
                            items: const [
                              DropdownMenuItem(
                                value: 0,
                                child: Text('Toàn bộ'),
                              ),
                              DropdownMenuItem(
                                value: 3,
                                child: Text('0–3 tháng'),
                              ),
                              DropdownMenuItem(
                                value: 6,
                                child: Text('4–6 tháng'),
                              ),
                              DropdownMenuItem(
                                value: 9,
                                child: Text('7–9 tháng'),
                              ),
                              DropdownMenuItem(
                                value: 12,
                                child: Text('10–12 tháng'),
                              ),
                              DropdownMenuItem(
                                value: 36,
                                child: Text('1–3 tuổi'),
                              ),
                              DropdownMenuItem(
                                value: 60,
                                child: Text('4–5 tuổi'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  start = weightAgeRanges[v]!.start.toDouble();
                                  end = weightAgeRanges[v]!.end.toDouble();
                                  selected = null;
                                });
                              }
                            },
                          ),
                        if (!widget.age)
                          DropdownButton<int>(
                            isExpanded: true,
                            isDense: true,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 13,
                              color: WeightChartColors.axis,
                            ),
                            value: radius,
                            items: const [
                              DropdownMenuItem(
                                value: 0,
                                child: Text('Toàn bộ'),
                              ),
                              DropdownMenuItem(value: 5, child: Text('±5 cm')),
                              DropdownMenuItem(
                                value: 10,
                                child: Text('±10 cm'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  radius = v;
                                  final center = widget.points.isEmpty
                                      ? (widget.start + widget.end) / 2
                                      : (widget.points.toList()..sort(
                                              (a, b) =>
                                                  a.date.compareTo(b.date),
                                            ))
                                            .last
                                            .x;
                                  start = v == 0
                                      ? widget.start
                                      : math.max(widget.start, center - v);
                                  end = v == 0
                                      ? widget.end
                                      : math.min(widget.end, center + v);
                                  selected = null;
                                });
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!widget.expanded)
              IconButton(
                tooltip: 'Phóng to biểu đồ',
                icon: const Icon(
                  Icons.fullscreen,
                  size: 26,
                  color: WeightChartColors.axis,
                ),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 48),
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      backgroundColor: Colors.white,
                      appBar: AppBar(
                        backgroundColor: Colors.white,
                        title: Text(
                          widget.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      body: SafeArea(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(8),
                          child: WeightChartView(
                            title: widget.title,
                            unit: widget.unit,
                            metricName: widget.metricName,
                            explanation: widget.explanation,
                            breakAt: widget.breakAt,
                            dataColor: widget.dataColor,
                            points: widget.points,
                            curves: widget.curves,
                            age: widget.age,
                            start: widget.start,
                            end: widget.end,
                            initialStart: start,
                            initialEnd: end,
                            initialRadius: radius,
                            birth: widget.birth,
                            classificationForDate: widget.classificationForDate,
                            expanded: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        LayoutBuilder(
          builder: (context, c) {
            final height = widget.expanded
                ? math.max(300.0, MediaQuery.sizeOf(context).height * .6)
                : (c.maxWidth * .50).clamp(250.0, 340.0);
            final size = Size(c.maxWidth, height);
            final left = math.min(
              64.0,
              34 * MediaQuery.textScalerOf(context).scale(1),
            );
            final right = widget.expanded
                ? math.max(
                    32.0,
                    MediaQuery.textScalerOf(context).scale(11) * 2 + 8,
                  )
                : 16.0;
            Offset at(double x, double y) => Offset(
              left + (x - xMin) / (xMax - xMin) * (size.width - left - right),
              20 + (axis.max - y) / (axis.max - axis.min) * (size.height - 62),
            );
            void select(Offset position, {double hitRadius = 32}) {
              int? closest;
              var distance = hitRadius;
              for (var i = 0; i < points.length; i++) {
                final d = (at(points[i].x, points[i].kg) - position).distance;
                if (d < distance) {
                  distance = d;
                  closest = i;
                }
              }
              if (selected != closest) setState(() => selected = closest);
            }

            final p = selected != null && selected! < points.length
                ? points[selected!]
                : null;
            final popupWidth = math.min(
              widget.expanded ? 220.0 : 185.0,
              size.width - 16,
            );
            final anchor = p == null ? Offset.zero : at(p.x, p.kg);
            return Semantics(
              label:
                  '${widget.title}. Trục ngang ${widget.age ? 'tuổi' : 'chiều dài/chiều cao'}, trục dọc ${widget.metricName} ${widget.unit}.',
              child: MouseRegion(
                onHover: (event) => select(event.localPosition, hitRadius: 18),
                onExit: (_) {
                  if (selected != null) setState(() => selected = null);
                },
                child: GestureDetector(
                  onTapUp: (d) => select(d.localPosition),
                  onHorizontalDragUpdate: (d) => select(d.localPosition),
                  child: SizedBox(
                    height: height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _WeightPainter(
                              points,
                              curves,
                              axis,
                              ticks,
                              widget.age,
                              widget.expanded,
                              at,
                              left,
                              p,
                              MediaQuery.textScalerOf(context).scale(11),
                              widget.unit,
                              widget.metricName,
                              widget.breakAt,
                              widget.dataColor,
                            ),
                          ),
                        ),
                        if (p != null)
                          Positioned(
                            left: (anchor.dx - popupWidth / 2).clamp(
                              8.0,
                              size.width - popupWidth - 8,
                            ),
                            width: popupWidth,
                            bottom: height - anchor.dy + 10,
                            child: IgnorePointer(
                              child: _WeightPointPopover(
                                point: p,
                                age: widget.age,
                                detailed: widget.expanded,
                                unit: widget.unit,
                                birth: widget.birth,
                                classification: widget.classificationForDate
                                    ?.call(p.date),
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
        if (widget.expanded)
          GrowthChartLegend(
            key: const Key('weight-chart-legend'),
            dataColor: widget.dataColor,
          ),
        if (curves.isEmpty)
          const Text('Chưa có dữ liệu tham chiếu WHO cho khoảng này.'),
        if (points.isEmpty) const Text('Chưa có số đo trong khoảng đang xem.'),
      ],
    );
    if (widget.expanded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: chart,
      );
    }
    return Container(
      padding: EdgeInsets.fromLTRB(
        widget.expanded ? 8 : 12,
        8,
        widget.expanded ? 8 : 12,
        4,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: WeightChartColors.frame),
        borderRadius: BorderRadius.circular(18),
      ),
      child: chart,
    );
  }
}

class _WeightPointPopover extends StatelessWidget {
  const _WeightPointPopover({
    required this.point,
    required this.age,
    required this.detailed,
    this.birth,
    this.classification,
    this.unit = 'kg',
  });
  final String unit;
  final WeightDatum point;
  final bool age;
  final bool detailed;
  final DateTime? birth;
  final String? classification;
  @override
  Widget build(BuildContext context) {
    final date = point.date;
    final ageDays = birth == null
        ? null
        : DateTime.utc(date.year, date.month, date.day)
              .difference(DateTime.utc(birth!.year, birth!.month, birth!.day))
              .inDays;
    final validZ = point.z != null && point.z!.isFinite;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('weight-point-popover'),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: WeightChartColors.frame),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 12,
            color: WeightChartColors.ink,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${point.kg.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')} $unit',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                validZ
                    ? 'Z-score: ${point.z!.toStringAsFixed(2)}'
                    : 'Z-score: Chưa có dữ liệu',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (validZ && classification != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: weightClassificationColor(classification)
                          .withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: weightClassificationColor(classification)
                            .withValues(alpha: .25),
                      ),
                    ),
                    child: Text(
                      classification!,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: weightClassificationColor(classification),
                      ),
                    ),
                  ),
                ),
              if (detailed && (!validZ || classification == null))
                const Text('Chưa đủ dữ liệu phân loại'),
              const SizedBox(height: 4),
              if (detailed)
                Text('Ngày đo: ${date.day}/${date.month}/${date.year}'),
              if (age || detailed)
                Text(
                  ageDays == null
                      ? (age
                            ? 'Tuổi: ${_number(point.x / 30.4375)} tháng'
                            : 'Tuổi: Chưa có ngày sinh')
                      : 'Tuổi: $ageDays ngày',
                ),
              if (!age)
                Text(
                  '${detailed ? 'Chiều dài/chiều cao: ' : ''}${_number(point.x)} cm',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Display colors use explicit assessment labels/codes, never chart position or Z.
Color weightClassificationColor(String? classification) =>
    switch ((growthClassificationCodeForLabel(classification) ?? classification)
        ?.trim()
        .toLowerCase()) {
      'within_range' ||
      'trong khoảng tham chiếu' ||
      'phù hợp' ||
      'phù hợp với tuổi' ||
      'cân đối' ||
      'cân đối với chiều dài' ||
      'cân đối với chiều cao' => WeightChartColors.positive,
      'severe_underweight' ||
      'severe_stunting' ||
      'severe_wasting' ||
      'obesity' ||
      'nhẹ cân mức độ nặng' ||
      'nhẹ cân nặng' ||
      'gầy còm nặng' ||
      'gầy còm mức độ nặng' ||
      'béo phì theo chỉ số nhân trắc' ||
      'béo phì' => WeightChartColors.critical,
      'underweight' ||
      'stunting' ||
      'very_tall' ||
      'wasting' ||
      'risk_overweight' ||
      'overweight' ||
      'high_wfa' ||
      'nhẹ cân' ||
      'gầy còm' ||
      'nguy cơ thừa cân' ||
      'có nguy cơ thừa cân' ||
      'thừa cân' ||
      'cân nặng theo tuổi cao' => WeightChartColors.attention,
      _ => WeightChartColors.unknown,
    };

class GrowthChartLegend extends StatelessWidget {
  const GrowthChartLegend({super.key, this.dataColor = WeightChartColors.data});
  final Color dataColor;
  Widget item(
    String title,
    Color color, {
    bool point = false,
    bool band = false,
  }) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 28,
        height: 20,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 26,
                height: band
                    ? 12
                    : point
                    ? 3
                    : 2,
                color: color,
              ),
              if (point)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        title,
        style: const TextStyle(
          fontFamily: 'Nunito',
          color: WeightChartColors.ink,
          fontSize: 12,
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        item('Số đo của bé', dataColor, point: true),
        item('Trung vị WHO (0)', WeightChartColors.median),
        item('Đường −2 / +2', WeightChartColors.sd2),
        item('Đường −3 / +3', WeightChartColors.sd3),
        item('Vùng −2 đến +2', WeightChartColors.center, band: true),
        item('Vùng ngoài đến ±3', WeightChartColors.outer, band: true),
      ],
    ),
  );
}

class _WeightPainter extends CustomPainter {
  _WeightPainter(
    this.points,
    this.curves,
    this.axis,
    this.ticks,
    this.age,
    this.expanded,
    this.at,
    this.left,
    this.selected,
    this.font,
    this.unit,
    this.metricName,
    this.breakAt,
    this.dataColor,
  );
  final List<WeightDatum> points;
  final List<WeightCurve> curves;
  final ({double min, double max, double step}) axis;
  final List<double> ticks;
  final bool age, expanded;
  final Offset Function(double, double) at;
  final double left, font;
  final String unit, metricName;
  final double? breakAt;
  final Color dataColor;
  final WeightDatum? selected;
  void label(
    Canvas c,
    String t,
    Offset p, {
    bool rightAligned = false,
    bool centered = false,
    Color? color,
  }) {
    final text = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: font,
          color: color ?? WeightChartColors.axis,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      c,
      rightAligned
          ? Offset(p.dx - text.width, p.dy)
          : centered
          ? Offset(p.dx - text.width / 2, p.dy)
          : p,
    );
  }

  @override
  void paint(Canvas c, Size s) {
    final grid = Paint()..color = WeightChartColors.grid;
    final plotRight =
        s.width - (expanded ? math.max(32.0, font * 2 + 8) : 16.0);
    final bottom = at(
      age ? weightAgeTick(ticks.first.toInt()) : ticks.first,
      axis.min,
    );
    final origin = Offset(left, bottom.dy);
    final axes = Paint()
      ..color = WeightChartColors.axis.withValues(alpha: .5)
      ..strokeWidth = 1;
    c.drawLine(Offset(left, 20), origin, axes);
    c.drawLine(origin, Offset(plotRight, origin.dy), axes);
    for (double y = axis.min; y <= axis.max + .001; y += axis.step) {
      final p = at(age ? weightAgeTick(ticks.first.toInt()) : ticks.first, y);
      c.drawLine(Offset(left, p.dy), Offset(plotRight, p.dy), grid);
      // Include the font's top bearing so the visible Y gap matches the X gap.
      label(
        c,
        y.toStringAsFixed(0),
        Offset(left - 8 - font * .2, p.dy - font / 2),
        rightAligned: true,
      );
    }
    for (final t in ticks) {
      final p = at(age ? weightAgeTick(t.toInt()) : t, axis.min);
      c.drawLine(Offset(p.dx, 20), p, grid);
      if (expanded || t != ticks.last) {
        label(c, t.toStringAsFixed(0), Offset(p.dx, p.dy + 8), centered: true);
      }
    }
    label(c, expanded ? '$metricName ($unit)' : unit, Offset(left, 0));
    label(
      c,
      expanded
          ? (age ? 'Tuổi (tháng)' : 'Chiều dài/chiều cao (cm)')
          : (age ? 'tháng' : 'cm'),
      expanded
          ? Offset(s.width - 180, s.height - 16)
          : Offset(s.width - 8, origin.dy + 8),
      rightAligned: !expanded,
    );
    if (curves.isNotEmpty) {
      bool startsSegment(int i) =>
          i == 0 ||
          curves[i].x <= curves[i - 1].x ||
          (breakAt != null &&
              curves[i - 1].x < breakAt! &&
              curves[i].x >= breakAt! &&
              !(i + 1 < curves.length && curves[i + 1].x == curves[i].x));
      final segments = <List<WeightCurve>>[];
      for (var i = 0; i < curves.length; i++) {
        if (startsSegment(i)) {
          segments.add([]);
        }
        segments.last.add(curves[i]);
      }
      void band(int lo, int hi, Color color) {
        for (final segment in segments) {
          final path = Path();
          for (var i = 0; i < segment.length; i++) {
            final p = at(segment[i].x, segment[i].kg[lo]);
            if (i == 0) {
              path.moveTo(p.dx, p.dy);
            } else {
              path.lineTo(p.dx, p.dy);
            }
          }
          for (final row in segment.reversed) {
            final p = at(row.x, row.kg[hi]);
            path.lineTo(p.dx, p.dy);
          }
          path.close();
          c.drawPath(path, Paint()..color = color);
        }
      }

      band(0, 1, WeightChartColors.outer);
      band(1, 3, WeightChartColors.center);
      band(3, 4, WeightChartColors.outer);
      for (var j = 0; j < 5; j++) {
        final path = Path();
        for (var i = 0; i < curves.length; i++) {
          final p = at(curves[i].x, curves[i].kg[j]);
          if (startsSegment(i)) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
        }
        c.drawPath(
          path,
          Paint()
            ..color = [
              WeightChartColors.sd3,
              WeightChartColors.sd2,
              WeightChartColors.median,
              WeightChartColors.sd2,
              WeightChartColors.sd3,
            ][j]
            ..strokeWidth = (j == 2 ? 1.8 : 1)
            ..style = PaintingStyle.stroke,
        );
        if (expanded) {
          final p = at(curves.last.x, curves.last.kg[j]);
          label(
            c,
            ['−3', '−2', '0', '+2', '+3'][j],
            Offset(p.dx + 6, p.dy - font / 2),
            color: [
              WeightChartColors.sd3,
              WeightChartColors.sd2,
              WeightChartColors.median,
              WeightChartColors.sd2,
              WeightChartColors.sd3,
            ][j],
          );
        }
      }
    }
    // WFL/WFH is a scatter: do not invent a trajectory by sorting stature.
    if (age && points.length > 1) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final p = at(points[i].x, points[i].kg);
        if (i == 0 ||
            (breakAt != null &&
                points[i - 1].x < breakAt! &&
                points[i].x >= breakAt!)) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      c.drawPath(
        path,
        Paint()
          ..color = dataColor
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke,
      );
    }
    for (final p in points) {
      final o = at(p.x, p.kg);
      if (p == selected) {
        for (double y = o.dy; y < origin.dy; y += 7) {
          c.drawLine(
            Offset(o.dx, y),
            Offset(o.dx, math.min(y + 4, origin.dy)),
            Paint()
              ..color = WeightChartColors.axis.withValues(alpha: .6)
              ..strokeWidth = 1,
          );
        }
        c.drawCircle(o, 7, Paint()..color = Colors.white);
        c.drawCircle(
          o,
          6,
          Paint()
            ..color = dataColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
      c.drawCircle(o, p == selected ? 2 : 4, Paint()..color = dataColor);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightPainter oldDelegate) => true;
}
