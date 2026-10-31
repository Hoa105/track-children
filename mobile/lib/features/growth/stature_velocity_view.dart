import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'growth_repository.dart';
import 'stature_insight_sheet.dart';
import 'growth_weight_velocity_axes.dart';
import 'growth_visuals.dart';
import 'stature_velocity_data.dart';
import 'weight_chart_view.dart' show GrowthChartLegend, weightAgeTicks;
import 'growth_chart_explanation_dialog.dart';

class StatureVelocityView extends StatefulWidget {
  const StatureVelocityView({
    required this.repository,
    required this.readings,
    this.easyRead = false,
    this.expanded = false,
    this.initialPeriod = 2,
    this.initialEnd = 24,
    super.key,
  });
  final GrowthRepository repository;
  final List<GrowthMeasurementDraft> readings;
  final bool easyRead, expanded;
  final int initialPeriod, initialEnd;
  @override
  State<StatureVelocityView> createState() => _StatureVelocityViewState();
}

class _StatureVelocityViewState extends State<StatureVelocityView> {
  late int period = widget.initialPeriod, ageRange = widget.initialEnd;
  int get end => ageRange == 0 ? 60 : ageRange;
  int get start =>
      const {0: 0, 3: 0, 6: 3, 9: 6, 12: 9, 24: 0, 36: 12, 60: 36}[ageRange]!;
  int? selected;
  late Future<StatureVelocityReference?> reference = widget.repository
      .statureVelocityPeriodReference(period);
  String number(double n) =>
      formatGrowthValue(double.parse(n.toStringAsFixed(2)));
  String signed(double n) => '${n > 0 ? '+' : ''}${number(n)}';
  String date(DateTime d) => '${d.day}/${d.month}/${d.year}';

