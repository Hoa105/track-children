import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../app_colors.dart';
import '../home_ui_icon.dart';
import 'background_config.dart';
import 'background_crop_state.dart';
import 'background_draft.dart';
import 'background_image_service.dart';

class CropBackgroundScreen extends StatefulWidget {
  const CropBackgroundScreen({
    required this.image,
    required this.crop,
    required this.onApply,
    super.key,
  });
  final DecodedBackgroundImage image;
  final BackgroundCropState crop;
  final Future<BackgroundConfig> Function() onApply;

  @override
  State<CropBackgroundScreen> createState() => _CropBackgroundScreenState();
}

class _CropBackgroundScreenState extends State<CropBackgroundScreen> {
  bool _busy = false;
  String? _error;
  Rect _startRect = Rect.zero;
  double _startZoom = 1;
  Offset _startFocal = Offset.zero;

  Future<void> _apply() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final config = await widget.onApply();
      if (mounted) Navigator.pop(context, config);
    } on BackgroundFlowCancelled {
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is BackgroundImageException ? error.message : 'Chưa áp dụng được ảnh nền. Ảnh cũ vẫn được giữ. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      backgroundColor: HomeColors.background,
      appBar: AppBar(
        backgroundColor: HomeColors.background,
        foregroundColor: HomeColors.ink,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Chỉnh sửa ảnh',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: HomeColors.ink,
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Đặt lại vị trí ban đầu',
            icon: const Icon(Icons.restart_alt_rounded, size: 22),
            color: HomeColors.primary,
            onPressed: _busy ? null : widget.crop.reset,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: HomeColors.reminderBackground.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HomeColors.iconBackground),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 16,
                    color: HomeColors.primary,
                  ),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Kéo, thu/phóng ảnh. Khung sáng là nền.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: HomeColors.ink,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final geometry = BackgroundCropGeometry(
                    viewport: constraints.biggest,
                    source: widget.crop.sourceSize,
                    normalizedRect: widget.crop.normalizedRect,
                  );
                  return ClipRect(
                    child: GestureDetector(
                      key: const ValueKey('background-crop-viewport'),
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: _busy
                          ? null
                          : (details) {
                              _startRect = widget.crop.normalizedRect;
                              _startZoom = widget.crop.zoom;
                              _startFocal =
                                  details.localFocalPoint -
                                  geometry.frame.topLeft;
                            },
                      onScaleUpdate: _busy
                          ? null
                          : (details) => widget.crop.gesture(
                              startRect: _startRect,
                              startZoom: _startZoom,
                              startFocal: _startFocal,
                              focal:
                                  details.localFocalPoint -
                                  geometry.frame.topLeft,
                              viewport: geometry.frame.size,
                              scale: details.scale,
                            ),
                      child: ListenableBuilder(
                        listenable: widget.crop,
                        builder: (_, _) => CustomPaint(
                          painter: BackgroundCropPainter(
                            widget.image.image,
                            widget.crop.normalizedRect,
                            sourceSize: widget.crop.sourceSize,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: HomeColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1429451E),
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListenableBuilder(
                    listenable: widget.crop,
                    builder: (_, _) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: HomeColors.reminderBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: HomeColors.iconBackground),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.zoom_in_rounded,
                                size: 16,
                                color: HomeColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.crop.zoom.toStringAsFixed(1)}×',
                                key: const ValueKey('background-crop-zoom'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: HomeColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : widget.crop.reset,
                          icon: const Icon(
                            Icons.refresh_rounded,
                            size: 16,
                            color: HomeColors.primary,
                          ),
                          label: const Text(
                            'Đặt lại',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: HomeColors.primary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 36),
                            side: const BorderSide(
                              color: HomeColors.iconBackground,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            backgroundColor: HomeColors.reminderBackground
                                .withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListenableBuilder(
                    listenable: widget.crop,
                    builder: (_, _) => Row(
                      children: [
                        IconButton(
                          tooltip: 'Thu nhỏ',
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: _busy || widget.crop.zoom <= 1
                              ? null
                              : () {
                                  final currentLog = math.log(widget.crop.zoom);
                                  final step = math.log(widget.crop.maxZoom) / 10;
                                  final targetLog = (currentLog - step)
                                      .clamp(0.0, math.log(widget.crop.maxZoom));
                                  final targetZoom = math.exp(targetLog);
                                  widget.crop.gesture(
                                    startRect: widget.crop.normalizedRect,
                                    startZoom: widget.crop.zoom,
                                    startFocal: const Offset(.5, .5),
                                    focal: const Offset(.5, .5),
                                    viewport: const Size(1, 1),
                                    scale: targetZoom / widget.crop.zoom,
                                  );
                                },
                          icon: const HomeUiIcon(
                            HomeUiIconName.zoomOut,
                            color: HomeColors.primary,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: HomeColors.primary,
                              inactiveTrackColor: HomeColors.iconBackground,
                              thumbColor: HomeColors.primary,
                              overlayColor:
                                  HomeColors.primary.withValues(alpha: 0.12),
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8,
                              ),
                            ),
                            child: Slider(
                              label: '${widget.crop.zoom.toStringAsFixed(1)}×',
                              min: 0,
                              max: math.log(widget.crop.maxZoom),
                              value: math.log(widget.crop.zoom),
                              onChanged: _busy || widget.crop.maxZoom <= 1
                                  ? null
                                  : (value) => widget.crop.gesture(
                                      startRect: widget.crop.normalizedRect,
                                      startZoom: widget.crop.zoom,
                                      startFocal: const Offset(.5, .5),
                                      focal: const Offset(.5, .5),
                                      viewport: const Size(1, 1),
                                      scale:
                                          math.exp(value) / widget.crop.zoom,
                                    ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Phóng to',
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: _busy ||
                                  widget.crop.zoom >= widget.crop.maxZoom
                              ? null
                              : () {
                                  final currentLog = math.log(widget.crop.zoom);
                                  final step = math.log(widget.crop.maxZoom) / 10;
                                  final targetLog = (currentLog + step)
                                      .clamp(0.0, math.log(widget.crop.maxZoom));
                                  final targetZoom = math.exp(targetLog);
                                  widget.crop.gesture(
                                    startRect: widget.crop.normalizedRect,
                                    startZoom: widget.crop.zoom,
                                    startFocal: const Offset(.5, .5),
                                    focal: const Offset(.5, .5),
                                    viewport: const Size(1, 1),
                                    scale: targetZoom / widget.crop.zoom,
                                  );
                                },
                          icon: const HomeUiIcon(
                            HomeUiIconName.zoomIn,
                            color: HomeColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .error
                                .withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 16,
                              color:
                                  Theme.of(context).colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: OutlinedButton(
                            onPressed: _busy ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: HomeColors.ink,
                              side: const BorderSide(color: Color(0xFFD4E0D1)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor: Colors.white,
                            ),
                            child: const Text(
                              'Hủy',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: FilledButton(
                            onPressed: _busy ? null : _apply,
                            style: FilledButton.styleFrom(
                              backgroundColor: HomeColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 1,
                            ),
                            child: _busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Áp dụng',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class BackgroundCropPainter extends CustomPainter {
  const BackgroundCropPainter(
    this.image,
    this.normalizedRect, {
    this.sourceSize,
  });
  final ui.Image image;
  final Rect normalizedRect;
  final Size? sourceSize;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = BackgroundCropGeometry(
      viewport: size,
      source:
          sourceSize ?? Size(image.width.toDouble(), image.height.toDouble()),
      normalizedRect: normalizedRect,
    );
    final frame = geometry.frame;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawColor(const Color(0xFF202B27), BlendMode.src);
    // Flatten transparent pixels onto the same white used by JPEG export.
    canvas.drawRect(geometry.image, Paint()..color = Colors.white);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      geometry.image,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(frame);
    canvas.drawPath(mask, Paint()..color = Colors.black.withValues(alpha: .45));
    canvas.drawRect(
      frame,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final line = Paint()
      ..color = Colors.white.withValues(alpha: .65)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(frame.left + frame.width * i / 3, frame.top),
        Offset(frame.left + frame.width * i / 3, frame.bottom),
        line,
      );
      canvas.drawLine(
        Offset(frame.left, frame.top + frame.height * i / 3),
        Offset(frame.right, frame.top + frame.height * i / 3),
        line,
      );
    }
    final corner = Paint()
      ..color = const Color(0xFFB6E34E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    const cornerLength = 16.0;
    canvas.drawLine(Offset(frame.left - 1, frame.top), Offset(frame.left + cornerLength, frame.top), corner);
    canvas.drawLine(Offset(frame.left, frame.top - 1), Offset(frame.left, frame.top + cornerLength), corner);
    canvas.drawLine(Offset(frame.right + 1, frame.top), Offset(frame.right - cornerLength, frame.top), corner);
    canvas.drawLine(Offset(frame.right, frame.top - 1), Offset(frame.right, frame.top + cornerLength), corner);
    canvas.drawLine(Offset(frame.left - 1, frame.bottom), Offset(frame.left + cornerLength, frame.bottom), corner);
    canvas.drawLine(Offset(frame.left, frame.bottom + 1), Offset(frame.left, frame.bottom - cornerLength), corner);
    canvas.drawLine(Offset(frame.right + 1, frame.bottom), Offset(frame.right - cornerLength, frame.bottom), corner);
    canvas.drawLine(Offset(frame.right, frame.bottom + 1), Offset(frame.right, frame.bottom - cornerLength), corner);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BackgroundCropPainter oldDelegate) =>
      image != oldDelegate.image ||
      normalizedRect != oldDelegate.normalizedRect ||
      sourceSize != oldDelegate.sourceSize;
}
