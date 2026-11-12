import 'package:flutter/material.dart';

import '../../../app_colors.dart';
import '../home_ui_icon.dart';
import 'background_config.dart';
import 'background_frame_spec.dart';
import 'local_background_image.dart';

/// The image, loading state and all fallbacks occupy exactly the same frame.
class HomeBackgroundFrame extends StatelessWidget {
  const HomeBackgroundFrame({
    required this.source,
    this.assetPath,
    this.finalLocalPath,
    this.loading = false,
    this.overlay,
    this.header,
    super.key,
  });

  final BackgroundSource source;
  final String? assetPath;
  final String? finalLocalPath;
  final bool loading;
  final Widget? overlay;
  final Widget? header;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final decodeWidth =
          (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
              .ceil()
              .clamp(1, BackgroundFrameSpec.targetWidthPx);
      Widget asset({String? status}) => Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.background),
          if (assetPath != null)
            Image.asset(
              assetPath!,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              cacheWidth: decodeWidth,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: AppColors.background),
            ),
          if (status != null)
            Positioned(
              top: 12,
              left: 16,
              right: 80,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    status,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
      final path = finalLocalPath;
      final custom = source != BackgroundSource.defaultImage;
      final provider = custom && path != null && path.isNotEmpty
          ? localBackgroundImage(path)
          : null;
      const missing = 'Không mở được ảnh đã lưu. Đang dùng ảnh mặc định.';
      Widget content() => Stack(
        fit: StackFit.expand,
        children: [
          if (!custom || loading)
            asset()
          else if (provider == null)
            asset(status: missing)
          else
            Image(
              key: ValueKey((source, path)),
              image: ResizeImage.resizeIfNeeded(decodeWidth, null, provider),
              fit: BoxFit.cover,
              alignment: Alignment.center,
              gaplessPlayback: false,
              excludeFromSemantics: true,
              frameBuilder: (_, child, frame, synchronous) {
                if (frame == null && !synchronous) {
                  return Semantics(
                    label: 'Đang tải ảnh nền',
                    child: const ColoredBox(
                      color: AppColors.background,
                      child: Center(
                        child: HomeUiIcon(
                          HomeUiIconName.image,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }
                return child;
              },
              errorBuilder: (_, _, _) {
                return asset(status: missing);
              },
            ),
          ?overlay,
          if (loading)
            const Positioned(
              top: 16,
              left: 16,
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  semanticsLabel: 'Đang tải ảnh nền',
                ),
              ),
            ),
        ],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null)
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE3F0E7), AppColors.background],
                ),
              ),
              child: header!,
            ),
          AspectRatio(
            key: const ValueKey('home-background-frame'),
            aspectRatio: homeBgAspectRatio,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              child: content(),
            ),
          ),
        ],
      );
    },
  );
}
