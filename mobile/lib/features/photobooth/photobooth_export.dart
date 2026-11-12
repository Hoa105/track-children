import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'photobooth_renderer.dart';
import 'photobooth_session.dart';

class PhotoBoothOutputStore {
  const PhotoBoothOutputStore({this.rootPath});
  final String? rootPath;
  Future<String> directory(PhotoBoothSession session) async {
    String scope(String value) =>
        base64Url.encode(utf8.encode(value)).replaceAll('=', '');
    return p.join(
      rootPath ??
          p.join(
            (await getApplicationDocumentsDirectory()).path,
            'photobooth_exports_v1',
          ),
      scope(session.accountId),
      scope(session.childId),
    );
  }

  /// Published exports deliberately outlive the temporary capture session.
  Future<String> write(PhotoBoothSession session, Uint8List bytes) async {
    final folder = Directory(await directory(session));
    await folder.create(recursive: true);
    final id = List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final file = File(p.join(folder.path, '$id.png'));
    final partial = File('${file.path}.part');
    try {
      await partial.writeAsBytes(bytes, flush: true);
      await partial.rename(file.path);
      return file.path;
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }
}

class PhotoBoothExporter {
  const PhotoBoothExporter({this.files = const PhotoBoothOutputStore()});
  final PhotoBoothOutputStore files;

  Future<String> export(
    PhotoBoothSession session,
    PhotoBoothPainter painter,
  ) async {
    final image = await painter.render();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw const PhotoBoothException('Chưa xuất được ảnh. Bạn hãy thử lại.');
      }
      return await files.write(
        session,
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  }
}

class PhotoBoothGallery {
  const PhotoBoothGallery();
  static const channel = MethodChannel('be_lon_khon/photobooth_gallery');

  Future<void> save(String path) async {
    try {
      if (await channel.invokeMethod<bool>('saveImage', {'path': path}) !=
          true) {
        throw const PhotoBoothException(
          'Chưa lưu được ảnh vào thư viện. Bạn hãy thử lại.',
        );
      }
    } on PlatformException catch (error) {
      if (error.code == 'permission_denied') {
        throw const PhotoBoothException(
          'Bạn hãy cho phép lưu ảnh trong Cài đặt để lưu bộ ảnh về máy.',
          canOpenSettings: true,
        );
      }
      throw const PhotoBoothException(
        'Chưa lưu được ảnh vào thư viện. Ảnh thành phẩm vẫn được giữ, bạn hãy thử lại.',
      );
    } on MissingPluginException {
      throw const PhotoBoothException(
        'Bạn hãy dùng ứng dụng Android hoặc iOS để lưu ảnh về máy.',
      );
    }
  }
}
