import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'background_draft.dart';
import 'background_files.dart';
import 'background_frame_spec.dart';

class DecodedBackgroundImage {
  const DecodedBackgroundImage({
    required this.path,
    required this.image,
    required this.naturalSize,
  });
  final String path;
  final ui.Image image;
  final ui.Size naturalSize;
  void dispose() => image.dispose();
}

class BackgroundImageService {
  const BackgroundImageService({this.files = const BackgroundFiles()});
  final BackgroundFiles files;

  static ui.Size decodeSize(ui.Size size, {bool exporting = false}) {
    final budget = exporting ? 12000000.0 : 4000000.0;
    final maxSide = exporting ? 16384.0 : 4096.0;
    final factor = math.min(
      1.0,
      math.min(
        math.sqrt(budget / (size.width * size.height)),
        maxSide / math.max(size.width, size.height),
      ),
    );
    return ui.Size(
      math.max(1, (size.width * factor).floor()).toDouble(),
      math.max(1, (size.height * factor).floor()).toDouble(),
    );
  }

  Future<DecodedBackgroundImage> decode(
    String path, {
    bool exporting = false,
  }) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      if (await File(path).length() > 64 * 1024 * 1024) {
        throw const BackgroundImageException(
          'Vui lòng chọn ảnh có dung lượng tối đa 64 MB.',
        );
      }
      buffer = await ui.ImmutableBuffer.fromFilePath(path);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final natural = ui.Size(
        descriptor.width.toDouble(),
        descriptor.height.toDouble(),
      );
      if (natural.width * natural.height > 100000000) {
        throw const BackgroundImageException(
          'Vui lòng chọn ảnh có kích thước tối đa 100 MP.',
        );
      }
      final target = decodeSize(natural, exporting: exporting);
      codec = await descriptor.instantiateCodec(
        targetWidth: target.width.toInt(),
        targetHeight: target.height.toInt(),
      );
      final frame = await codec.getNextFrame();
      // Engine codecs apply encoded image orientation before exposing pixels.
      return DecodedBackgroundImage(
        path: path,
        image: frame.image,
        naturalSize: natural,
      );
    } on BackgroundImageException {
      rethrow;
    } catch (_) {
      throw const BackgroundImageException(
        'Không đọc được ảnh. Bạn hãy chọn ảnh khác.',
      );
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  void validateSize(DecodedBackgroundImage decoded) {
    final available = decodeSize(decoded.naturalSize, exporting: true);
    final width = math.min(
      available.width,
      available.height * homeBgAspectRatio,
    );
    if (width < 1080 || width / homeBgAspectRatio < 720) {
      throw const BackgroundImageException(
        'Vui lòng chọn ảnh có kích thước tối thiểu 1080 x 720 px.',
      );
    }
  }

  /// Draw only source pixels into an exact output rectangle. UI is never captured.
  Future<String> export(String sourcePath, ui.Rect normalizedRect) async {
    final decoded = await decode(sourcePath, exporting: true);
    ui.Image? output;
    ui.Picture? picture;
    String? path;
    try {
      final rect = normalizedRect;
      if (rect.isEmpty ||
          rect.left < -1e-8 ||
          rect.top < -1e-8 ||
          rect.right > 1 + 1e-8 ||
          rect.bottom > 1 + 1e-8) {
        throw const BackgroundImageException(
          'Vùng ảnh chưa hợp lệ. Bạn hãy căn chỉnh lại.',
        );
      }
      final source = ui.Rect.fromLTRB(
        rect.left * decoded.image.width,
        rect.top * decoded.image.height,
        rect.right * decoded.image.width,
        rect.bottom * decoded.image.height,
      );
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      const destination = ui.Rect.fromLTWH(
        0,
        0,
        BackgroundFrameSpec.targetWidthPx * 1.0,
        BackgroundFrameSpec.targetHeightPx * 1.0,
      );
      canvas.drawColor(const ui.Color(0xffffffff), ui.BlendMode.src);
      canvas.drawImageRect(
        decoded.image,
        source,
        destination,
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      picture = recorder.endRecording();
      output = await picture.toImage(
        BackgroundFrameSpec.targetWidthPx,
        BackgroundFrameSpec.targetHeightPx,
      );
      final raw = await output.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (raw == null) {
        throw const BackgroundImageException(
          'Chưa tạo được ảnh nền. Vui lòng thử lại.',
        );
      }
      final encoded = await compute(
        _encodeJpeg,
        raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes),
      );
      path = await files.stagePath();
      await File(path).writeAsBytes(encoded, flush: true);
      return path;
    } catch (_) {
      await files.removePending(path);
      rethrow;
    } finally {
      output?.dispose();
      picture?.dispose();
      decoded.dispose();
    }
  }
}

Uint8List _encodeJpeg(Uint8List rgba) {
  final image = img.Image.fromBytes(
    width: BackgroundFrameSpec.targetWidthPx,
    height: BackgroundFrameSpec.targetHeightPx,
    bytes: rgba.buffer,
    bytesOffset: rgba.offsetInBytes,
    numChannels: 4,
  );
  return img.encodeJpg(image, quality: 88);
}
