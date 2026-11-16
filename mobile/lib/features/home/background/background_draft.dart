import 'background_config.dart';

/// A selection that has not changed Home or persisted preferences yet.
class BackgroundDraft {
  const BackgroundDraft({
    required this.childId,
    required this.source,
    this.croppedPath,
  });

  final String childId;
  final BackgroundSource source;
  final String? croppedPath;
}

class BackgroundFlowCancelled implements Exception {
  const BackgroundFlowCancelled();
}

class BackgroundImageException implements Exception {
  const BackgroundImageException(this.message, {this.canOpenSettings = false});
  final String message;
  final bool canOpenSettings;
  @override
  String toString() => message;
}
