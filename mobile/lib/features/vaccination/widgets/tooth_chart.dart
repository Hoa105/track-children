import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/tooth.dart';

/// Upper and lower primary-teeth arches (10 teeth each), drawn from the
/// viewer's point of view — the child's right side is on the left.
/// Erupted teeth are filled green; teeth whose typical eruption window the
/// child is currently in are outlined amber.
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

  static const _height = 280.0;
  static const _jawGap = 36.0;

  /// Right-side molar → right central incisor, then left central → left molar.
  static List<PrimaryTooth> _arch(Jaw jaw) => [
        for (final type in ToothType.values.reversed) PrimaryTooth(jaw, JawSide.right, type),
        for (final type in ToothType.values) PrimaryTooth(jaw, JawSide.left, type),
      ];

  static double _radius(ToothType type) => switch (type) {
        ToothType.firstMolar || ToothType.secondMolar => 17,
        ToothType.canine => 15,
        _ => 13,
      };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cx = width / 2;
        final a = width / 2 - 22;
        final b = _height / 2 - _jawGap / 2 - 22;
        final children = <Widget>[];

        for (final jaw in Jaw.values) {
          final arch = _arch(jaw);
          final cy = jaw == Jaw.upper ? _height / 2 - _jawGap / 2 : _height / 2 + _jawGap / 2;
          for (var i = 0; i < arch.length; i++) {
            final tooth = arch[i];
            final theta = math.pi - (i + 0.5) / arch.length * math.pi;
            final r = _radius(tooth.type);
            final x = cx + a * math.cos(theta);
            final y = jaw == Jaw.upper ? cy - b * math.sin(theta) : cy + b * math.sin(theta);
            children.add(Positioned(
              left: x - r,
              top: y - r,
              child: _ToothDot(
                radius: r,
                erupted: eruptedIds.contains(tooth.id),
                expectedNow: ageMonths >= tooth.eruptionMonths.$1,
                onTap: () => onToothTap(tooth),
              ),
            ));
          }
        }

        return SizedBox(
          height: _height,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: _height / 2 - _jawGap / 2 - 40,
                child: Text('Hàm trên', textAlign: TextAlign.center, style: AppTextStyles.caption),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: _height / 2 + _jawGap / 2 + 24,
                child: Text('Hàm dưới', textAlign: TextAlign.center, style: AppTextStyles.caption),
              ),
              Positioned(
                left: 0,
                top: _height / 2 - 8,
                child: Text('Phải', style: AppTextStyles.caption),
              ),
              Positioned(
                right: 0,
                top: _height / 2 - 8,
                child: Text('Trái', style: AppTextStyles.caption),
              ),
              ...children,
            ],
          ),
        );
      },
    );
  }
}

class _ToothDot extends StatelessWidget {
  const _ToothDot({
    required this.radius,
    required this.erupted,
    required this.expectedNow,
    required this.onTap,
  });

  final double radius;
  final bool erupted;
  final bool expectedNow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = erupted
        ? AppColors.primaryDark
        : expectedNow
            ? AppColors.amber
            : AppColors.borderAlt2;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          color: erupted ? AppColors.primary : AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: expectedNow && !erupted ? 2 : 1.5),
        ),
      ),
    );
  }
}

/// Legend row explaining the chart colors.
class ToothChartLegend extends StatelessWidget {
  const ToothChartLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(Color fill, Color border, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: Border.all(color: border, width: 1.5),
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: AppTextStyles.caption),
          ],
        );
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        item(AppColors.primary, AppColors.primaryDark, 'Đã mọc'),
        item(AppColors.surface, AppColors.amber, 'Đến tuổi mọc'),
        item(AppColors.surface, AppColors.borderAlt2, 'Chưa đến tuổi'),
      ],
    );
  }
}
