import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'growth_models.dart' show GrowthMetric;

const growthGreen = Color(0xFF277B58);
const growthWeightOrange = Color(0xFFE58A42);
const growthInk = Color(0xFF25342F);
const growthMuted = Color(0xFF74817A);

Color growthUpdateAccent(GrowthMetric metric) => switch (metric) {
  GrowthMetric.weight => growthWeightOrange,
  GrowthMetric.lengthHeight => const Color(0xFF4B92C6),
  GrowthMetric.headCircumference => const Color(0xFF9468B5),
};

String growthUpdateSmile(GrowthMetric metric) => 'update-smile-${metric.name}';

double growthMeasurementToolbarHeight(BuildContext context, String title) {
  final text =
      TextPainter(
        text: TextSpan(
          text: title,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: TextDirection.ltr,
      )..layout(
        maxWidth: (MediaQuery.sizeOf(context).width - 144).clamp(
          80,
          double.infinity,
        ),
      );
  return (text.height + 16).clamp(64, double.infinity);
}

TextSpan growthMeasurementTooltipSpan({
  required String measurement,
  required String zScore,
  required String contextLabel,
  required String date,
}) => TextSpan(
  style: const TextStyle(
    fontFamily: 'Nunito',
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: Color(0xFF62738D),
  ),
  children: [
    TextSpan(
      text: '$measurement\n',
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: Color(0xFF172A4B),
      ),
    ),
    TextSpan(
      text: '$zScore\n',
      style: zScore.contains('Chưa')
          ? null
          : const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF172A4B),
            ),
    ),
    TextSpan(text: '$contextLabel\n$date'),
  ],
);

class GrowthAsset extends StatelessWidget {
  const GrowthAsset(this.name, {this.size = 32, super.key});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SvgPicture.asset(
      'assets/growth/$name.svg',
      width: size,
      height: size,
    ),
  );
}

/// Paints behind the text so the paper grows naturally with accessibility text.
class GrowthNotePaperPainter extends CustomPainter {
  const GrowthNotePaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const fold = 18.0;
    final outline = Path()
      ..moveTo(8, 7)
      ..quadraticBezierTo(w * .25, 1, w * .48, 6)
      ..quadraticBezierTo(w * .72, 10, w - 8, 4)
      ..quadraticBezierTo(w - 1, h * .25, w - 6, h * .52)
      ..quadraticBezierTo(w - 10, h * .73, w - 5, h - fold - 5)
      ..lineTo(w - fold - 5, h - 5)
      ..quadraticBezierTo(w * .7, h - 1, w * .47, h - 7)
      ..quadraticBezierTo(w * .23, h - 11, 7, h - 5)
      ..quadraticBezierTo(1, h * .76, 6, h * .49)
      ..quadraticBezierTo(10, h * .24, 8, 7)
      ..close();
    canvas.drawPath(outline, Paint()..color = const Color(0xFFFFF8DE));
    canvas.drawPath(
      outline,
      Paint()
        ..color = const Color(0xFFE4D5A6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final corner = Path()
      ..moveTo(w - 5, h - fold - 5)
      ..quadraticBezierTo(w - fold - 7, h - fold - 8, w - fold - 5, h - 5)
      ..close();
    canvas.drawPath(corner, Paint()..color = const Color(0xFFF0E3B6));
    canvas.drawPath(
      corner,
      Paint()
        ..color = const Color(0xFFD8C691)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant GrowthNotePaperPainter oldDelegate) => false;
}

class GrowthMeasurementSteps extends StatelessWidget {
  const GrowthMeasurementSteps({
    this.activeStep = 1,
    this.accent = growthGreen,
    super.key,
  });
  final int activeStep;
  final Color accent;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < 3; i++)
        Expanded(
          child: Semantics(
            label:
                'Bước ${i + 1} trên 3: ${['Nhập số đo', 'Xem kết quả', 'Lưu'][i]}',
            selected: i + 1 == activeStep,
            child: ExcludeSemantics(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: i == 0
                              ? Colors.transparent
                              : i + 1 <= activeStep
                              ? accent
                              : const Color(0xFFDCE3DD),
                        ),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i + 1 <= activeStep ? accent : Colors.white,
                          border: Border.all(
                            color: i + 1 <= activeStep
                                ? accent
                                : const Color(0xFFCAD6CE),
                          ),
                        ),
                        child: Text(
                          '${i + 1}',
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontSize: 15,
                            color: i + 1 <= activeStep
                                ? Colors.white
                                : growthMuted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: i == 2
                              ? Colors.transparent
                              : i + 1 < activeStep
                              ? accent
                              : const Color(0xFFDCE3DD),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ['Nhập số đo', 'Xem kết quả', 'Lưu'][i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: i + 1 <= activeStep ? accent : growthMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}
