import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../home/background/background_image_service.dart';
import 'photobooth_catalog.dart';
import 'photobooth_edit.dart';
import 'photobooth_session.dart';

/// Bounded decoded images shared by painter and export. No file handles retained.
class PhotoBoothImages {
  PhotoBoothImages({this.spareCacheBytes = 12 * 1024 * 1024});
  final int spareCacheBytes;
  final photos = <ui.Image>[];
  final assets = <String, ui.Image>{};
  bool _disposed = false;
  bool get disposed => _disposed;
  Future<void> loadPhotos(PhotoBoothSession session) async {
    try {
      for (final photo in session.selectedPhotos) {
        final decoded = await const BackgroundImageService().decode(photo.path);
        if (_disposed) {
          decoded.dispose();
          return;
        }
        photos.add(decoded.image);
      }
    } catch (_) {
      dispose();
      rethrow;
    }
  }

  Future<void> loadAsset(String path) async {
    if (_disposed) return;
    final cached = assets.remove(path);
    if (cached != null) {
      assets[path] = cached; // Touch the bounded LRU without decoding again.
      return;
    }
    final bytes = await rootBundle.load(path);
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final limit = path.contains('/frames/') ? 1800.0 : 1024.0;
      final scale = math.min(
        1.0,
        limit / math.max(descriptor.width, descriptor.height),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      final image = (await codec.getNextFrame()).image;
      if (_disposed || assets.containsKey(path)) {
        image.dispose();
      } else {
        assets[path] = image;
      }
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  /// Active images stay alive; recently used inactive images share a byte limit.
  void retainAssets(Set<String> paths) {
    var spare = 0;
    for (final path in assets.keys.toList().reversed) {
      if (paths.contains(path)) continue;
      final image = assets[path]!;
      final bytes = image.width * image.height * 4;
      if (spare + bytes <= spareCacheBytes) {
        spare += bytes;
      } else {
        assets.remove(path)?.dispose();
      }
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final image in [...photos, ...assets.values]) {
      image.dispose();
    }
    photos.clear();
    assets.clear();
  }
}

enum PhotoBoothPaintLayer { all, photos, frame, stickers }

class PhotoBoothPainter extends CustomPainter {
  const PhotoBoothPainter({
    required this.frame,
    required this.draft,
    required this.catalog,
    required this.images,
    this.liveEditor,
    this.layer = PhotoBoothPaintLayer.all,
    this.filterQuality = FilterQuality.high,
    super.repaint,
  });
  final PhotoBoothFrame frame;
  final PhotoBoothEdit draft;
  final PhotoBoothCatalog catalog;
  final PhotoBoothImages images;
  final PhotoBoothEditorController? liveEditor;
  final PhotoBoothPaintLayer layer;
  final FilterQuality filterQuality;

  @override
  void paint(Canvas canvas, Size size) {
    final current = liveEditor?.draft ?? draft;
    canvas.save();
    canvas.scale(
      size.width / frame.size.width,
      size.height / frame.size.height,
    );
    canvas.clipRect(Offset.zero & frame.size);
    final paint = Paint()..filterQuality = filterQuality;
    if (layer == PhotoBoothPaintLayer.all ||
        layer == PhotoBoothPaintLayer.photos) {
      canvas.drawRect(Offset.zero & frame.size, Paint()..color = Colors.white);
      for (final slot in frame.slots) {
        if (slot.photo >= images.photos.length) continue;
        final photo = images.photos[slot.photo];
        final transform =
            current.photos[slot.photo] ?? const PhotoBoothPhotoTransform();
        canvas.save();
        canvas.clipRect(slot.rect);
        canvas.drawImageRect(
          photo,
          transform.sourceRect(
            Size(photo.width.toDouble(), photo.height.toDouble()),
            slot.rect.size,
          ),
          slot.rect,
          paint,
        );
        canvas.restore();
      }
    }
    final overlay = images.assets[frame.asset];
    if (overlay != null &&
        (layer == PhotoBoothPaintLayer.all ||
            layer == PhotoBoothPaintLayer.frame)) {
      canvas.drawImageRect(
        overlay,
        Rect.fromLTWH(
          0,
          0,
          overlay.width.toDouble(),
          overlay.height.toDouble(),
        ),
        Offset.zero & frame.size,
        paint,
      );
    }
    if (layer == PhotoBoothPaintLayer.all ||
        layer == PhotoBoothPaintLayer.stickers) {
      for (final sticker in current.stickers) {
        final asset = catalog.sticker(sticker.assetKey);
        final image = images.assets[asset.asset];
        if (image == null) continue;
        final extent = sticker.extent(frame.size, asset.size);
        canvas.save();
        canvas.translate(
          sticker.x * frame.size.width,
          sticker.y * frame.size.height,
        );
        canvas.rotate(sticker.rotation);
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromCenter(
            center: Offset.zero,
            width: extent.width,
            height: extent.height,
          ),
          paint,
        );
        canvas.restore();
      }
    }
    canvas.restore();
  }

  Future<ui.Image> render() async {
    final recorder = ui.PictureRecorder();
    paint(Canvas(recorder), frame.size);
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(
        frame.size.width.toInt(),
        frame.size.height.toInt(),
      );
    } finally {
      picture.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant PhotoBoothPainter oldDelegate) {
    if (oldDelegate.frame != frame ||
        oldDelegate.images != images ||
        oldDelegate.layer != layer ||
        oldDelegate.filterQuality != filterQuality) {
      return true;
    }
    return switch (layer) {
      PhotoBoothPaintLayer.photos => !identical(
        oldDelegate.draft.photos,
        draft.photos,
      ),
      PhotoBoothPaintLayer.frame => false,
      PhotoBoothPaintLayer.stickers => !identical(
        oldDelegate.draft.stickers,
        draft.stickers,
      ),
      PhotoBoothPaintLayer.all => oldDelegate.draft != draft,
    };
  }
}
