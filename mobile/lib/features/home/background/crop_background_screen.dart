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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chỉnh sửa ảnh'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _busy ? null : widget.crop.reset,
            child: const Text('Đặt lại'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Text('Kéo, thu/phóng ảnh. Khung sáng là nền.'),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ListenableBuilder(
                listenable: widget.crop,
                builder: (_, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.crop.zoom.toStringAsFixed(1)}×',
                      key: const ValueKey('background-crop-zoom'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    Row(
                      children: [
                        const HomeUiIcon(HomeUiIconName.zoomOut),
                        Expanded(
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
                                    scale: math.exp(value) / widget.crop.zoom,
                                  ),
                          ),
                        ),
                        const HomeUiIcon(HomeUiIconName.zoomIn),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _apply,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Áp dụng'),
                    ),
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
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BackgroundCropPainter oldDelegate) =>
      image != oldDelegate.image ||
      normalizedRect != oldDelegate.normalizedRect ||
      sourceSize != oldDelegate.sourceSize;
}
