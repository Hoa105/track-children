import 'package:flutter/material.dart';

import '../../app_colors.dart';

class GrowthWeightVelocityHeader extends StatelessWidget {
  const GrowthWeightVelocityHeader({
    required this.grams,
    required this.delta,
    required this.easyRead,
    this.recordingOnly = false,
    this.period = 1,
    super.key,
  });
  final bool recordingOnly;
  final int period;
  final int? grams, delta;
  final bool easyRead;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final large = easyRead || MediaQuery.textScalerOf(context).scale(14) > 20;
      final change = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            delta == null
                ? 'Chưa có dữ liệu so sánh'
                : delta == 0
                ? 'Bằng kỳ trước'
                : '${delta! > 0 ? 'Nhiều hơn' : 'Ít hơn'} ${delta!.abs()}\u00A0g',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: large ? 'Nunito' : 'DancingScript',
              fontSize: large ? 20 : 21,
              fontWeight: FontWeight.w900,
              color: WeightChartColors.data,
            ),
          ),
          const SizedBox(height: 3),
          if (!recordingOnly)
            Text(
              period == 1 ? 'so với tháng trước' : 'so với kỳ trước',
              style: TextStyle(
                fontFamily: large ? 'Nunito' : 'DancingScript',
                fontSize: large ? 17 : 15,
                color: WeightChartColors.heroInk,
              ),
            ),
        ],
      );
      final value = grams == null
          ? const Text(
              'Chưa đủ dữ liệu',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: WeightChartColors.data,
              ),
            )
          : FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text:
                        '${grams! > 0
                            ? '+'
                            : grams! < 0
                            ? '−'
                            : ''}${grams!.abs()}',
                    style: TextStyle(
                      fontSize: large
                          ? 48
                          : constraints.maxWidth < 330
                          ? 38
                          : 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                    ),
                  ),
                  TextSpan(
                    text: '\u00A0g',
                    style: TextStyle(
                      fontSize: large ? 24 : 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                fontFamily: 'Nunito',
                color: WeightChartColors.data,
                height: 1.12,
              ),
            ));
      return CustomPaint(
        painter: large ? null : const GrowthWeightHeaderDoodle(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recordingOnly
                    ? 'Mức tăng cân kỳ gần nhất'
                    : period == 1
                    ? 'Tốc độ tăng cân tháng gần nhất'
                    : 'Mức tăng cân trong $period tháng',
                style: TextStyle(
                  fontFamily: large ? 'Nunito' : 'DancingScript',
                  fontSize: large ? 20 : 21,
                  fontWeight: FontWeight.w700,
                  color: WeightChartColors.heroInk,
                ),
              ),
              SizedBox(height: large ? 10 : 4),
              if (!large)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: value),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: change,
                      ),
                    ),
                  ],
                )
              else ...[
                value,
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerRight, child: change),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class GrowthWeightHeaderDoodle extends CustomPainter {
  const GrowthWeightHeaderDoodle({this.color = WeightChartColors.data});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final stroke = Path()
      ..moveTo(5, size.height - 4)
      ..quadraticBezierTo(
        size.width * .2,
        size.height - 8,
        size.width * .43,
        size.height - 5,
      );
    canvas.drawPath(stroke, paint..strokeWidth = 2);
    canvas.drawLine(
      Offset(size.width * .45, size.height - 5),
      Offset(size.width * .47, size.height - 6),
      paint..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant GrowthWeightHeaderDoodle oldDelegate) => oldDelegate.color != color;
}
