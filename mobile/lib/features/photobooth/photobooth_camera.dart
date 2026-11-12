import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

import 'photobooth_session.dart';

abstract interface class PhotoBoothCamera {
  bool get ready;
  bool get front;
  bool get canSwitch;
  double get aspectRatio;
  Future<void> initialize({required bool front});
  Future<PhotoBoothCapture> capture();
  Future<void> suspend();
  Future<void> discard(PhotoBoothCapture capture);
  Future<void> openSettings();
  Widget preview();
}

/// Serializes native calls: disposing or switching never races a capture/init.
class DevicePhotoBoothCamera implements PhotoBoothCamera {
  CameraController? _controller;
  List<CameraDescription> _lenses = [];
  Future<void> _tail = Future.value();
  final _captures = <String>{};

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  @override
  bool get ready =>
      _controller?.value.isInitialized == true &&
      _controller?.value.hasError == false;
  @override
  bool get front =>
      _controller?.description.lensDirection == CameraLensDirection.front;
  @override
  bool get canSwitch =>
      _lenses.any((l) => l.lensDirection == CameraLensDirection.front) &&
      _lenses.any((l) => l.lensDirection == CameraLensDirection.back);
  @override
  double get aspectRatio => ready ? 1 / _controller!.value.aspectRatio : 3 / 4;

  @override
  Future<void> initialize({required bool front}) => _serial(() async {
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      throw const PhotoBoothException(
        'Bạn hãy dùng ứng dụng Android hoặc iOS để chụp Photobooth.',
      );
    }
    final old = _controller;
    _controller = null;
    await old?.dispose();
    CameraController? next;
    try {
      _lenses = await availableCameras();
      if (_lenses.isEmpty) {
        throw const PhotoBoothException(
          'Thiết bị chưa có camera sẵn sàng. Bạn hãy thử lại.',
        );
      }
      final direction = front
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      final lens = _lenses.firstWhere(
        (lens) => lens.lensDirection == direction,
        orElse: () => _lenses.first,
      );
      next = CameraController(lens, ResolutionPreset.high, enableAudio: false);
      await next.initialize();
      await next.lockCaptureOrientation(DeviceOrientation.portraitUp);
      // The brief UI flash is an overlay; do not trigger a hardware flash.
      try {
        await next.setFlashMode(FlashMode.off);
      } on CameraException {
        /* Some cameras expose no flash. */
      }
      _controller = next;
    } catch (error) {
      try {
        await next?.dispose();
      } catch (_) {
        /* Preserve the original camera error. */
      }
      throw _failure(error, 'Chưa mở được camera. Bạn hãy thử lại.');
    }
  });

  @override
  Future<PhotoBoothCapture> capture() => _serial(() async {
    if (!ready || _controller!.value.isTakingPicture) {
      throw const PhotoBoothException('Camera chưa sẵn sàng. Bạn hãy thử lại.');
    }
    try {
      final file = await _controller!.takePicture();
      _captures.add(file.path);
      return PhotoBoothCapture(path: file.path, frontCamera: front);
    } catch (error) {
      throw _failure(
        error,
        'Chưa chụp được ảnh. Bạn hãy giữ máy ổn định và thử lại.',
      );
    }
  });

  @override
  Future<void> suspend() => _serial(() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  });

  @override
  Future<void> discard(PhotoBoothCapture capture) async {
    if (!_captures.remove(capture.path)) return;
    try {
      if (await File(capture.path).exists()) await File(capture.path).delete();
    } catch (_) {
      /* The OS can clean a locked camera cache file later. */
    }
  }

  @override
  Future<void> openSettings() async {
    try {
      if (!await permissions.openAppSettings()) {
        throw const PhotoBoothException(
          'Bạn hãy mở Cài đặt của thiết bị, chọn ứng dụng và bật quyền Camera.',
        );
      }
    } catch (_) {
      throw const PhotoBoothException(
        'Bạn hãy mở Cài đặt của thiết bị, chọn ứng dụng và bật quyền Camera.',
      );
    }
  }

  @override
  Widget preview() {
    if (!ready) return const SizedBox.shrink();
    // Native front previews are mirrored. Unmirror only the preview so it
    // matches the unmirrored still image, including any text in the scene.
    return Transform.flip(flipX: front, child: CameraPreview(_controller!));
  }

  PhotoBoothException _failure(Object error, String fallback) {
    if (error is PhotoBoothException) return error;
    if (error is CameraException) {
      return switch (error.code) {
        'CameraAccessDenied' => const PhotoBoothException(
          'Chưa có quyền Camera. Bạn hãy cấp quyền để chụp ảnh; nếu đã từ chối nhiều lần, hãy bật quyền trong Cài đặt.',
          canOpenSettings: true,
        ),
        'CameraAccessDeniedWithoutPrompt' => const PhotoBoothException(
          'Quyền Camera đang bị tắt. Bạn hãy mở Cài đặt và bật quyền cho ứng dụng.',
          canOpenSettings: true,
        ),
        'CameraAccessRestricted' => const PhotoBoothException(
          'Camera bị giới hạn trên thiết bị. Bạn hãy kiểm tra quyền Camera trong Cài đặt.',
          canOpenSettings: true,
        ),
        _ => PhotoBoothException(fallback),
      };
    }
    return PhotoBoothException(fallback);
  }
}
