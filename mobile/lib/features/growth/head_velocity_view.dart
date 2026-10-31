import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'growth_repository.dart';
import 'head_insight_sheet.dart';
import 'growth_weight_velocity_axes.dart';
import 'growth_visuals.dart';
import 'head_velocity_data.dart';
import 'weight_chart_view.dart' show GrowthChartLegend;
import 'growth_chart_explanation_dialog.dart';

class HeadVelocityView extends StatefulWidget {
  const HeadVelocityView({
    required this.repository,
    required this.readings,
    this.easyRead = false,
    this.expanded = false,
    this.initialPeriod = 2,
    this.initialEnd = -1,
    super.key,
  });
  final GrowthRepository repository;
  final List<GrowthMeasurementDraft> readings;
  final bool easyRead, expanded;
  final int initialPeriod, initialEnd;
  @override
  State<HeadVelocityView> createState() => _HeadVelocityViewState();
}

class _HeadVelocityViewState extends State<HeadVelocityView> {
  late int period = widget.initialPeriod, ageRange = widget.initialEnd;
  int get end => ageRange == -1
      ? (period <= 3 ? 12 : 24)
      : ageRange == 0
      ? 60
      : ageRange;
  int get start => const {
    -1: 0,
    0: 0,
    3: 0,
    6: 3,
    9: 6,
    12: 9,
    24: 0,
    36: 12,
    60: 36,
  }[ageRange]!;
  int? selected;
  late Future<HeadVelocityReference?> reference = widget.repository
      .headVelocityPeriodReference(period);
  String number(double n) =>
      formatGrowthValue(double.parse(n.toStringAsFixed(2)));
  String signed(double n) => '${n > 0 ? '+' : ''}${number(n)}';
  String date(DateTime d) => '${d.day}/${d.month}/${d.year}';

