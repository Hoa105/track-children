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
  RangeValues _window = const RangeValues(0, 60);
  @visibleForTesting
  RangeValues get visibleRange => _window;
  RangeValues _gestureWindow = const RangeValues(0, 60);
  double _anchorAge = 0, _initialGestureScale = 1;
  int _gesturePointers = 0;

  double _fraction(Offset focalPoint, double width) =>
      ((focalPoint.dx - 38) / (width - 46)).clamp(0.0, 1.0);

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
      60.0,
    );
    final first = _anchorAge - _fraction(details.localFocalPoint, width) * span;
    _setWindow(first, first + span);
  }

  void _setWindow(double start, double end) {
    final span = (end - start).clamp(1 / 30, 60.0);
    final first = start.clamp(0.0, 60 - span);
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
      birth.year + 5,
      birth.month,
      birth.day.clamp(1, DateUtils.getDaysInMonth(birth.year + 5, birth.month)),
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
        aspectRatio: 1,
        child: Center(child: Text('Chưa có số đo trong độ tuổi này.')),
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
      children: [
        if (selected != null)
          Semantics(
            liveRegion: true,
            child: Container(
              key: const Key('selected-growth-measurement'),
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: GrowthColors.primarySoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: GrowthColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lần đo đang xem',
                    style: TextStyle(
                      color: GrowthColors.primaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${formatGrowthValue(selected.value)} ${widget.metric.unit}',
                    key: const Key('selected-growth-value'),
                    style: const TextStyle(
                      color: GrowthColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Ngày đo: ${selected.measuredAt.day.toString().padLeft(2, '0')}/${selected.measuredAt.month.toString().padLeft(2, '0')}/${selected.measuredAt.year}',
                    key: const Key('selected-growth-date'),
                    style: const TextStyle(
                      color: GrowthColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Text(
            'Chụm/tách hai ngón để thu/phóng. Chạm hai lần để đặt lại.',
            style: TextStyle(fontSize: 12, color: GrowthColors.textSecondary),
          ),
        ),
        LayoutBuilder(
          builder: (context, c) {
            final chartHeight = (c.maxWidth * 1.24).clamp(400.0, 640.0);
            return SizedBox(
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
                  onReset: () => _setWindow(0, 60),
                  panEnabled: _window.end - _window.start < 60 - 1e-9,
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
                            ),
                          )
                        : CustomPaint(
                            key: const Key('growth-plot'),
                            painter: painter,
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
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
    this.maxAge = 60,
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

  Rect plot(Size size) =>
      Rect.fromLTRB(38, 18, size.width - 8, size.height - 38);

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
    double fontSize = 11,
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
    final grid = Paint()
      ..color = const Color(0xFFD8E1DD)
      ..strokeWidth = 1;
    final intervals = ((high - low) / valueScale.step).round();
    for (var i = 0; i <= intervals; i++) {
      final y = r.bottom - r.height * i / intervals;
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), grid);
      label(
        canvas,
        naturalLabel(low + valueScale.step * i),
        Offset(r.left - 6, y - 7),
        right: true,
      );
    }
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
      if (xFor(age) - xFor(ticks.last) > 34 && r.right - xFor(age) > 34) {
        ticks.add(age);
      }
    }
    ticks.add(maxAge);
    for (final age in ticks) {
      label(
        canvas,
        formatGrowthValue((age * 100).round() / 100),
        Offset(xFor(age), r.bottom + 6),
        center: true,
      );
    }
    label(canvas, metric.unit, Offset(r.left, 0), fontSize: 10.5);
    label(
      canvas,
      'Tháng',
      Offset(r.center.dx, r.bottom + 21),
      center: true,
      fontSize: 10.5,
    );
    final axis = Paint()
      ..color = const Color(0xFF526B68)
      ..strokeWidth = 1.5;
    canvas.drawLine(r.topLeft, r.bottomLeft, axis);
    canvas.drawLine(r.bottomLeft, r.bottomRight, axis);
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
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    final markers = showMarkers(size);
    for (final row in rows) {
      if (!markers && !identical(row, selected)) {
        continue;
      }
      final p = point(row, size);
      if (identical(row, selected)) {
        canvas.drawCircle(p, 13, Paint()..color = color.withValues(alpha: .18));
        canvas.drawCircle(p, 8, Paint()..color = AppColors.surface);
      }
      canvas.drawCircle(
        p,
        identical(row, selected) ? 6 : 4.5,
        Paint()..color = color,
      );
    }
  }

  bool showMarkers(Size size) {
    // A small history should expose every measurement, even on a wide time axis.
    if (rows.length <= 12) return true;
    for (var i = 1; i < rows.length; i++) {
      if ((point(rows[i], size) - point(rows[i - 1], size)).distance < 20) {
        return false;
      }
    }
    return true;
  }

  @override
  bool shouldRepaint(covariant _MeasurementPainter old) => true;
}
