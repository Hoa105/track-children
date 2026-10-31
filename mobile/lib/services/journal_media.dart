import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copies of diary photos / videos kept in the app folder: they are uploaded
/// from here (also after a restart while offline) and shown without network.
///
/// Media item maps stored in a journal entry (`media`):
/// `{id, type: image|video, path?, uploaded, rejected?, url?, expiresAt?}`.
class JournalMediaFiles {
  /// Replaced in tests.
  static JournalMediaFiles instance = JournalMediaFiles();

  Future<Directory> _dir() async {
    final dir = Directory(
      p.join((await getApplicationDocumentsDirectory()).path, 'journal_media'),
    );
    return dir.create(recursive: true);
  }

  /// Copies a picked file (camera files live in a cache the OS may clear).
  Future<String> keep(XFile file, String id) async {
    final ext = p.extension(file.path).toLowerCase();
    final path = p.join((await _dir()).path, '$id$ext');
    await file.saveTo(path);
    return path;
  }

  Future<String> keepBytes(List<int> bytes, String id, String ext) async {
    final file = File(p.join((await _dir()).path, '$id$ext'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<bool> exists(String path) => File(path).exists();

  Future<void> remove(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Đã xóa / không còn
    }
  }
}
