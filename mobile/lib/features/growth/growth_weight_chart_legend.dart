import 'package:flutter/material.dart';

class GrowthWeightChartLegend extends StatelessWidget {
  const GrowthWeightChartLegend({
    this.seriesColor = const Color(0xFF329B6F),
    super.key,
  });
  final Color seriesColor;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 9, color: seriesColor),
      SizedBox(width: 6),
      Flexible(
        child: Text(
          'Số đo của trẻ',
          style: TextStyle(fontSize: 13, color: Color(0xFF62738D)),
        ),
      ),
    ],
  );
}

class GrowthWeightReferenceLegend extends StatelessWidget {
  const GrowthWeightReferenceLegend({
    this.seriesColor = const Color(0xFF329B6F),
    this.regionColor = const Color(0xFFB2D6A9),
    this.medianColor = const Color(0xFF79C99B),
    super.key,
  });
  final Color seriesColor, regionColor, medianColor;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            GrowthWeightChartLegend(seriesColor: seriesColor),
            for (final entry in [
              ('Phù hợp với tuổi', regionColor),
              ('Cần chú ý', Color(0xFFFCE3C1)),
            ])
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 14, height: 10, color: entry.$2),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      entry.$1,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF62738D),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            for (final entry in [
              ('-3 SD', Color(0xFFFF8D79)),
              ('-2 SD', Color(0xFFF0BE75)),
              ('0 SD (trung vị)', medianColor),
              ('+2 SD', Color(0xFFF0BE75)),
              ('+3 SD', Color(0xFFFF8D79)),
            ])
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 14, height: 1.5, color: entry.$2),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      entry.$1,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF62738D),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    ),
  );
}
