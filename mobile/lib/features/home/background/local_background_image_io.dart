import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

ImageProvider? localBackgroundImage(String path) => _HomeFileImage(File(path));

/// Read the small final JPEG into memory, closing its file before decoding.
/// Cached codecs then cannot lock old/temporary files during cleanup on Windows.
class _HomeFileImage extends FileImage {
  const _HomeFileImage(super.file);

  @override
  ImageStreamCompleter loadImage(FileImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(
        codec: _load(decode),
        scale: scale,
        debugLabel: 'Home background',
      );

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    try {
      if (await file.length() > 16 * 1024 * 1024) {
        throw StateError('Image too large');
      }
      return await decode(
        await ui.ImmutableBuffer.fromUint8List(await file.readAsBytes()),
      );
    } catch (_) {
      throw StateError('Không mở được ảnh nền đã lưu.');
    }
  }

  @override
  String toString() => 'Home background image';
}
