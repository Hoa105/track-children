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
  });
  final Set<String> eruptedIds;
  final int ageMonths;
  final ValueChanged<PrimaryTooth> onToothTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = math.max(340.0, width * 1.12);
      final center = Offset(width / 2, height / 2);
      final a = width / 2 - 29;
      final b = height / 2 - 50;
      return SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _MouthPainter())),
            for (final jaw in Jaw.values)
              for (var i = 0; i < 10; i++)
                _positionTooth(context, jaw, i, center, a, b),
          ],
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
  ) {
    final type = ToothType.values[i < 5 ? 4 - i : i - 5];
    final tooth = PrimaryTooth(jaw, i < 5 ? JawSide.right : JawSide.left, type);
    // Equal arc-length spacing keeps the molars and incisors evenly separated
    // even when the responsive ellipse becomes taller or wider.
    final theta = _archAngle(i, a, b);
    final upper = jaw == Jaw.upper;
    final x = center.dx + a * math.cos(theta);
    final y = center.dy + (upper ? -1 : 1) * (20 + b * math.sin(theta));
    final erupted = eruptedIds.contains(tooth.id);
    final expected = ageMonths >= tooth.eruptionMonths.$1;
    final state = erupted
        ? 'Đã mọc'
        : expected
        ? 'Đến tuổi tham khảo'
        : 'Chưa đến tuổi tham khảo';
    return Positioned(
      left: x - 22,
      top: y - 22,
      width: 44,
      height: 44,
      child: Semantics(
        button: true,
        label: '${tooth.label}, $state',
        child: Tooltip(
          message: tooth.label,
          child: InkResponse(
            onTap: () => onToothTap(tooth),
            radius: 25,
            child: AnimatedOpacity(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 250),
              opacity: erupted || expected ? 1 : .48,
              child: Transform.rotate(
                // The illustration's biting edge points down. Align it with
                // the ellipse's inward normal; mirror the lower arch.
                angle: upper
                    ? math.atan2(b * math.cos(theta), a * math.sin(theta))
                    : math.atan2(b * math.cos(theta), -a * math.sin(theta)),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: ToothIllustration(
                    type: type,
                    erupted: erupted,
                    expected: expected,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static double _archAngle(int index, double a, double b) {
    const steps = 200;
    final lengths = <double>[0];
    var previous = Offset(-a, 0);
    for (var step = 1; step <= steps; step++) {
      final angle = math.pi - step * math.pi / steps;
      final point = Offset(a * math.cos(angle), b * math.sin(angle));
      lengths.add(lengths.last + (point - previous).distance);
      previous = point;
    }
    final target = lengths.last * (index + .5) / 10;
    final segment = lengths.indexWhere((length) => length >= target);
    final fraction =
        (target - lengths[segment - 1]) /
        (lengths[segment] - lengths[segment - 1]);
    return math.pi - (segment - 1 + fraction) * math.pi / steps;
  }
}

class ToothIllustration extends StatelessWidget {
  const ToothIllustration({
    super.key,
    this.type = ToothType.firstMolar,
    this.erupted = true,
    this.expected = false,
  });
  final ToothType type;
  final bool erupted;
  final bool expected;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(40, 40),
    painter: _ToothPainter(type, erupted, expected),
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
          colors: [Color(0xFFF3DCE0), Color(0xFFFAECEE)],
        ).createShader(rect),
    );
    final cx = size.width / 2;
    final cy = size.height / 2;
    // Soft palate and throat sit behind the tongue and dental arches.
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
          colors: [Color(0xFF995D70), Color(0xFFBE8091), Color(0xFFE7AAB8)],
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
        ..color = const Color(0xFFE9AFBC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      palate,
      Paint()
        ..color = const Color(0xFFF2C3CD)
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
    canvas.drawShadow(uvula, const Color(0xFF90566A), 2, false);
    canvas.drawPath(
      uvula,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFF2BBC9), Color(0xFFD78FA5)],
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
    canvas.drawShadow(tongue, const Color(0xFFBB7E89), 3, false);
    canvas.drawPath(
      tongue,
      Paint()
        ..shader =
            const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF3B1BE), Color(0xFFDC8F9F)],
            ).createShader(
              Rect.fromLTWH(cx - tongueWidth, cy, tongueWidth * 2, 75),
            ),
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx, cy + 12)
        ..quadraticBezierTo(cx - 3, cy + 30, cx, cy + 48),
      Paint()
        ..color = const Color(0xFFC97D90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    for (final upper in [true, false]) {
      final path = Path();
      for (var i = 0; i <= 60; i++) {
        final theta = math.pi - i * math.pi / 60;
        final x = size.width / 2 + (size.width / 2 - 29) * math.cos(theta);
        final y =
            size.height / 2 +
            (upper ? -1 : 1) * (20 + (size.height / 2 - 50) * math.sin(theta));
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFE9AFB8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 43
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFF4C5CC)
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
  _ToothPainter(this.type, this.erupted, this.expected);
  final ToothType type;
  final bool erupted;
  final bool expected;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 40, size.height / 40);
    final molar = type == ToothType.firstMolar || type == ToothType.secondMolar;
    final canine = type == ToothType.canine;
    final path = Path();
    if (molar) {
      path.moveTo(7, 5);
      path.cubicTo(12, 0, 17, 5, 20, 4);
      path.cubicTo(26, 0, 36, 2, 36, 12);
      path.cubicTo(40, 24, 33, 37, 28, 37);
      path.quadraticBezierTo(23, 40, 20, 34);
      path.quadraticBezierTo(11, 42, 6, 32);
      path.cubicTo(1, 24, 1, 10, 7, 5);
    } else {
      path.moveTo(9, 5);
      path.quadraticBezierTo(20, 1, 31, 5);
      path.cubicTo(36, 12, 34, 26, 29, 31);
      path.quadraticBezierTo(24, 35, 20, canine ? 39 : 34);
      path.quadraticBezierTo(12, 37, 8, 29);
      path.quadraticBezierTo(3, 15, 9, 5);
    }
    path.close();
    canvas.drawShadow(path, const Color(0xFF8E5963), 2, false);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: erupted
              ? [Colors.white, const Color(0xFFFFFDF3), const Color(0xFFE4DDCF)]
              : [const Color(0xFFFAEFEA), const Color(0xFFEAD5D3)],
        ).createShader(const Rect.fromLTWH(0, 0, 40, 40)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = expected && !erupted ? 1.8 : 1
        ..color = erupted
            ? const Color(0xFFB5B49F)
            : expected
            ? const Color(0xFFD6A34C)
            : const Color(0xFFC5AAAD),
    );
    final groove = Path();
    if (molar) {
      groove.moveTo(11, 13);
      groove.quadraticBezierTo(20, 22, 29, 13);
      groove.moveTo(20, 19);
      groove.lineTo(18, 29);
    } else {
      groove.moveTo(12, 11);
      groove.quadraticBezierTo(20, 8, 28, 11);
    }
    canvas.drawPath(
      groove,
      Paint()
        ..color = const Color(0xFFCCC4B5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
    if (erupted) {
      canvas.drawCircle(
        const Offset(31, 32),
        5,
        Paint()..color = AppColors.primary,
      );
      canvas.drawPath(
        Path()
          ..moveTo(28.5, 32)
          ..lineTo(30.3, 34)
          ..lineTo(33.5, 30),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ToothPainter oldDelegate) =>
      oldDelegate.type != type ||
      oldDelegate.erupted != erupted ||
      oldDelegate.expected != expected;
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
        (AppColors.primary, 'Đã mọc'),
        (const Color(0xFFD6A34C), 'Đến tuổi mọc'),
        (const Color(0xFFC5AAAD), 'Chưa đến tuổi'),
      ])
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: item.$1),
            const SizedBox(width: 5),
            Flexible(
              child: Text(item.$2, style: const TextStyle(fontSize: 11)),
            ),
          ],
        ),
    ],
  );
}
