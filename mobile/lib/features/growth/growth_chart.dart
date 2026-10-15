import '../../services/demo_store.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app_colors.dart';
import '../../services/who_growth_reference.dart';

class GrowthChart extends StatefulWidget {
  const GrowthChart({
    this.rangeStart,
    this.rangeEnd,
    this.previewAnchor,
    this.childId,
    required this.values,
    required this.dates,
    required this.metric,
    required this.childName,
    required this.preview,
    required this.unit,
    super.key,
  });
  final String? childId;
  final DateTime? rangeStart, rangeEnd, previewAnchor;
  final List<double> values;
  final List<DateTime> dates;
  final String metric, childName, unit;
  final bool preview;
  @override
  State<GrowthChart> createState() => _GrowthChartState();
}

class _GrowthChartState extends State<GrowthChart> {
  WhoGrowthReference? _reference;
  String? _sex;
  DateTime? _birth;
  bool _error = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final reference = await WhoGrowthReference.load();
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final latest = widget.previewAnchor ?? widget.dates.last;
      setState(() {
        _reference = reference;
        _sex = widget.preview
            ? 'boys'
            : prefs.getString('who_profile_${widget.childName}_sex');
        final child = widget.childId == null
            ? null
            : DemoStore.instance.childById(widget.childId!);
        if (child != null) _sex = child['gender'] == 'male' ? 'boys' : 'girls';
        _birth = widget.preview
            ? DateTime(
                latest.year,
                latest.month - 8,
                latest.day.clamp(
                  1,
                  DateTime(latest.year, latest.month - 7, 0).day,
                ),
              )
            : DateTime.tryParse(
                child?['date_of_birth'] as String? ??
                    prefs.getString('who_profile_${widget.childName}_birth') ??
                    '',
              );
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final samples = <WhoChartReferencePoint>[];
    if (_birth != null && _sex != null && _reference != null) {
      final first = widget.rangeStart ?? widget.dates.first;
      final last = widget.rangeEnd ?? widget.dates.last;
      final dates = <DateTime>{first, last};
      for (
        var d = first;
        !d.isAfter(last);
        d = d.add(const Duration(days: 7))
      ) {
        dates.add(d);
      }
      // Include the exact length-to-height transition, keeping the two paths separate.
      final transition = DateTime(
        _birth!.year + 2,
        _birth!.month,
        _birth!.day.clamp(
          1,
          DateTime(_birth!.year + 2, _birth!.month + 1, 0).day,
        ),
      );
      for (final d in [
        transition.subtract(const Duration(milliseconds: 1)),
        transition,
      ]) {
        if (!d.isBefore(first) && !d.isAfter(last)) dates.add(d);
      }
      final sorted = dates.toList()..sort();
      for (final date in sorted) {
        final row = _reference!.at(widget.metric, _sex!, _birth!, date);
        if (row != null) {
          samples.add(
            WhoChartReferencePoint(date, row, date.isBefore(transition)),
          );
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: LayoutBuilder(
            builder: (context, c) => GestureDetector(
              onTapUp: (details) {
                final first = widget.rangeStart ?? widget.dates.first;
                final span = (widget.rangeEnd ?? widget.dates.last)
                    .difference(first)
                    .inMilliseconds;
                final fraction =
                    ((details.localPosition.dx - 42) / (c.maxWidth - 56)).clamp(
                      0.0,
                      1.0,
                    );
                var index = 0;
                var distance = double.infinity;
                for (var i = 0; i < widget.dates.length; i++) {
                  final diff =
                      (widget.dates[i].difference(first).inMilliseconds -
                              fraction * span)
                          .abs();
                  if (diff < distance) {
                    distance = diff;
                    index = i;
                  }
                }
                final date = widget.dates[index];
                final row = _birth == null || _sex == null
                    ? null
                    : _reference?.at(widget.metric, _sex!, _birth!, date);
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        '${date.day}/${date.month}/${date.year} · ${widget.values[index].toStringAsFixed(1)} ${widget.unit}${row == null ? '' : ' · WHO: ${row[1].toStringAsFixed(1)} ${widget.unit}'}',
                      ),
                    ),
                  );
              },
              child: CustomPaint(
                key: const ValueKey('growth-who-chart'),
                size: Size(c.maxWidth, 200),
                painter: GrowthChartPainter(
                  widget.values,
                  widget.dates,
                  samples,
                  rangeStart: widget.rangeStart,
                  rangeEnd: widget.rangeEnd,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            const Text(
              '● Số đo của bé',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (samples.isNotEmpty) ...[
              const Text(
                '┄ Trung vị WHO',
                style: TextStyle(fontSize: 11, color: Color(0xFFBB7435)),
              ),
              const Text(
                '▰ Vùng −2 đến +2 SD',
                style: TextStyle(fontSize: 11, color: Color(0xFF647FA8)),
              ),
            ],
          ],
        ),
        if (samples.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error
                  ? 'Chưa tải được đường WHO. Hãy mở lại màn hình.'
                  : _birth == null || _sex == null
                  ? 'Chưa có thông tin đối chiếu WHO.'
                  : 'Không có chuẩn WHO trong khoảng tuổi này (0–60 tháng).',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        if (samples.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'WHO theo tuổi và giới tính · vùng SD là tham chiếu, không phải kết luận sức khỏe.',
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ),
        if (samples.isNotEmpty && ['height', 'bmi'].contains(widget.metric))
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Dưới 2 tuổi: đo nằm; từ 2 tuổi: đo đứng. Số đo khác tư thế cần quy đổi trước khi đối chiếu.',
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}

class WhoChartReferencePoint {
  WhoChartReferencePoint(this.date, this.values, this.beforeTwo);
  final DateTime date;
  final List<double> values;
  final bool beforeTwo;
}

class GrowthChartPainter extends CustomPainter {
  GrowthChartPainter(
    this.values,
    this.dates,
    this.reference, {
    this.rangeStart,
    this.rangeEnd,
  });
  final DateTime? rangeStart, rangeEnd;
  final List<double> values;
  final List<DateTime> dates;
  final List<WhoChartReferencePoint> reference;
  bool get hasReference => reference.isNotEmpty;
  @override
  void paint(Canvas canvas, Size size) {
    final all = [...values, for (final r in reference) ...r.values];
    final min = all.reduce(math.min), max = all.reduce(math.max);
    final pad = math.max((max - min) * .12, .5);
    final low = min - pad, high = max + pad;
    final first = rangeStart ?? dates.first;
    final span = (rangeEnd ?? dates.last).difference(first).inMilliseconds;
    Offset point(DateTime date, double v) => Offset(
      42 +
          (span == 0
              ? (size.width - 56) / 2
              : date.difference(first).inMilliseconds /
                    span *
                    (size.width - 56)),
      12 + (high - v) / (high - low) * (size.height - 24),
    );
    for (var i = 0; i < 4; i++) {
      final y = 12 + i * (size.height - 24) / 3;
      canvas.drawLine(
        Offset(42, y),
        Offset(size.width - 14, y),
        Paint()..color = AppColors.border,
      );
      final label = TextPainter(
        text: TextSpan(
          text: (high - (high - low) * i / 3).toStringAsFixed(1),
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(0, y - 6));
    }
    Path line(List<Offset> points) {
      final p = Path()..moveTo(points.first.dx, points.first.dy);
      for (final o in points.skip(1)) {
        p.lineTo(o.dx, o.dy);
      }
      return p;
    }

    for (final before in [true, false]) {
      final group = reference.where((r) => r.beforeTwo == before).toList();
      if (group.isEmpty) continue;
      final lower = group.map((r) => point(r.date, r.values[0])).toList();
      final upper = group.map((r) => point(r.date, r.values[2])).toList();
      final area = line(lower);
      for (final p in upper.reversed) {
        area.lineTo(p.dx, p.dy);
      }
      area.close();
      canvas.drawPath(area, Paint()..color = const Color(0x24647FA8));
      final median = line(
        group.map((r) => point(r.date, r.values[1])).toList(),
      );
      for (final metric in median.computeMetrics()) {
        for (double d = 0; d < metric.length; d += 10) {
          canvas.drawPath(
            metric.extractPath(d, math.min(d + 6, metric.length)),
            Paint()
              ..color = const Color(0xFFBB7435)
              ..strokeWidth = 2
              ..style = PaintingStyle.stroke,
          );
        }
      }
      if (group.length == 1) {
        canvas.drawCircle(
          point(group.first.date, group.first.values[1]),
          3,
          Paint()..color = const Color(0xFFBB7435),
        );
      }
    }
    final points = List.generate(
      values.length,
      (i) => point(dates[i], values[i]),
    );
    canvas.drawPath(
      line(points),
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    for (final p in points) {
      canvas.drawCircle(p, 5, Paint()..color = Colors.white);
      canvas.drawCircle(p, 3.5, Paint()..color = AppColors.primary);
    }
  }

  @override
  bool shouldRepaint(covariant GrowthChartPainter oldDelegate) => true;
}
