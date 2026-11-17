import 'package:image_picker/image_picker.dart';
import 'package:track_children/services/journal_media.dart';

/// Records copies instead of writing to the app folder (no path_provider in tests).
class FakeMediaFiles extends JournalMediaFiles {
  final files = <String, List<int>>{};

  @override
  Future<String> keep(XFile file, String id) async {
    final path = '/media/$id-${file.name}';
    files[path] = await file.readAsBytes();
    return path;
  }

  @override
  Future<String> keepBytes(List<int> bytes, String id, String ext) async {
    final path = '/media/$id$ext';
    files[path] = bytes;
    return path;
  }

  @override
  Future<bool> exists(String path) async => files.containsKey(path);

  @override
  Future<void> remove(String path) async => files.remove(path);
}
