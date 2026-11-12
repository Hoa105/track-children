/// Shared by Home previews and the crop/export flow.
const homeBgAspectRatio = 3.0 / 2.0;

abstract final class BackgroundFrameSpec {
  static const aspectRatio = homeBgAspectRatio;
  static const targetWidthPx = 1440;
  static const targetHeightPx = 960;
}
