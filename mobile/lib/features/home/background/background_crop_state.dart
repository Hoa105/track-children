import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'background_frame_spec.dart';

/// Coordinates are normalized against the oriented image, independent of dp.
class BackgroundCropState extends ChangeNotifier {
  BackgroundCropState({required this.sourceSize});

  final Size sourceSize;
  // Pinch and the slider allow the same 1–5x range for every image.
  final double maxZoom = 5;
  double _zoom = 1;
  Offset _center = const Offset(.5, .5);
  double get zoom => _zoom;
  Offset get center => _center;

  Rect get normalizedRect {
    final width =
        math.min(
          1.0,
          sourceSize.height * homeBgAspectRatio / sourceSize.width,
        ) /
        _zoom;
    final height =
        width * sourceSize.width / sourceSize.height / homeBgAspectRatio;
    return Rect.fromCenter(center: _center, width: width, height: height);
  }

  void reset() {
    _zoom = 1;
    _center = const Offset(.5, .5);
    notifyListeners();
  }

  /// Preserves the source point under the initial focal point while zooming.
  /// Clamping the new center prevents empty edges on both drag and pinch.
  void gesture({
    required Rect startRect,
    required double startZoom,
    required Offset startFocal,
    required Offset focal,
    required Size viewport,
    required double scale,
  }) {
    if (viewport.isEmpty || !scale.isFinite || scale <= 0) return;
    _zoom = (startZoom * scale).clamp(1.0, maxZoom);
    final size = normalizedRect.size;
    final sourcePoint = Offset(
      startRect.left + startFocal.dx / viewport.width * startRect.width,
      startRect.top + startFocal.dy / viewport.height * startRect.height,
    );
    _center = Offset(
      (sourcePoint.dx + (.5 - focal.dx / viewport.width) * size.width).clamp(
        size.width / 2,
        1 - size.width / 2,
      ),
      (sourcePoint.dy + (.5 - focal.dy / viewport.height) * size.height).clamp(
        size.height / 2,
        1 - size.height / 2,
      ),
    );
    notifyListeners();
  }
}

/// The frame stays fixed while the entire image moves underneath it.
class BackgroundCropGeometry {
  BackgroundCropGeometry({
    required Size viewport,
    required Size source,
    required Rect normalizedRect,
  }) {
    final inset = math.min(20.0, viewport.shortestSide * .08);
    final available = Size(
      math.max(1, viewport.width - inset * 2),
      math.max(1, viewport.height - inset * 2),
    );
    final fit = math.min(
      available.width / source.width,
      available.height / source.height,
    );
    final width = math.min(
      source.width * fit,
      source.height * fit * homeBgAspectRatio,
    );
    frame = Rect.fromCenter(
      center: viewport.center(Offset.zero),
      width: width,
      height: width / homeBgAspectRatio,
    );
    final imageWidth = frame.width / normalizedRect.width;
    final imageHeight = frame.height / normalizedRect.height;
    image = Rect.fromLTWH(
      frame.left - normalizedRect.left * imageWidth,
      frame.top - normalizedRect.top * imageHeight,
      imageWidth,
      imageHeight,
    );
  }

  late final Rect frame;
  late final Rect image;
}
