import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import 'growth_repository.dart';
import 'growth_chart_scale.dart';
import 'growth_chart_gestures.dart';

class GrowthMeasurementChart extends StatefulWidget {
  const GrowthMeasurementChart({
    super.key,
    required this.rows,
    required this.birth,
    required this.metric,
    this.onPinchingChanged,
  });
  final List<GrowthMeasurementDraft> rows;
  final DateTime? birth;
  final GrowthMetric metric;
  final ValueChanged<bool>? onPinchingChanged;
  @override
  State<GrowthMeasurementChart> createState() => GrowthMeasurementChartState();
}

class GrowthMeasurementChartState extends State<GrowthMeasurementChart> {
  GrowthMeasurementDraft? _selected;
  late RangeValues _window;
  @visibleForTesting
  RangeValues get visibleRange => _window;
  late RangeValues _gestureWindow;
  double _anchorAge = 0, _initialGestureScale = 1;
  int _gesturePointers = 0;

  static const double _leftMargin = 38.0;
  static const double _rightMargin = 38.0;

  @override
  void initState() {
    super.initState();
    _window = _calculateInitialWindow();
    _gestureWindow = _window;
  }

  @override
  void didUpdateWidget(covariant GrowthMeasurementChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metric != widget.metric ||
        oldWidget.rows.length != widget.rows.length ||
        oldWidget.birth != widget.birth) {
      _window = _calculateInitialWindow();
      _gestureWindow = _window;
    }
  }

  RangeValues _calculateInitialWindow() {
    final birth = widget.birth;
    if (birth == null || widget.rows.isEmpty) {
      return const RangeValues(0, 24);
    }
    double maxAge = 0;
    for (final r in widget.rows) {
      final m = growthChartAgeMonths(birth, r.measuredAt);
      if (m != null && m > maxAge) maxAge = m;
    }
    // Smart adaptation: match standard WHO infant/child growth phases
    if (maxAge <= 12) {
      return const RangeValues(0, 12);
    } else if (maxAge <= 24) {
      return const RangeValues(0, 24);
    } else if (maxAge <= 36) {
      return const RangeValues(0, 36);
    } else {
      return const RangeValues(0, 72);
    }
  }

  double _fraction(Offset focalPoint, double width) =>
      ((focalPoint.dx - _leftMargin) / (width - (_leftMargin + _rightMargin)))
          .clamp(0.0, 1.0);

  void _startGesture(ScaleStartDetails details, double width) {
    _gestureWindow = _window;
    _gesturePointers = details.pointerCount;
    _initialGestureScale = 1;
    _anchorAge =
        _window.start +
        _fraction(details.localFocalPoint, width) *
            (_window.end - _window.start);
  }

  void _updateGesture(ScaleUpdateDetails details, double width) {
    if (details.pointerCount != _gesturePointers) {
      _gestureWindow = _window;
      _gesturePointers = details.pointerCount;
      _initialGestureScale = details.scale;
      _anchorAge =
          _window.start +
          _fraction(details.localFocalPoint, width) *
              (_window.end - _window.start);
      return;
    }
    final scale = details.pointerCount >= 2
        ? details.scale / _initialGestureScale
        : 1.0;
    if (!scale.isFinite || scale <= 0) return;
    final span = ((_gestureWindow.end - _gestureWindow.start) / scale).clamp(
      1 / 30,
      72.0,
    );
    final first = _anchorAge - _fraction(details.localFocalPoint, width) * span;
    _setWindow(first, first + span);
  }

  void _setWindow(double start, double end) {
    final span = (end - start).clamp(1 / 30, 72.0);
    final first = start.clamp(0.0, 72 - span);
    setState(() => _window = RangeValues(first, first + span));
  }

  @override
  Widget build(BuildContext context) {
    final birth = widget.birth;
    if (birth == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Cần ngày sinh của bé để hiển thị biểu đồ.',
          textAlign: TextAlign.center,
        ),
      );
    }
    final end = DateTime(
      birth.year + 6,
      birth.month,
      birth.day.clamp(1, DateUtils.getDaysInMonth(birth.year + 6, birth.month)),
    );
    final validRows = widget.rows
        .where(
          (r) =>
              r.value.isFinite &&
              r.value > 0 &&
              !r.measuredAt.isBefore(birth) &&
              !r.measuredAt.isAfter(end),
        )
        .toList();
    validRows.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    if (validRows.isEmpty) {
      return const AspectRatio(
        aspectRatio: 1.3,
        child: Center(
          child: Text(
            'Chưa có số đo trong độ tuổi này.',
            style: TextStyle(color: GrowthColors.textSecondary),
          ),
        ),
      );
    }
    final rows = validRows.where((row) {
      final age = growthChartAgeMonths(birth, row.measuredAt)!;
      return age >= _window.start - 1e-9 && age <= _window.end + 1e-9;
    }).toList();
    final selected = rows.contains(_selected) ? _selected : rows.lastOrNull;
    final painter = rows.isEmpty
        ? null
        : _MeasurementPainter(
            rows,
            birth,
            end,
            widget.metric,
            selected!,
            minAge: _window.start,
            maxAge: _window.end,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selected != null)
          Semantics(
            liveRegion: true,
            child: Container(
              key: const Key('selected-growth-measurement'),
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: GrowthColors.primarySoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: GrowthColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lần đo đang chọn',
                        style: TextStyle(
                          color: GrowthColors.primaryDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatGrowthValue(selected.value)} ${widget.metric.unit}',
                        key: const Key('selected-growth-value'),
                        style: const TextStyle(
                          color: GrowthColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${selected.measuredAt.day.toString().padLeft(2, '0')}/${selected.measuredAt.month.toString().padLeft(2, '0')}/${selected.measuredAt.year}',
                        key: const Key('selected-growth-date'),
                        style: const TextStyle(
                          color: GrowthColors.primaryDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Lúc ${(growthChartAgeMonths(birth, selected.measuredAt) ?? 0).toStringAsFixed(1).replaceAll('.', ',')} tháng tuổi',
                        style: const TextStyle(
                          color: GrowthColors.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 10),

        // Quick Preset Range Chips
        _buildRangePresets(),

        const SizedBox(height: 10),

        LayoutBuilder(
          builder: (context, c) {
            // Balanced golden-ratio height for mobile (proportional & readable)
            final chartHeight = (c.maxWidth * 0.72).clamp(270.0, 340.0);
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFCFDFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5EDE6), width: 1.1),
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: c.maxWidth,
                height: chartHeight,
                child: MouseRegion(
                  onHover: (event) {
                    if (painter == null) return;
                    final nearest = _nearestRow(
                      rows,
                      painter,
                      Size(c.maxWidth, chartHeight),
                      event.localPosition,
                    );
                    if (nearest != null && nearest != _selected) {
                      setState(() {
                        _selected = nearest;
                      });
                    }
                  },
                  child: GrowthChartGestures(
                    onPinchingChanged: widget.onPinchingChanged,
                    onReset: () => _setWindow(0, 72),
                    panEnabled: _window.end - _window.start < 72 - 1e-9,
                    onStart: (details) => _startGesture(details, c.maxWidth),
                    onUpdate: (details) => _updateGesture(details, c.maxWidth),
                    onTap: (event) {
                      if (painter == null) return;
                      final size = Size(c.maxWidth, chartHeight);
                      final nearest = _nearestRow(
                        rows,
                        painter,
                        size,
                        event.localPosition,
                      );
                      if (nearest != null) setState(() => _selected = nearest);
                    },
                    child: Semantics(
                      label:
                          '${widget.metric.title}. ${rows.length} lần đo trong khoảng đang xem. Chạm để chọn số đo.',
                      child: painter == null
                          ? const Center(
                              child: Text(
                                'Chưa có số đo trong khoảng đang xem.',
                                textAlign: TextAlign.center,
                                style:
                                    TextStyle(color: GrowthColors.textSecondary),
                              ),
                            )
                          : CustomPaint(
                              key: const Key('growth-plot'),
                              painter: painter,
                            ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        const Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 2),
          child: Text(
            'Chạm vào điểm tròn để xem số đo. Chụm/tách 2 ngón để phóng to/thu nhỏ.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: GrowthColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildRangePresets() {
    final currentSpan = (_window.end - _window.start).round();
    final isFullSpan = _window.start == 0 && currentSpan >= 70;
    final presets = [
      (12, '12 tháng'),
      (24, '24 tháng'),
      (36, '3 tuổi'),
      (72, 'Toàn bộ'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: presets.map((preset) {
            final isSelected =
                (_window.start == 0 && currentSpan == preset.$1) ||
                    (preset.$1 == 72 && isFullSpan);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _setWindow(0, preset.$1.toDouble()),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? GrowthColors.primary
                          : GrowthColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? GrowthColors.primary
                            : GrowthColors.border,
                        width: 1.4,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color:
                                    GrowthColors.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : const [
                              BoxShadow(
                                color: Color(0x0A29451E),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                    ),
                    child: Text(
                      preset.$2,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : GrowthColors.primaryDark,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  GrowthMeasurementDraft? _nearestRow(
    List<GrowthMeasurementDraft> rows,
    _MeasurementPainter painter,
    Size size,
    Offset position,
  ) {
    GrowthMeasurementDraft? nearest;
    var distance = 24.0;
    for (final row in rows) {
      final candidate = (painter.point(row, size) - position).distance;
      if (candidate <= distance) {
        distance = candidate;
        nearest = row;
      }
    }
    return nearest;
  }
}

class _MeasurementPainter extends CustomPainter {
  _MeasurementPainter(
    this.rows,
    this.birth,
    this.end,
    this.metric,
    this.selected, {
    this.minAge = 0,
    this.maxAge = 72,
  });
  final List<GrowthMeasurementDraft> rows;
  final DateTime birth, end;
  final GrowthMetric metric;
  final GrowthMeasurementDraft selected;
  final double minAge, maxAge;
  static const color = GrowthColors.primary;
  late final GrowthChartValueScale valueScale = GrowthChartValueScale.forRows(
    rows,
    metric,
  );
  double get low => valueScale.low;
  double get high => valueScale.high;
  DateTime get start => birth;
  DateTime get stop => end;

  static const double leftMargin = 38.0;
  static const double rightMargin = 38.0;

  Rect plot(Size size) =>
      Rect.fromLTRB(leftMargin, 16, size.width - rightMargin, size.height - 34);

  double xForDate(DateTime date, Size size) {
    final r = plot(size);
    final months = growthChartAgeMonths(birth, date)!;
    return r.left + (months - minAge) / (maxAge - minAge) * r.width;
  }

  Offset point(GrowthMeasurementDraft row, Size size) {
    final r = plot(size);
    return Offset(
      xForDate(row.measuredAt, size),
      r.bottom - (row.value - low) / (high - low) * r.height,
    );
  }

  void label(
    Canvas canvas,
    String value,
    Offset at, {
    bool center = false,
    bool right = false,
    double fontSize = 10.5,
  }) {
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'Nunito',
          color: GrowthColors.textPrimary,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset(
        center
            ? at.dx - text.width / 2
            : right
                ? at.dx - text.width
                : at.dx,
        at.dy,
      ),
    );
  }

  String naturalLabel(double value) => formatGrowthValue(value);

  @override
  void paint(Canvas canvas, Size size) {
    final r = plot(size);

    // 1. Grid lines and Y-axis labels
    final grid = Paint()
      ..color = const Color(0xFFE2EBE5)
      ..strokeWidth = 1;
    final intervals = ((high - low) / valueScale.step).round();
    for (var i = 0; i <= intervals; i++) {
      final y = r.bottom - r.height * i / intervals;
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), grid);
      label(
        canvas,
        naturalLabel(low + valueScale.step * i),
        Offset(r.left - 5, y - 6.5),
        right: true,
      );
    }

    // 2. X-axis tick intervals
    final span = maxAge - minAge;
    final rawStep = span / 5;
    final magnitude = math
        .pow(10, (math.log(rawStep) / math.ln10).floor())
        .toDouble();
    final niceStep =
        [
          1.0,
          2.0,
          2.5,
          5.0,
          10.0,
        ].firstWhere((v) => v * magnitude >= rawStep - 1e-9) *
        magnitude;
    final step = span >= 48
        ? 12.0
        : span >= 24
            ? 6.0
            : span >= 12
                ? 3.0
                : span >= 6
                    ? 1.0
                    : niceStep;
    final ticks = <double>[minAge];
    double xFor(double age) => r.left + (age - minAge) / span * r.width;
    for (
      var age = (minAge / step).floor() * step + step;
      age < maxAge - 1e-9;
      age += step
    ) {
      if (xFor(age) - xFor(ticks.last) > 30 && r.right - xFor(age) > 30) {
        ticks.add(age);
      }
    }
    ticks.add(maxAge);
    for (final age in ticks) {
      label(
        canvas,
        formatGrowthValue((age * 100).round() / 100),
        Offset(xFor(age), r.bottom + 5),
        center: true,
      );
    }

    // 3. Units & Labels
    label(canvas, metric.unit, Offset(r.left, 0), fontSize: 10);
    label(
      canvas,
      'Tháng',
      Offset(r.center.dx, r.bottom + 18),
      center: true,
      fontSize: 10,
    );

    // 4. Main Axes Lines
    final axis = Paint()
      ..color = const Color(0xFF5A7365)
      ..strokeWidth = 1.4;
    canvas.drawLine(r.topLeft, r.bottomLeft, axis);
    canvas.drawLine(r.bottomLeft, r.bottomRight, axis);

    // 5. Area Fill Gradient under the curve
    if (rows.length >= 2) {
      final areaPath = Path();
      GrowthMeasurementDraft? prev;
      for (final row in rows) {
        final p = point(row, size);
        if (prev == null ||
            DateUtils.isSameDay(row.measuredAt, prev.measuredAt)) {
          areaPath.moveTo(p.dx, p.dy);
        } else {
          areaPath.lineTo(p.dx, p.dy);
        }
        prev = row;
      }
      areaPath.lineTo(point(rows.last, size).dx, r.bottom);
      areaPath.lineTo(point(rows.first, size).dx, r.bottom);
      areaPath.close();

      final areaPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.01),
          ],
        ).createShader(r);
      canvas.drawPath(areaPath, areaPaint);
    }

    // 6. Main Curve Line
    final path = Path();
    GrowthMeasurementDraft? previous;
    for (final row in rows) {
      final p = point(row, size);
      if (previous == null ||
          DateUtils.isSameDay(row.measuredAt, previous.measuredAt)) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
      previous = row;
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    // 7. Measurement Dots & Selection Ring
    final markers = showMarkers(size);
    for (final row in rows) {
      if (!markers && !identical(row, selected)) {
        continue;
      }
      final p = point(row, size);
      if (identical(row, selected)) {
        canvas.drawCircle(
          p,
          13,
          Paint()..color = color.withValues(alpha: .22),
        );
        canvas.drawCircle(p, 7.5, Paint()..color = Colors.white);
        canvas.drawCircle(p, 5.5, Paint()..color = color);
      } else {
        canvas.drawCircle(p, 5, Paint()..color = Colors.white);
        canvas.drawCircle(p, 3.8, Paint()..color = color);
      }
    }
  }

  bool showMarkers(Size size) {
    if (rows.length <= 12) return true;
    for (var i = 1; i < rows.length; i++) {
      if ((point(rows[i], size) - point(rows[i - 1], size)).distance < 18) {
        return false;
      }
    }
    return true;
  }

  @override
  bool shouldRepaint(covariant _MeasurementPainter old) => true;
}
