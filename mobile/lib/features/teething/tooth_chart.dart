import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../models/tooth.dart';

/// Dental arches viewed facing the child; right appears on the viewer's left.
class ToothChart extends StatelessWidget {
  const ToothChart({
    super.key,
    required this.eruptedIds,
    required this.ageMonths,
    required this.onToothTap,
    this.referenceIds,
    this.selectedReferenceId,
    this.showPairNumbers = false,
  });
  final Set<String> eruptedIds;
  final int ageMonths;
  final ValueChanged<PrimaryTooth>? onToothTap;
  final bool showPairNumbers;

  /// When supplied, the chart is in reference mode. Highlighted teeth are
  /// possible by age, not parent-confirmed erupted teeth.
  final Set<String>? referenceIds;
  final String? selectedReferenceId;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = math.max(460.0, width * 1.45);
      final center = Offset(width / 2, height / 2);
      final a = width / 2 - (width * .08 + 6);
      final b = height / 2 - 50;
      final angles = _archAngles(a, b);
      return RepaintBoundary(
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(painter: _MouthPainter()),
                ),
              ),
              for (final jaw in Jaw.values)
                for (var i = 0; i < 10; i++)
                  _positionTooth(context, jaw, i, center, a, b, angles[i]),
            ],
          ),
        ),
      );
    },
  );

  Widget _positionTooth(
    BuildContext context,
    Jaw jaw,
    int i,
    Offset center,
    double a,
    double b,
    double theta,
  ) {
    final type = ToothType.values[i < 5 ? 4 - i : i - 5];
    final tooth = PrimaryTooth(jaw, i < 5 ? JawSide.right : JawSide.left, type);
    // Equal arc-length spacing keeps the molars and incisors evenly separated
    // even when the responsive ellipse becomes taller or wider.
    final upper = jaw == Jaw.upper;
    final x = center.dx + a * math.cos(theta);
    final y = center.dy + (upper ? -1 : 1) * (20 + b * math.sin(theta));
    final reference = referenceIds?.contains(tooth.id) ?? false;
    final erupted = referenceIds == null && eruptedIds.contains(tooth.id);
    final expected = referenceIds == null
        ? !erupted && tooth.eruptionMonths.$1 <= ageMonths
        : reference;
    final selectedPairCode = selectedReferenceId == null
        ? null
        : PrimaryTooth.all
              .where((item) => item.id == selectedReferenceId)
              .firstOrNull
              ?.pairCode;
    final selectedReference =
        referenceIds != null && selectedPairCode == tooth.pairCode;
    final state = referenceIds != null
        ? (reference
              ? 'Có thể đã bắt đầu mọc theo lịch tham khảo'
              : 'Chưa đến mốc tham khảo')
        : (erupted
              ? 'Đã mọc'
              : expected
              ? 'Có thể mọc theo tháng tuổi'
              : 'Chưa đến mốc có thể mọc');
    final toothSize = (a * 2 * .21).clamp(56.0, 76.0);
    final rotation = upper
        ? math.atan2(b * math.cos(theta), a * math.sin(theta))
        : math.atan2(b * math.cos(theta), -a * math.sin(theta));
    return Positioned(
      left: x - toothSize / 2,
      top: y - toothSize / 2,
      width: toothSize,
      height: toothSize,
      child: Semantics(
        key: Key('tooth-target-${tooth.id}'),
        button: onToothTap != null,
        label: showPairNumbers
            ? 'Cặp ${tooth.pairCode}, $state'
            : '${tooth.label}, $state',
        child: Tooltip(
          message: referenceIds != null ? '' : tooth.label,
          child: InkResponse(
            onTap: onToothTap == null ? null : () => onToothTap!(tooth),
            radius: toothSize / 2,
            child: AnimatedOpacity(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 250),
              opacity: referenceIds != null
                  ? (reference ? 1 : .55)
                  : (erupted ? 1 : .55),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Transform.rotate(
                      // The illustration's biting edge points down. Align it with
                      // the ellipse's inward normal; mirror the lower arch.
                      angle: rotation,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: ToothIllustration(
                          type: type,
                          erupted: erupted,
                          expected: expected,
                          reference: reference,
                          selectedReference: selectedReference,
                          faceRotation: -rotation,
                        ),
                      ),
                    ),
                  ),
                  if (showPairNumbers && (referenceIds != null || erupted))
                    Positioned(
                      left: toothSize / 2 - 9,
                      top: 0,
                      width: 18,
                      height: 18,
                      child: ExcludeSemantics(
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: referenceIds != null && !reference
                                ? const Color(0xFFC5AAAD)
                                : AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.2),
                          ),
                          child: Text(
                            '${tooth.pairCode}',
                            key: Key('reference-pair-${tooth.id}'),
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Calculate the arc table once for both jaws, rather than for every tooth.
  static List<double> _archAngles(double a, double b) {
    const steps = 200;
    final lengths = <double>[0];
    var previous = Offset(-a, 0);
    for (var step = 1; step <= steps; step++) {
      final angle = math.pi - step * math.pi / steps;
      final point = Offset(a * math.cos(angle), b * math.sin(angle));
      lengths.add(lengths.last + (point - previous).distance);
      previous = point;
    }
    return List.generate(10, (index) {
      final target = lengths.last * (index + .5) / 10;
      final segment = lengths.indexWhere((length) => length >= target);
      final fraction =
          (target - lengths[segment - 1]) /
          (lengths[segment] - lengths[segment - 1]);
      return math.pi - (segment - 1 + fraction) * math.pi / steps;
    });
  }
}

class ToothIllustration extends StatelessWidget {
  const ToothIllustration({
    super.key,
    this.type = ToothType.firstMolar,
    this.erupted = true,
    this.expected = false,
    this.reference = false,
    this.selectedReference = false,
    this.faceRotation = 0,
  });
  final ToothType type;
  final bool erupted;
  final bool expected;
  final bool reference;
  final bool selectedReference;
  final double faceRotation;
  @override
  Widget build(BuildContext context) {
    final colors = selectedReference
        ? const _ToothColors(
            Colors.white,
            Colors.white,
            AppColors.primary,
          )
        : reference
        ? const _ToothColors(
            Colors.white,
            Colors.white,
            Color(0xFFE58FA3),
          )
        : erupted
        ? const _ToothColors(
            Colors.white,
            Color(0xFFFFF0F3),
            Color(0xFFE58FA3),
          )
        : _ToothColors(
            const Color(0xFFFFFEFB),
            const Color(0xFFF0E9E2),
            const Color(0xFFCAB8B5),
          );
    return TweenAnimationBuilder<_ToothColors>(
      tween: _ToothColorsTween(begin: colors, end: colors),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => CustomPaint(
        size: const Size(40, 40),
        painter: _ToothPainter(
          type,
          erupted,
          expected,
          reference,
          selectedReference,
          value,
          faceRotation,
        ),
      ),
    );
  }
}

class _ToothColors {
  const _ToothColors(this.top, this.bottom, this.outline);
  final Color top;
  final Color bottom;
  final Color outline;

  @override
  bool operator ==(Object other) =>
      other is _ToothColors &&
      top == other.top &&
      bottom == other.bottom &&
      outline == other.outline;

  @override
  int get hashCode => Object.hash(top, bottom, outline);
}

class _ToothColorsTween extends Tween<_ToothColors> {
  _ToothColorsTween({required super.begin, required super.end});
  @override
  _ToothColors lerp(double t) => _ToothColors(
    Color.lerp(begin!.top, end!.top, t)!,
    Color.lerp(begin!.bottom, end!.bottom, t)!,
    Color.lerp(begin!.outline, end!.outline, t)!,
  );
}

class _MouthPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(5, 10, size.width - 10, size.height - 20);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.25, -.35),
          colors: [Color(0xFFFFF8F6), Color(0xFFFFE8EC)],
        ).createShader(rect),
    );
    canvas.drawOval(
      rect.deflate(3),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF8BBC5), Color(0xFFEA91A3), Color(0xFFF7B4C0)],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11,
    );

    final cx = size.width / 2;
    final cy = size.height / 2;
    final throatWidth = size.width * .19;
    final throatRect = Rect.fromCenter(
      center: Offset(cx, cy - 12),
      width: throatWidth * 2,
      height: 104,
    );
    canvas.drawOval(
      throatRect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, .25),
          colors: [Color(0xFFC98398), Color(0xFFE1A7B5), Color(0xFFF5D0D7)],
          stops: [0, .65, 1],
        ).createShader(throatRect),
    );

    final palate = Path()
      ..moveTo(cx - throatWidth, cy + 14)
      ..cubicTo(
        cx - throatWidth,
        cy - 83,
        cx + throatWidth,
        cy - 83,
        cx + throatWidth,
        cy + 14,
      );
    canvas.drawPath(
      palate,
      Paint()
        ..color = const Color(0xFFEFB7C3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      palate,
      Paint()
        ..color = const Color(0xFFFFDCE2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    final uvula = Path()
      ..moveTo(cx - 7, cy - 55)
      ..quadraticBezierTo(cx - 5, cy - 43, cx - 6, cy - 32)
      ..cubicTo(cx - 7, cy - 20, cx + 7, cy - 20, cx + 6, cy - 32)
      ..quadraticBezierTo(cx + 5, cy - 43, cx + 7, cy - 55)
      ..close();
    canvas.drawShadow(uvula, const Color(0x409D5269), 2, false);
    canvas.drawPath(
      uvula,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFD3DB), Color(0xFFEC9FB1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(cx - 7, cy - 55, 14, 35)),
    );

    final tongueWidth = size.width * .23;
    final tongue = Path()
      ..moveTo(cx - tongueWidth, cy + 52)
      ..cubicTo(
        cx - tongueWidth * 1.15,
        cy + 20,
        cx - tongueWidth * .75,
        cy - 5,
        cx,
        cy + 1,
      )
      ..cubicTo(
        cx + tongueWidth * .75,
        cy - 5,
        cx + tongueWidth * 1.15,
        cy + 20,
        cx + tongueWidth,
        cy + 52,
      )
      ..quadraticBezierTo(cx, cy + 80, cx - tongueWidth, cy + 52)
      ..close();
    canvas.drawShadow(tongue, const Color(0x35A65F72), 3, false);
    canvas.drawPath(
      tongue,
      Paint()
        ..shader =
            const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFC9D1), Color(0xFFEDA4B3)],
            ).createShader(
              Rect.fromLTWH(cx - tongueWidth, cy, tongueWidth * 2, 75),
            ),
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx, cy + 12)
        ..quadraticBezierTo(cx - 3, cy + 30, cx, cy + 48),
      Paint()
        ..color = const Color(0xFFD98A9C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - tongueWidth * .42, cy + 20),
        width: tongueWidth * .38,
        height: 7,
      ),
      Paint()..color = const Color(0x66FFF7F8),
    );

    for (final upper in [true, false]) {
      final arch = Path();
      for (var i = 0; i <= 60; i++) {
        final theta = math.pi - i * math.pi / 60;
        final x =
            size.width / 2 +
            (size.width / 2 - (size.width * .08 + 6)) * math.cos(theta);
        final y =
            size.height / 2 +
            (upper ? -1 : 1) * (20 + (size.height / 2 - 50) * math.sin(theta));
        if (i == 0) {
          arch.moveTo(x, y);
        } else {
          arch.lineTo(x, y);
        }
      }
      canvas.drawPath(
        arch,
        Paint()
          ..color = const Color(0xFFEDB7C0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 43
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        arch,
        Paint()
          ..color = const Color(0xFFFFE0E4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 33
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_MouthPainter oldDelegate) => false;
}

class _ToothPainter extends CustomPainter {
  _ToothPainter(
    this.type,
    this.erupted,
    this.expected,
    this.reference,
    this.selectedReference,
    this.colors,
    this.faceRotation,
  );
  final _ToothColors colors;
  final double faceRotation;
  final ToothType type;
  final bool erupted;
  final bool expected;
  final bool reference;
  final bool selectedReference;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 40, size.height / 40);
    final molar = type == ToothType.firstMolar || type == ToothType.secondMolar;
    final canine = type == ToothType.canine;
    final path = Path();
    if (molar) {
      // Plump crown and two soft lobes give the milk tooth a friendly shape.
      path.moveTo(7, 5);
      path.cubicTo(11, 1, 16, 2, 20, 5);
      path.cubicTo(25, 1, 32, 1, 35, 7);
      path.cubicTo(39, 15, 35, 25, 33, 30);
      path.cubicTo(31, 37, 27, 39, 24, 34);
      path.quadraticBezierTo(20, 31, 16, 34);
      path.cubicTo(12, 40, 8, 36, 7, 30);
      path.cubicTo(4, 23, 1, 12, 7, 5);
    } else {
      path.moveTo(9, 5);
      path.cubicTo(14, 2, 17, 4, 20, 5);
      path.cubicTo(24, 3, 29, 2, 32, 7);
      path.cubicTo(36, 14, 32, 25, 29, 31);
      if (canine) {
        path.quadraticBezierTo(20, 43, 11, 31);
      } else {
        path.cubicTo(27, 37, 23, 38, 20, 33);
        path.cubicTo(16, 38, 12, 36, 10, 31);
      }
      path.cubicTo(6, 23, 3, 11, 9, 5);
    }
    path.close();
    canvas.drawShadow(path, const Color(0x33714B52), 2, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.top, colors.bottom],
        ).createShader(const Rect.fromLTWH(0, 0, 40, 40)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 1.3
        ..color = colors.outline,
    );
    // A curved sheen keeps the center clear for the pair number.
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
      Path()
        ..moveTo(9, 14)
        ..quadraticBezierTo(8, 8, 14, 7),
      Paint()
        ..color = Colors.white.withValues(alpha: .9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawOval(
      const Rect.fromLTWH(27, 23, 4, 6),
      Paint()..color = colors.outline.withValues(alpha: .10),
    );
    canvas.restore();
    // Keep the smile upright even when its tooth follows the dental arch.
    canvas.save();
    canvas.translate(20, 20);
    canvas.rotate(faceRotation);
    final cheek = Paint()
      ..color = const Color(0xFFF3A6B4).withValues(alpha: .75);
    canvas.drawOval(const Rect.fromLTWH(-10, 0, 5, 3), cheek);
    canvas.drawOval(const Rect.fromLTWH(5, 0, 5, 3), cheek);
    final ink = Paint()..color = const Color(0xFF3D5550);
    for (final x in [-4.8, 4.8]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, -2), width: 2.6, height: 3.5),
        ink,
      );
      canvas.drawCircle(
        Offset(x - .35, -2.7),
        .5,
        Paint()..color = Colors.white,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(-3.2, 2)
        ..quadraticBezierTo(0, 6.5, 3.2, 2),
      Paint()
        ..color = const Color(0xFF3D5550)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ToothPainter oldDelegate) =>
      oldDelegate.faceRotation != faceRotation ||
      oldDelegate.colors.top != colors.top ||
      oldDelegate.colors.bottom != colors.bottom ||
      oldDelegate.colors.outline != colors.outline ||
      oldDelegate.type != type ||
      oldDelegate.erupted != erupted ||
      oldDelegate.expected != expected ||
      oldDelegate.reference != reference ||
      oldDelegate.selectedReference != selectedReference;
}

class ToothReferenceLegend extends StatelessWidget {
  const ToothReferenceLegend({super.key});

  @override
  Widget build(BuildContext context) => const Wrap(
    alignment: WrapAlignment.center,
    spacing: 18,
    runSpacing: 8,
    children: [
      _LegendDot(color: Color(0xFFE58FA3), label: 'Có thể đã mọc'),
      _LegendDot(color: Color(0xFFC5AAAD), label: 'Chưa đến mốc'),
    ],
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 9, color: color),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    ],
  );
}

class ToothChartLegend extends StatelessWidget {
  const ToothChartLegend({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 14,
    runSpacing: 8,
    children: [
      for (final item in [
        (const Color(0xFFE58FA3), 'Đã mọc'),
        (const Color(0xFFC5AAAD), 'Đến tuổi mọc'),
        (const Color(0xFFC5AAAD), 'Chưa đến tuổi'),
      ])
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: item.$1),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                item.$2,
                style: TextStyle(
                  fontSize: 11,
                  color: item.$2 == 'Đã mọc'
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: item.$2 == 'Đã mọc'
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
    ],
  );
}
