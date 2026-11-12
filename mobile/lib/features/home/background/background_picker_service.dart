import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

import 'background_draft.dart';
import 'background_files.dart';

class BackgroundPickerService {
  BackgroundPickerService({
    ImagePicker? picker,
    this.files = const BackgroundFiles(),
  }) : picker = picker ?? ImagePicker();
  final ImagePicker picker;
  final BackgroundFiles files;
  static const pendingKey = 'home_background_picker_v1';
  static const recoveredKey = 'home_background_recovered_v1';

  Future<String?> pick({
    required String accountId,
    required String childId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      pendingKey,
      jsonEncode({'accountId': accountId, 'childId': childId}),
    )) {
      throw const BackgroundImageException(
        'Chưa mở được thư viện. Vui lòng thử lại.',
      );
    }
    try {
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
        maxWidth: 8192,
        maxHeight: 8192,
      );
      if (file == null) return null;
      return await files.keepInput(file.path);
    } on PlatformException catch (error) {
      final denied =
          error.code == 'photo_access_denied' ||
          error.code == 'photo_access_restricted';
      throw BackgroundImageException(
        denied
            ? 'Chưa có quyền chọn ảnh. Bạn có thể cấp quyền Ảnh trong Cài đặt rồi thử lại.'
            : 'Không mở được thư viện. Bạn hãy thử lại.',
        canOpenSettings: denied,
      );
    } on BackgroundImageException {
      rethrow;
    } catch (_) {
      throw const BackgroundImageException(
        'Không đọc được ảnh đã chọn. Bạn hãy chọn lại.',
      );
    } finally {
      await prefs.remove(pendingKey);
    }
  }

  Future<void> openSettings() async {
    try {
      if (await permissions.openAppSettings()) return;
    } catch (_) {
      /* Show a stable recovery message instead of native details. */
    }
    throw const BackgroundImageException(
      'Bạn hãy mở Cài đặt của thiết bị, chọn ứng dụng và cấp quyền Ảnh rồi thử lại.',
      canOpenSettings: true,
    );
  }

  /// Only retrieve plugin data when our own persisted picker marker exists.
  /// Other features' gallery/video results are not consumed here.
  Future<void> recoverInterrupted() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(pendingKey);
    if (raw == null) return;
    String? path;
    try {
      final owner = jsonDecode(raw) as Map<String, dynamic>;
      if (owner['accountId'] is! String || owner['childId'] is! String) return;
      final lost = await picker.retrieveLostData();
      if (lost.files == null || lost.files!.isEmpty) return;
      path = await files.keepInput(lost.files!.first.path);
      final previous = prefs.getString(recoveredKey);
      if (previous != null) {
        try {
          await files.removePending(
            (jsonDecode(previous) as Map)['path'] as String?,
          );
        } catch (_) {
          /* Invalid old draft. */
        }
      }
      if (!await prefs.setString(
        recoveredKey,
        jsonEncode({...owner, 'path': path}),
      )) {
        await files.removePending(path);
      }
    } catch (_) {
      await files.removePending(path);
    } finally {
      await prefs.remove(pendingKey);
    }
  }

  Future<Set<String>> recoveryPaths() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(recoveredKey);
    try {
      final path = raw == null
          ? null
          : (jsonDecode(raw) as Map)['path'] as String?;
      return path == null ? {} : {path};
    } catch (_) {
      return {};
    }
  }

  Future<String?> takeRecovered({
    required String accountId,
    required String childId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(recoveredKey);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map;
      if (data['accountId'] != accountId || data['childId'] != childId) {
        return null;
      }
      await prefs.remove(recoveredKey);
      final path = data['path'] as String?;
      if (path == null ||
          !await files.isPending(path) ||
          !await File(path).exists()) {
        return null;
      }
      return path;
    } catch (_) {
      await prefs.remove(recoveredKey);
      return null;
    }
  }
}
