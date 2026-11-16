import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../home/background/background_image_service.dart';
import 'photobooth_session.dart';

abstract interface class PhotoBoothShotStore {
  Future<LocalPhoto> save(PhotoBoothSession session, PhotoBoothCapture capture);
  Future<void> remove(PhotoBoothSession session, LocalPhoto photo);
  Future<void> clear(PhotoBoothSession session);
  Future<void> handoff(PhotoBoothSession session);
}

/// Session files are independent from Home's pending and applied backgrounds.
class PhotoBoothFiles implements PhotoBoothShotStore {
  const PhotoBoothFiles({this.rootPath});
  final String? rootPath;

  Future<String> _root() async => p.normalize(
    p.absolute(
      rootPath ??
          p.join(
            (await getApplicationDocumentsDirectory()).path,
            'photobooth_sessions_v1',
          ),
    ),
  );

  String _scope(String value) =>
      base64Url.encode(utf8.encode(value)).replaceAll('=', '');

  Future<String> directory(PhotoBoothSession session) async {
    final root = await _root();
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(session.sessionId)) {
      throw const PhotoBoothException(
        'Phiên chụp không hợp lệ. Bạn hãy mở lại Photobooth.',
      );
    }
    final path = p.join(
      root,
      _scope(session.accountId),
      _scope(session.childId),
      session.sessionId,
    );
    if (!p.isWithin(root, path)) {
      throw const PhotoBoothException('Không mở được phiên chụp.');
    }
    return path;
  }

  @override
  Future<LocalPhoto> save(
    PhotoBoothSession session,
    PhotoBoothCapture capture,
  ) async {
    // The shared engine decoder handles EXIF rotation and bounds preview memory.
    final decoded = await const BackgroundImageService().decode(capture.path);
    String? part;
    String? destination;
    try {
      final raw = await decoded.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (raw == null) {
        throw const PhotoBoothException(
          'Chưa đọc được ảnh vừa chụp. Bạn hãy chụp lại.',
        );
      }
      final bytes = await compute(_encodePhoto, (
        raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes),
        decoded.image.width,
        decoded.image.height,
      ));
      final folder = Directory(await directory(session));
      await folder.create(recursive: true);
      final id = List.generate(
        16,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      destination = p.join(folder.path, '$id.jpg');
      part = '$destination.part';
      await File(part).writeAsBytes(bytes, flush: true);
      await File(part).rename(destination);
      return LocalPhoto(
        path: destination,
        width: decoded.image.width,
        height: decoded.image.height,
        capturedAt: DateTime.now(),
        frontCamera: capture.frontCamera,
      );
    } catch (_) {
      for (final path in [part, destination]) {
        if (path != null) {
          try {
            if (await File(path).exists()) await File(path).delete();
          } catch (_) {
            /* Retry cleanup on session close. */
          }
        }
      }
      rethrow;
    } finally {
      decoded.dispose();
    }
  }

  @override
  Future<void> remove(PhotoBoothSession session, LocalPhoto photo) async {
    final folder = await directory(session);
    final path = p.normalize(p.absolute(photo.path));
    if (p.isWithin(folder, path)) {
      try {
        if (await File(path).exists()) await File(path).delete();
      } catch (_) {
        /* Session cleanup can retry. */
      }
    }
  }

  @override
  Future<void> clear(PhotoBoothSession session) async {
    final folder = Directory(await directory(session));
    try {
      if (await folder.exists()) await folder.delete(recursive: true);
    } catch (_) {
      /* Old sessions are pruned on the next visit. */
    }
  }

  @override
  Future<void> handoff(PhotoBoothSession session) async {
    if (!session.complete) {
      throw const PhotoBoothException(
        'Bạn hãy chọn đủ ảnh vào khung trước khi tiếp tục.',
      );
    }
    final folder = Directory(await directory(session));
    await folder.create(recursive: true);
    final file = File(p.join(folder.path, 'session.json'));
    final pending = File('${file.path}.part');
    await pending.writeAsString(session.toJson(), flush: true);
    if (await file.exists()) await file.delete();
    await pending.rename(file.path);
  }

  /// Only abandoned sessions in this account/child scope, older than 24 hours.
  Future<void> prune(PhotoBoothSession active) async {
    final activePath = await directory(active);
    final parent = Directory(p.dirname(activePath));
    if (!await parent.exists()) return;
    final cutoff = DateTime.now().subtract(const Duration(days: 1));
    await for (final entry in parent.list(followLinks: false)) {
      if (entry is! Directory ||
          entry.path == activePath ||
          !RegExp(r'^[a-f0-9]{32}$').hasMatch(p.basename(entry.path)) ||
          !p.isWithin(parent.path, entry.path)) {
        continue;
      }
      try {
        if ((await entry.stat()).modified.isBefore(cutoff)) {
          await entry.delete(recursive: true);
        }
      } catch (_) {
        /* An active or locked session is left alone. */
      }
    }
  }
}

Uint8List _encodePhoto((Uint8List, int, int) input) {
  final image = img.Image.fromBytes(
    width: input.$2,
    height: input.$3,
    bytes: input.$1.buffer,
    bytesOffset: input.$1.offsetInBytes,
    numChannels: 4,
  );
  return img.encodeJpg(image, quality: 92);
}