  void explain(HeadVelocityInterval? p, HeadVelocityReference? ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          HeadInsightSheet(period: period, interval: p, reference: ref),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<HeadVelocityReference?>(
    future: reference,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        );
      }
      final ref = snapshot.data;
      final intervals =
          headVelocityIntervals(
                widget.readings,
                widget.repository.dateOfBirth,
                period,
                ref,
              )
              .where(
                (p) =>
                    (p.start + p.end) / 2 >= start &&
                    (p.start + p.end) / 2 <= end,
              )
              .toList();
      final latest = intervals.lastOrNull;
      final previous = latest == null
          ? null
          : intervals
                .where((p) => (p.end - latest.start).abs() < .001)
                .lastOrNull;
      final delta = previous == null ? null : latest!.gain - previous.gain;
      final rows = (ref?.rows ?? <HeadVelocityRow>[])
          .where(
            (r) =>
                (r.start + r.end) / 2 >= start && (r.start + r.end) / 2 <= end,
          )
          .toList();
      final large =
          widget.easyRead || MediaQuery.textScalerOf(context).scale(14) > 20;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          widget.expanded ? 8 : 20,
          widget.expanded ? 8 : 16,
          widget.expanded ? 8 : 20,
          widget.expanded ? 4 : 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.expanded) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final p in [2, 3, 4, 6])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: TextButton(
                          key: ValueKey('head-period-$p'),
                          style: TextButton.styleFrom(
                            foregroundColor: p == period
                                ? WeightChartColors.positive
                                : WeightChartColors.axis,
                            backgroundColor: p == period
                                ? WeightChartColors.center
                                : Colors.transparent,
                          ),
                          onPressed: () => setState(() {
                            period = p;
                            ageRange = -1;
                            selected = null;
                            reference = widget.repository
                                .headVelocityPeriodReference(p);
                          }),
                          child: Text('$p tháng'),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Mức tăng vòng đầu kỳ gần nhất',
                style: TextStyle(
                  fontFamily: large ? 'Nunito' : 'DancingScript',
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: WeightChartColors.heroInk,
                ),
              ),
              LayoutBuilder(
                builder: (context, c) {
                  final value = Text(
                    latest == null
                        ? 'Chưa đủ số đo'
                        : '${signed(latest.gain)}\u00A0cm',
                    style: TextStyle(
                      fontSize: large ? 40 : 44,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF9468B5),
                    ),
                  );
                  final compare = Text(
                    delta == null
                        ? 'Chưa có dữ liệu so sánh'
                        : delta.abs() < .001
                        ? 'Bằng kỳ trước'
                        : '${delta > 0 ? 'Nhiều hơn' : 'Ít hơn'} ${number(delta.abs())}\u00A0cm\nso với kỳ trước',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: large ? 'Nunito' : 'DancingScript',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF9468B5),
                    ),
                  );
                  return large
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [value, compare],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: value,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(child: compare),
                          ],
                        );
                },
              ),
              const SizedBox(height: 16),
            ],
            Container(
              padding: widget.expanded
                  ? EdgeInsets.zero
                  : const EdgeInsets.all(12),
              decoration: widget.expanded
                  ? null
                  : BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: WeightChartColors.frame),
                      borderRadius: BorderRadius.circular(18),
                    ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: widget.expanded
                        ? WrapAlignment.spaceBetween
                        : WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (!widget.expanded)
                        const SizedBox(
                          width: 54,
                          child: Text(
                            'Theo\ntháng',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: WeightChartColors.axis,
                            ),
                          ),
                        ),
                      IconButton(
                        tooltip: 'Thông tin biểu đồ',
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 40,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () => widget.expanded
                            ? showDialog<void>(
                                context: context,
                                builder: (_) => GrowthChartExplanationDialog(
                                  title: Text(
                                    'Mức tăng vòng đầu · kỳ $period tháng',
                                  ),
                                  content: Text(
                                    'Trục ngang là tuổi (tháng), trục dọc là mức tăng vòng đầu (cm) trong kỳ $period tháng. Điểm tím là mức tăng của bé. Mỗi cột WHO là một kỳ đo riêng với các mốc −3, −2, 0, +2 và +3 SD theo giới tính; không nối thành đường tăng trưởng.\n\nChạm hoặc rê chuột lên điểm để xem số đo đầu kỳ, cuối kỳ và đối chiếu WHO. Ngoài phạm vi chuẩn chỉ ghi nhận số liệu.',
                                  ),
                                  actions: const [],
                                ),
                              )
                            : explain(latest, ref),
                        icon: const Icon(Icons.info_outline, size: 20),
                      ),
                      Container(
                        width: widget.expanded
                            ? math.min(
                                200.0,
                                148 * MediaQuery.textScalerOf(context).scale(1),
                              )
                            : 128,
                        padding: widget.expanded
                            ? const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              )
                            : EdgeInsets.zero,
                        decoration: widget.expanded
                            ? BoxDecoration(
                                border: Border.all(
                                  color: WeightChartColors.frame,
                                ),
                                borderRadius: BorderRadius.circular(24),
                              )
                            : null,
                        child: DropdownButton<int>(
                          isDense: widget.expanded,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            color: WeightChartColors.axis,
                          ),
                          underline: const SizedBox.shrink(),
                          isExpanded: true,
                          value: ageRange,
                          items: [
                            DropdownMenuItem(
                              value: -1,
                              child: Text(
                                period <= 3
                                    ? '0–12 tháng'
                                    : widget.expanded
                                    ? '0–24 tháng'
                                    : '0–24 tháng (WHO)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            DropdownMenuItem(value: 0, child: Text('Toàn bộ')),
                            DropdownMenuItem(
                              value: 3,
                              child: Text('0–3 tháng'),
                            ),
                            DropdownMenuItem(
                              value: 6,
                              child: Text('3–6 tháng'),
                            ),
                            DropdownMenuItem(
                              value: 9,
                              child: Text('6–9 tháng'),
                            ),
                            DropdownMenuItem(
                              value: 12,
                              child: Text('9–12 tháng'),
                            ),
                            DropdownMenuItem(
                              value: 24,
                              child: Text('0–24 tháng'),
                            ),
                            DropdownMenuItem(
                              value: 36,
                              child: Text('1–3 tuổi'),
                            ),
                            DropdownMenuItem(
                              value: 60,
                              child: Text('3–5 tuổi'),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            ageRange = v!;
                            selected = null;
                          }),
                        ),
                      ),
                      if (!widget.expanded)
                        IconButton(
                          tooltip: 'Mở rộng biểu đồ',
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 40,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => Theme(
                                data: Theme.of(context),
                                child: Scaffold(
                                  backgroundColor: Colors.white,
                                  appBar: AppBar(
                                    backgroundColor: Colors.white,
                                    surfaceTintColor: Colors.transparent,
                                    title: Text(
                                      'Mức tăng vòng đầu · kỳ $period tháng',
                                      style: const TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  body: SafeArea(
                                    child: HeadVelocityView(
                                      repository: widget.repository,
                                      readings: widget.readings,
                                      easyRead: widget.easyRead,
                                      expanded: true,
                                      initialPeriod: period,
                                      initialEnd: ageRange,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.open_in_full, size: 18),
                        ),
                    ],
                  ),
                  LayoutBuilder(
                    builder: (context, c) {
                      final size = Size(
                        c.maxWidth,
                        widget.expanded
                            ? math.max(
                                300.0,
                                MediaQuery.sizeOf(context).height * .6,
                              )
                            : 280,
                      );
                      final painter = HeadIncrementPainter(
                        intervals,
                        rows,
                        start.toDouble(),
                        end.toDouble(),
                        selected,
                        MediaQuery.textScalerOf(context).scale(11),
                        widget.expanded,
                      );
                      void select(Offset at) {
                        int? next;
                        var distance = 28.0;
                        for (var i = 0; i < intervals.length; i++) {
                          final d =
                              (painter.point(intervals[i], size) - at).distance;
                          if (d < distance) {
                            next = i;
                            distance = d;
                          }
                        }
                        setState(() => selected = next);
                      }

                      final p = selected != null && selected! < intervals.length
                          ? intervals[selected!]
                          : null;
                      return MouseRegion(
                        onHover: (e) => select(e.localPosition),
                        onExit: (_) => setState(() => selected = null),
                        child: GestureDetector(
                          onTapDown: (e) => select(e.localPosition),
                          child: Stack(
                            children: [
                              Semantics(
                                label:
                                    'Mức tăng vòng đầu (cm) trong kỳ $period tháng; trục ngang tuổi theo tháng.',
                                child: CustomPaint(
                                  size: size,
                                  painter: painter,
                                ),
                              ),
                              if (p != null)
                                Positioned(
                                  top: 8,
                                  left: 40,
                                  right: 8,
                                  child: IgnorePointer(
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(
                                          color: WeightChartColors.frame,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${signed(p.gain)}\u00A0cm · kỳ $period tháng\n${date(p.from.measuredAt)} – ${date(p.to.measuredAt)}${widget.expanded ? '\nĐầu kỳ: ${number(p.from.value)} cm · Cuối kỳ: ${number(p.to.value)} cm' : ''}\n${p.referenceLabel}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  if (snapshot.hasError)
                    TextButton(
                      onPressed: () => setState(
                        () => reference = widget.repository
                            .headVelocityPeriodReference(period),
                      ),
                      child: const Text(
                        'Chưa tải được tham chiếu WHO. Thử lại',
                      ),
                    ),
                  if (ref == null && !snapshot.hasError)
                    const Text('Chưa có tham chiếu WHO đúng giới tính.'),
                  if (widget.expanded)
                    const GrowthChartLegend(
                      key: Key('head-velocity-expanded-legend'),
                      dataColor: Color(0xFF9468B5),
                    ),
                  if (end > (period <= 3 ? 12 : 24))
                    const Text(
                      'WHO có chuẩn vòng đầu kỳ 2/3 tháng đến 12 tháng tuổi, kỳ 4/6 tháng đến 24 tháng. Ngoài phạm vi chỉ ghi nhận mức thay đổi.',
                    ),
                  if (intervals.isEmpty)
                    const Text('Chưa đủ số đo đúng kỳ trong khoảng đang xem.'),
                ],
              ),
            ),
            if (!widget.expanded) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2ECF8),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const GrowthAsset('result-smile-head', size: 48),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Tốc độ vòng đầu của bé thế nào?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF76518F),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      latest == null
                          ? 'Chưa đủ hai số đo phù hợp trong kỳ đang xem.'
                          : latest.gain < 0
                          ? 'Số đo cuối kỳ thấp hơn đầu kỳ; ba mẹ hãy kiểm tra cách đo và đo lại.'
                          : 'Bé tăng ${number(latest.gain)}\u00A0cm trong kỳ $period tháng gần nhất đang xem.${delta == null
                                ? ''
                                : delta.abs() < .001
                                ? ' Mức tăng bằng kỳ liền trước cùng độ dài.'
                                : ' ${delta > 0 ? 'Nhiều' : 'Ít'} hơn ${number(delta.abs())}\u00A0cm so với kỳ liền trước cùng độ dài.'}',
                      style: const TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    if (latest != null)
                      Text(
                        'Đối chiếu WHO: ${latest.referenceLabel}.',
                        style: const TextStyle(height: 1.5),
                      ),
                    Material(
                      color: const Color(0xFFFFFEFA),
                      borderRadius: BorderRadius.circular(18),
                      child: ListTile(
                        title: const Text(
                          'Vì sao có nhận xét này?',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text(
                          'Kết quả của bé và căn cứ đối chiếu WHO',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => explain(latest, ref),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

/// Each reference bar represents one WHO increment interval, not an attained curve.
class HeadIncrementPainter extends CustomPainter {
  HeadIncrementPainter(
    this.intervals,
    this.rows,
    this.start,
    this.end,
    this.selected,
    this.font,
    this.expanded,
  );
  final List<HeadVelocityInterval> intervals;
  final List<HeadVelocityRow> rows;
  final double start, end, font;
  final int? selected;
  final bool expanded;
  late final axis = growthVelocityValueAxis([
    0,
    ...intervals.map((p) => p.gain),
    ...rows.expand((r) => [r.sd.first, r.sd.last]),
  ]);
  double get left => expanded ? math.min(64.0, 34 * font / 11) : 48;
  double get right => expanded ? math.max(32.0, font * 2 + 8) : 20;
  Offset at(double x, double y, Size s) => Offset(
    left + (x - start) / (end - start) * (s.width - left - right),
    20 + (axis.max - y) / (axis.max - axis.min) * (s.height - 64),
  );
  Offset point(HeadVelocityInterval p, Size s) =>
      at((p.start + p.end) / 2, p.gain, s);
  void label(Canvas c, String text, Offset at, {bool center = false}) {
    final t = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: font,
          color: WeightChartColors.axis,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    t.paint(c, Offset(center ? at.dx - t.width / 2 : at.dx, at.dy));
  }

  @override
  void paint(Canvas c, Size s) {
    final grid = Paint()..color = WeightChartColors.grid;
    for (final v in axis.ticks) {
      final p = at(start, v, s);
      c.drawLine(Offset(left, p.dy), Offset(s.width - right, p.dy), grid);
      label(c, formatGrowthValue(v), Offset(4, p.dy - font / 2));
    }
    for (final m in growthVelocityAgeTicks(
      start.toInt(),
      end.toInt(),
      largeText: font > 20,
    )) {
      final p = at(m.toDouble(), axis.min, s);
      c.drawLine(Offset(p.dx, 20), p, grid);
      label(c, '${m.toInt()}', Offset(p.dx, p.dy + 8), center: true);
    }
    label(c, expanded ? 'Mức tăng vòng đầu (cm)' : 'cm', Offset(left, 0));
    label(
      c,
      expanded ? 'Tuổi (tháng)' : 'tháng',
      expanded
          ? Offset((left + s.width - right) / 2, s.height - 16)
          : Offset(s.width - 48, s.height - 16),
      center: expanded,
    );
    c.save();
    c.clipRect(Rect.fromLTRB(left, 20, s.width - right, s.height - 44));
    for (final r in rows) {
      final x = (r.start + r.end) / 2;
      final center = at(x, 0, s).dx;
      for (final band in [
        (0, 1, WeightChartColors.outer),
        (1, 5, WeightChartColors.center),
        (5, 6, WeightChartColors.outer),
      ]) {
        c.drawRect(
          Rect.fromLTRB(
            center - 5,
            at(x, r.sd[band.$2], s).dy,
            center + 5,
            at(x, r.sd[band.$1], s).dy,
          ),
          Paint()..color = band.$3,
        );
      }
      for (final sd in [-3, -2, 0, 2, 3]) {
        final p = at(x, r.sd[sd + 3], s);
        c.drawLine(
          p - const Offset(7, 0),
          p + const Offset(7, 0),
          Paint()
            ..color = sd == 0
                ? WeightChartColors.median
                : sd.abs() == 2
                ? WeightChartColors.sd2
                : WeightChartColors.sd3
            ..strokeWidth = 1.6,
        );
      }
    }
    for (var i = 0; i < intervals.length; i++) {
      final p = point(intervals[i], s);
      c.drawCircle(
        p,
        i == selected ? 7 : 4,
        Paint()..color = Color(0xFF9468B5),
      );
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant HeadIncrementPainter old) => true;
}
