import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/home/background/background_crop_state.dart';
import 'package:track_children/features/home/background/background_frame_spec.dart';
import 'package:track_children/features/home/background/background_image_service.dart';

void main() {
  for (final size in const [
    Size(3600, 2400),
    Size(2400, 3600),
    Size(6000, 1500),
    Size(3000, 3000),
  ]) {
    test('crop remains 3:2, inside the oriented source: $size', () {
      final state = BackgroundCropState(sourceSize: size);
      final random = Random(42);
      for (var i = 0; i < 300; i++) {
        final start = state.normalizedRect;
        state.gesture(
          startRect: start,
          startZoom: state.zoom,
          startFocal: const Offset(170, 100),
          focal: Offset(
            random.nextDouble() * 3000 - 1500,
            random.nextDouble() * 2000 - 1000,
          ),
          viewport: const Size(360, 240),
          scale: random.nextDouble() * 20,
        );
        final rect = state.normalizedRect;
        expect(rect.left, greaterThanOrEqualTo(-1e-9));
        expect(rect.top, greaterThanOrEqualTo(-1e-9));
        expect(rect.right, lessThanOrEqualTo(1 + 1e-9));
        expect(rect.bottom, lessThanOrEqualTo(1 + 1e-9));
        expect(
          rect.width * size.width / (rect.height * size.height),
          closeTo(homeBgAspectRatio, 1e-9),
        );
        expect(state.zoom, inInclusiveRange(1.0, state.maxZoom));
      }
      state.reset();
      expect(state.zoom, 1);
      expect(state.center, const Offset(.5, .5));
      state.dispose();
    });
  }

  test('pinch preserves the source point under the focal point', () {
    final state = BackgroundCropState(sourceSize: const Size(3600, 2400));
    final before = state.normalizedRect;
    const focal = Offset(126, 96);
    const viewport = Size(360, 240);
    Offset sourcePoint(Rect rect) => Offset(
      rect.left + focal.dx / viewport.width * rect.width,
      rect.top + focal.dy / viewport.height * rect.height,
    );
    state.gesture(
      startRect: before,
      startZoom: 1,
      startFocal: focal,
      focal: focal,
      viewport: viewport,
      scale: 2,
    );
    expect(
      (sourcePoint(before) - sourcePoint(state.normalizedRect)).distance,
      lessThan(1e-9),
    );
    state.dispose();
  });

  test(
    'zoom can exceed detail threshold; decode budgets still bound memory',
    () {
      final state = BackgroundCropState(sourceSize: const Size(2400, 1600));
      expect(state.maxZoom, 5);
      state.gesture(
        startRect: state.normalizedRect,
        startZoom: 1,
        startFocal: const Offset(.5, .5),
        focal: const Offset(.5, .5),
        viewport: const Size(1, 1),
        scale: 1e9,
      );
      expect(state.zoom, state.maxZoom);
      expect(state.normalizedRect.width * 2400, closeTo(480, 1e-9));
      expect(state.normalizedRect.height * 1600, closeTo(320, 1e-9));
      for (final size in const [
        Size(8000, 6000),
        Size(20000, 1000),
        Size(100000, 100000),
      ]) {
        for (final exporting in [false, true]) {
          final decoded = BackgroundImageService.decodeSize(
            size,
            exporting: exporting,
          );
          expect(
            decoded.width * decoded.height,
            lessThanOrEqualTo(exporting ? 12000000 : 4000000),
          );
          expect(
            decoded.longestSide,
            lessThanOrEqualTo(exporting ? 16384 : 4096),
          );
          expect(
            decoded.height,
            closeTo(decoded.width * size.height / size.width, 1.0),
          );
        }
      }
      state.dispose();
    },
  );

  for (final source in const [
    Size(1800, 2700),
    Size(3600, 2400),
    Size(6000, 1500),
  ]) {
    test('full image fits workspace and frame stays fixed: $source', () {
      final crop = BackgroundCropState(sourceSize: source);
      const viewport = Size(320, 380);
      BackgroundCropGeometry layout() => BackgroundCropGeometry(
        viewport: viewport,
        source: source,
        normalizedRect: crop.normalizedRect,
      );
      final initial = layout();
      expect(initial.frame.width / initial.frame.height, closeTo(1.5, 1e-9));
      expect(initial.image.left, greaterThanOrEqualTo(0));
      expect(initial.image.top, greaterThanOrEqualTo(0));
      expect(initial.image.right, lessThanOrEqualTo(viewport.width));
      expect(initial.image.bottom, lessThanOrEqualTo(viewport.height));
      crop.gesture(
        startRect: crop.normalizedRect,
        startZoom: 1,
        startFocal: initial.frame.center - initial.frame.topLeft,
        focal: initial.frame.center - initial.frame.topLeft,
        viewport: initial.frame.size,
        scale: 12,
      );
      final zoomed = layout();
      expect(zoomed.frame, initial.frame);
      expect(crop.zoom, lessThanOrEqualTo(5));
      expect(
        zoomed.image.width,
        closeTo(initial.image.width * crop.zoom, 1e-8),
      );
      final rect = crop.normalizedRect;
      expect(
        zoomed.image.left + rect.left * zoomed.image.width,
        closeTo(zoomed.frame.left, 1e-8),
      );
      expect(
        zoomed.image.top + rect.top * zoomed.image.height,
        closeTo(zoomed.frame.top, 1e-8),
      );
      crop.dispose();
    });
  }

  test('all image resolutions allow 5x and clamp to the 1–5x range', () {
    for (final source in const [
      Size(6000, 4000),
      Size(1080, 720),
      Size(720, 1080),
    ]) {
      final crop = BackgroundCropState(sourceSize: source);
      crop.gesture(
        startRect: crop.normalizedRect,
        startZoom: 1,
        startFocal: const Offset(.5, .5),
        focal: const Offset(.5, .5),
        viewport: const Size(1, 1),
        scale: 1000,
      );
      expect(crop.maxZoom, 5);
      expect(crop.zoom, 5);
      crop.gesture(
        startRect: crop.normalizedRect,
        startZoom: crop.zoom,
        startFocal: const Offset(.5, .5),
        focal: const Offset(.5, .5),
        viewport: const Size(1, 1),
        scale: .001,
      );
      expect(crop.zoom, 1);
      crop.dispose();
    }
  });
}
