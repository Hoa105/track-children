import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app_colors.dart';

/// Icons for taking photos and changing the Home background.
enum HomeUiIconName {
  photoSparkles('photo-sparkles'),
  image('image'),
  defaultCollection('default-collection'),
  camera('camera'),
  zoomOut('zoom-out'),
  zoomIn('zoom-in'),
  check('check');

  const HomeUiIconName(this.fileName);
  final String fileName;
}

class HomeUiIcon extends StatelessWidget {
  const HomeUiIcon(
    this.icon, {
    this.size = 24,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final HomeUiIconName icon;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/images/scenery/icons/ui/modern-${icon.fileName}.svg',
    width: size,
    height: size,
    colorFilter: icon == HomeUiIconName.photoSparkles && color == null
        ? null
        : ColorFilter.mode(color ?? AppColors.primary, BlendMode.srcIn),
    semanticsLabel: semanticLabel,
    excludeFromSemantics: semanticLabel == null,
  );
}
