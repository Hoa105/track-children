import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Browser dimensions are CSS pixels, matching Flutter logical layout pixels.
/// The engine can retain a pre-keyboard physical height while an input is focused.
class KeyboardInsetLayout extends StatelessWidget {
  const KeyboardInsetLayout({
    super.key,
    required this.visibleHeight,
    required this.child,
  });
  final double visibleHeight;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottom = visibleHeight.isFinite && visibleHeight > 0
        ? math.max(0.0, media.size.height - visibleHeight)
        : 0.0;
    return MediaQuery(
      data: media.copyWith(viewInsets: EdgeInsets.only(bottom: bottom)),
      child: child,
    );
  }
}