  void explain(StatureVelocityInterval? p, StatureVelocityReference? ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          StatureInsightSheet(period: period, interval: p, reference: ref),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<StatureVelocityReference?>(
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
          statureVelocityIntervals(
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
      final rows = (ref?.rows ?? <StatureVelocityRow>[])
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
          16,
          widget.expanded ? 8 : 20,
          32,
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
                          key: ValueKey('stature-period-$p'),
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
                            selected = null;
                            reference = widget.repository
                                .statureVelocityPeriodReference(p);
                          }),
                          child: Text('$p tháng'),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Mức tăng chiều dài/chiều cao kỳ gần nhất',
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
                      color: StatureChartColors.data,
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
              padding: const EdgeInsets.all(12),
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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final controls = <Widget>[
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
                            maxWidth: 40,
                            minHeight: 40,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: () => widget.expanded
                              ? showDialog<void>(
                                  context: context,
                                  builder: (_) => GrowthChartExplanationDialog(
                                    title: Text(
                                      'Mức tăng chiều dài · kỳ $period tháng',
                                    ),
                                    content: const Text(
                                      'Trục ngang là tuổi (tháng), trục dọc là mức tăng chiều dài/chiều cao (cm) trong kỳ. Điểm xanh dương là mức tăng của bé. Mỗi cột tham chiếu WHO là một kỳ đo riêng; không nối thành đường tăng trưởng. Các mốc −3, −2, 0, +2 và +3 SD theo đúng giới tính và kỳ đo.\n\nChạm hoặc rê chuột lên điểm để xem số đo đầu kỳ, cuối kỳ và Z-score. Ngoài phạm vi chuẩn chỉ ghi nhận số liệu.',
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
                                  160.0,
                                  96 *
                                      MediaQuery.textScalerOf(context).scale(1),
                                )
                              : 88,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: WeightChartColors.frame),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: DropdownButton<int>(
                            isDense: true,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 13,
                              color: WeightChartColors.axis,
                            ),
                            underline: const SizedBox.shrink(),
                            isExpanded: true,
                            value: ageRange,
                            selectedItemBuilder: (_) => const [
                              Align(alignment: Alignment.centerLeft, child: Text('Toàn bộ')),
                              Align(alignment: Alignment.centerLeft, child: Text('0–3')),
                              Align(alignment: Alignment.centerLeft, child: Text('3–6')),
                              Align(alignment: Alignment.centerLeft, child: Text('6–9')),
                              Align(alignment: Alignment.centerLeft, child: Text('9–12')),
                              Align(alignment: Alignment.centerLeft, child: Text('0–24')),
                              Align(alignment: Alignment.centerLeft, child: Text('1–3 tuổi')),
                              Align(alignment: Alignment.centerLeft, child: Text('3–5 tuổi')),
                            ],
                            items: const [
                              DropdownMenuItem(
                                value: 0,
                                child: Text('Toàn bộ'),
                              ),
                              DropdownMenuItem(value: 3, child: Text('0–3 tháng')),
                              DropdownMenuItem(value: 6, child: Text('3–6 tháng')),
                              DropdownMenuItem(value: 9, child: Text('6–9 tháng')),
                              DropdownMenuItem(value: 12, child: Text('9–12 tháng')),
                              DropdownMenuItem(value: 24, child: Text('0–24 tháng')),
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
                              maxWidth: 40,
                              minHeight: 40,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(
                                    backgroundColor: Colors.white,
                                    surfaceTintColor: Colors.transparent,
                                    title: Text(
                                      'Mức tăng chiều dài · kỳ $period tháng',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  backgroundColor: Colors.white,
                                  body: SafeArea(
                                    child: StatureVelocityView(
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
                            icon: const Icon(
                              Icons.fullscreen,
                              size: 26,
                              color: WeightChartColors.axis,
                            ),
                          ),
                      ];
                      return widget.expanded
                          ? Row(
                              children: [
                                controls[0],
                                const Spacer(),
                                controls[1],
                              ],
                            )
                          : Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                controls[0],
                                controls[1],
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    controls[2],
                                    const SizedBox(width: 4),
                                    controls[3],
                                  ],
                                ),
                              ],
                            );
                    },
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
                      final painter = StatureIncrementPainter(
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
                      final popupWidth = math.min(
                        widget.expanded ? 220.0 : 185.0,
                        size.width - 16,
                      );
                      final anchor = p == null
                          ? Offset.zero
                          : painter.point(p, size);
                      return MouseRegion(
                        onHover: (e) => select(e.localPosition),
                        onExit: (_) => setState(() => selected = null),
                        child: GestureDetector(
                          onTapDown: (e) => select(e.localPosition),
                          onHorizontalDragUpdate: (e) =>
                              select(e.localPosition),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Semantics(
                                label:
                                    'Mức tăng chiều dài/chiều cao (cm) trong kỳ $period tháng; trục ngang tuổi theo tháng.',
                                child: CustomPaint(
                                  size: size,
                                  painter: painter,
                                ),
                              ),
                              if (p != null)
                                Positioned(
                                  bottom: size.height - anchor.dy + 10,
                                  left: (anchor.dx - popupWidth / 2).clamp(
                                    8.0,
                                    size.width - popupWidth - 8,
                                  ),
                                  width: popupWidth,
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
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${signed(p.gain)}\u00A0cm',
                                            style: const TextStyle(
                                              fontFamily: 'Nunito',
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                              color: StatureChartColors.data,
                                            ),
                                          ),
                                          Text(
                                            p.gain < 0
                                                ? 'Cần kiểm tra lại số đo'
                                                : p.z == null
                                                ? 'Chỉ ghi nhận — chưa có đối chiếu WHO phù hợp'
                                                : 'Z-score: ${number(p.z!)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            '${date(p.from.measuredAt)} – ${date(p.to.measuredAt)}',
                                          ),
                                          if (widget.expanded) ...[
                                            Text('Chu kỳ: $period tháng'),
                                            Text(
                                              'Đầu kỳ: ${number(p.from.value)}\u00A0cm',
                                            ),
                                            Text(
                                              'Cuối kỳ: ${number(p.to.value)}\u00A0cm',
                                            ),
                                          ],
                                        ],
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
                            .statureVelocityPeriodReference(period),
                      ),
                      child: const Text(
                        'Chưa tải được tham chiếu WHO. Thử lại',
                      ),
                    ),
                  if (ref == null && !snapshot.hasError)
                    const Text('Chưa có tham chiếu WHO đúng giới tính.'),
                  if (widget.expanded)
                    const GrowthChartLegend(
                      key: Key('stature-velocity-expanded-legend'),
                      dataColor: StatureChartColors.data,
                    ),
                  if (end > 24)
                    const Text(
                      'WHO không có chuẩn tốc độ chiều cao đứng 2–5 tuổi trong bộ tài liệu này. Biểu đồ chỉ ghi nhận mức thay đổi.',
                    ),
                  if (intervals.isEmpty)
                    const Text(
                      'Chưa đủ số đo cùng cách đo và đúng kỳ trong khoảng đang xem.',
                    ),
                ],
              ),
            ),
            if (!widget.expanded) ...[
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
                        const Expanded(
                          child: Text(
                            'Tốc độ chiều dài/chiều cao của bé thế nào?',
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
class StatureIncrementPainter extends CustomPainter {
  StatureIncrementPainter(
    this.intervals,
    this.rows,
    this.start,
    this.end,
    this.selected,
    this.font,
    this.expanded,
  );
  final List<StatureVelocityInterval> intervals;
  final List<StatureVelocityRow> rows;
  final double start, end, font;
  final int? selected;
  final bool expanded;
  double get left => expanded ? math.min(64.0, 34 * font / 11) : 48;
  double get right => expanded ? math.max(32.0, font * 2 + 8) : 20;
  late final axis = growthVelocityValueAxis([
    0,
    ...intervals.map((p) => p.gain),
    ...rows.expand((r) => [r.sd.first, r.sd.last]),
  ]);
  Offset at(double x, double y, Size s) => Offset(
    left + (x - start) / (end - start) * (s.width - left - right),
    20 + (axis.max - y) / (axis.max - axis.min) * (s.height - 64),
  );
  Offset point(StatureVelocityInterval p, Size s) =>
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
    final ticks = expanded
        ? weightAgeTicks(
            start.toInt(),
            end.toInt(),
          ).map((m) => m.toInt()).toList()
        : growthVelocityAgeTicks(
            start.toInt(),
            end.toInt(),
            largeText: font > 20,
          );
    for (final m in ticks) {
      final p = at(m.toDouble(), axis.min, s);
      c.drawLine(Offset(p.dx, 20), p, grid);
      label(c, '${m.toInt()}', Offset(p.dx, p.dy + 8), center: true);
    }
    label(c, expanded ? 'Mức tăng chiều dài (cm)' : 'cm', Offset(left, 0));
    label(
      c,
      expanded ? 'Tuổi (tháng)' : 'tháng',
      Offset(s.width - (expanded ? 150 : 48), s.height - 16),
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
      if (i == selected) {
        for (double y = p.dy; y < s.height - 44; y += 7) {
          c.drawLine(
            Offset(p.dx, y),
            Offset(p.dx, math.min(y + 4, s.height - 44)),
            Paint()..color = WeightChartColors.axis.withValues(alpha: .6),
          );
        }
        c.drawCircle(p, 7, Paint()..color = Colors.white);
        c.drawCircle(
          p,
          6,
          Paint()
            ..color = StatureChartColors.data
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
      c.drawCircle(
        p,
        i == selected ? 2 : 4,
        Paint()..color = StatureChartColors.data,
      );
    }
    c.restore();
    final axes = Paint()
      ..color = WeightChartColors.axis.withValues(alpha: .5)
      ..strokeWidth = 1;
    c.drawLine(Offset(left, 20), Offset(left, s.height - 44), axes);
    c.drawLine(
      Offset(left, s.height - 44),
      Offset(s.width - right, s.height - 44),
      axes,
    );
    if (expanded && rows.isNotEmpty) {
      final row = rows.last;
      const labels = [3, 2, 0, -2, -3];
      final positions = [
        for (final sd in labels)
          at((row.start + row.end) / 2, row.sd[sd + 3], s),
      ];
      final ys = [for (final p in positions) p.dy - font / 2];
      ys.last = math.min(ys.last, s.height - 44 - font);
      for (var i = ys.length - 2; i >= 0; i--) {
        ys[i] = math.min(ys[i], ys[i + 1] - font - 2);
      }
      for (var i = 0; i < labels.length; i++) {
        final sd = labels[i];
        label(c, sd > 0 ? '+$sd' : '$sd', Offset(positions[i].dx + 9, ys[i]));
      }
    }
  }

  @override
  bool shouldRepaint(covariant StatureIncrementPainter old) => true;
}
