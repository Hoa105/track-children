import '../../services/demo_store.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../services/who_growth_reference.dart';

class GrowthChart extends StatefulWidget {
  const GrowthChart({
    this.selectedIndex,
    this.highlightIndex,
    this.onSelected,
    this.rangeStart,
    this.rangeEnd,
    this.previewAnchor,
    this.childId,
    this.allowReference = true,
    required this.values,
    required this.dates,
    required this.metric,
    required this.childName,
    required this.preview,
    required this.unit,
    super.key,
  });
  final String? childId;
  final bool allowReference;
  final int? selectedIndex, highlightIndex;
  final ValueChanged<int>? onSelected;
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
  bool _showMedian = true;
  bool _showBand = true;
  int? _activeIndex;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final reference = await WhoGrowthReference.load();
      if (!mounted) return;
      final latest = widget.previewAnchor ?? widget.dates.last;
      setState(() {
        _reference = reference;
        final child = widget.childId == null
            ? null
            : DemoStore.instance.childById(widget.childId!);
        _sex = widget.preview
            ? 'boys'
            : switch (child?['gender']) {
                'male' => 'boys',
                'female' => 'girls',
                _ => null,
              };
        _birth = widget.preview
            ? DateTime(
                latest.year,
                latest.month - 8,
                latest.day.clamp(
                  1,
                  DateTime(latest.year, latest.month - 7, 0).day,
                ),
              )
            : DateTime.tryParse(child?['date_of_birth']?.toString() ?? '');
        if (!widget.preview &&
            _birth != null &&
            _birth!.isAfter(DateTime.now())) {
          _birth = null;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final samples = <WhoChartReferencePoint>[];
    if (widget.allowReference &&
        _birth != null &&
        _sex != null &&
        _reference != null) {
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
    final selected = widget.selectedIndex ?? _activeIndex;
    final motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.allowReference)
          const Text(
            'Chưa đối chiếu WHO: kiểm tra tư thế đo chiều cao.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        SizedBox(
          height: 220,
          child: LayoutBuilder(
            builder: (context, c) {
              void chooseIndex(int index) {
                setState(() => _activeIndex = index);
                widget.onSelected?.call(index);
              }

              void select(double dx) {
                final first = widget.rangeStart ?? widget.dates.first;
                final span = (widget.rangeEnd ?? widget.dates.last)
                    .difference(first)
                    .inMilliseconds;
                final fraction = ((dx - 42) / (c.maxWidth - 56)).clamp(
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
                chooseIndex(index);
              }

              Widget plot(double progress) => CustomPaint(
                key: const ValueKey('growth-who-chart'),
                size: Size(c.maxWidth, 220),
                painter: GrowthChartPainter(
                  widget.values,
                  widget.dates,
                  samples,
                  rangeStart: widget.rangeStart,
                  rangeEnd: widget.rangeEnd,
                  selectedIndex: selected,
                  highlightIndex: widget.highlightIndex,
                  showMedian: _showMedian,
                  showBand: _showBand,
                  progress: progress,
                  axisStyle: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(fontSize: 10, color: AppColors.textSecondary),
                ),
              );
              return Semantics(
                label:
                    'Biểu đồ ${widget.values.length} lần đo. Kéo ngang để xem số đo.',
                onIncrease: () => chooseIndex(
                  ((selected ?? 0) + 1).clamp(0, widget.values.length - 1),
                ),
                onDecrease: () => chooseIndex(
                  ((selected ?? 0) - 1).clamp(0, widget.values.length - 1),
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => select(d.localPosition.dx),
                  onHorizontalDragStart: (d) => select(d.localPosition.dx),
                  onHorizontalDragUpdate: (d) => select(d.localPosition.dx),
                  child: motion == Duration.zero
                      ? plot(1)
                      : TweenAnimationBuilder<double>(
                          duration: motion,
                          tween: Tween(begin: 0, end: 1),
                          curve: Curves.easeOutCubic,
                          builder: (context, progress, _) => plot(progress),
                        ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Số đo của bé',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (samples.isNotEmpty) ...[
              Semantics(
                toggled: _showMedian,
                child: TextButton(
                  key: const ValueKey('toggle-who-median'),
                  onPressed: () => setState(() => _showMedian = !_showMedian),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 40),
                    foregroundColor: _showMedian
                        ? const Color(0xFFBB7435)
                        : AppColors.textSecondary,
                  ),
                  child: Text(
                    'Trung vị WHO',
                    style: TextStyle(
                      fontSize: 10,
                      decoration: _showMedian
                          ? TextDecoration.none
                          : TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ),
              Semantics(
                toggled: _showBand,
                child: TextButton(
                  key: const ValueKey('toggle-who-band'),
                  onPressed: () => setState(() => _showBand = !_showBand),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 40),
                    foregroundColor: _showBand
                        ? const Color(0xFF647FA8)
                        : AppColors.textSecondary,
                  ),
                  child: Text(
                    'Vùng −2 đến +2 SD',
                    style: TextStyle(
                      fontSize: 10,
                      decoration: _showBand
                          ? TextDecoration.none
                          : TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ),
            ],
            IconButton(
              tooltip: 'Chuẩn WHO',
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                useSafeArea: true,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (context) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Hiểu biểu đồ WHO',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 21,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Đường xanh là số đo của bé. Đường cam nét đứt là trung vị WHO theo tuổi và giới tính. Vùng nhạt thể hiện −2 đến +2 độ lệch chuẩn (SD), không phải kết luận về sức khỏe.',
                      ),
                      const SizedBox(height: 12),
                      if (['height', 'bmi'].contains(widget.metric))
                        const Text(
                          'Dưới 2 tuổi dùng chiều dài đo nằm; từ 2 tuổi dùng chiều cao đo đứng. Số đo khác tư thế cần quy đổi trước khi đối chiếu.',
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        'Chuẩn áp dụng từ 0 đến 60 tháng. Dữ liệu tham khảo không thay thế đánh giá của nhân viên y tế.',
                      ),
                      const SizedBox(height: 16),
                      const SelectableText(
                        'Nguồn: WHO Child Growth Standards\nhttps://www.who.int/tools/child-growth-standards',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (samples.isEmpty)
          Text(
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
    this.selectedIndex,
    this.highlightIndex,
    this.showMedian = true,
    this.showBand = true,
    this.progress = 1,
    this.axisStyle,
  });
  final int? selectedIndex, highlightIndex;
  final bool showMedian, showBand;
  final double progress;
  final TextStyle? axisStyle;
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
          style:
              axisStyle ??
              const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(0, y - 6));
    }
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(42, 0, 42 + (size.width - 56) * progress, size.height),
    );
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
      if (showBand) {
        canvas.drawPath(area, Paint()..color = const Color(0x24647FA8));
      }
      final median = line(
        group.map((r) => point(r.date, r.values[1])).toList(),
      );
      if (showMedian) {
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
      }
      if (showMedian && group.length == 1) {
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
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      if (i == highlightIndex) {
        canvas.drawCircle(
          p,
          9 + 8 * (1 - progress),
          Paint()..color = AppColors.primary.withValues(alpha: .13),
        );
      }
      canvas.drawCircle(p, 5, Paint()..color = Colors.white);
      canvas.drawCircle(p, 3.5, Paint()..color = AppColors.primary);
    }
    canvas.restore();
    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < points.length) {
      final p = points[selectedIndex!];
      canvas.drawLine(
        Offset(p.dx, 8),
        Offset(p.dx, size.height - 8),
        Paint()
          ..color = AppColors.primary.withValues(alpha: .22)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(
        p,
        9,
        Paint()..color = AppColors.primary.withValues(alpha: .12),
      );
      canvas.drawCircle(p, 6, Paint()..color = Colors.white);
      canvas.drawCircle(p, 4.5, Paint()..color = AppColors.primary);
    }
  }

  @override
  bool shouldRepaint(covariant GrowthChartPainter oldDelegate) => true;
}
