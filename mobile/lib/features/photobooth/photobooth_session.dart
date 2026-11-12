import 'dart:convert';
import 'dart:math';

enum PhotoBoothDuration {
  fifteen(15),
  thirty(30),
  sixty(60);

  const PhotoBoothDuration(this.seconds);
  final int seconds;
  int get estimatedPhotos => seconds ~/ 3;
}

/// The output layout is chosen after capture, independently of the photo pool.
enum PhotoBoothMode {
  two(2),
  four(4);

  const PhotoBoothMode(this.count);
  final int count;
}

enum CapturePhase {
  idle,
  initializing,
  ready,
  countingDown,
  capturing,
  breakBetweenShots,
  reviewing,
  paused,
  editing,
  error,
}

class LocalPhoto {
  const LocalPhoto({
    required this.path,
    required this.width,
    required this.height,
    required this.capturedAt,
    required this.frontCamera,
  });

  final String path;
  final int width;
  final int height;
  final DateTime capturedAt;
  final bool frontCamera;

  Map<String, Object> toJson() => {
    'path': path,
    'width': width,
    'height': height,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    'frontCamera': frontCamera,
  };
}

/// Ordered originals for the editor. A photostrip or Home collage is not a shot.
class PhotoBoothSession {
  PhotoBoothSession({
    required this.sessionId,
    required this.accountId,
    required this.childId,
    this.mode = PhotoBoothMode.two,
    this.duration = PhotoBoothDuration.thirty,
    required this.createdAt,
    List<LocalPhoto> shots = const [],
    List<int?>? selectedIndices,
  }) : shots = List.unmodifiable(shots),
       selectedIndices = List.unmodifiable(
         selectedIndices ?? List<int?>.filled(mode.count, null),
       ) {
    final chosen = this.selectedIndices.whereType<int>().toList();
    if (this.selectedIndices.length != mode.count ||
        chosen.any((index) => index < 0 || index >= shots.length) ||
        chosen.toSet().length != chosen.length) {
      throw ArgumentError('Invalid Photobooth photo selection');
    }
  }

  factory PhotoBoothSession.create({
    required String accountId,
    required String childId,
    PhotoBoothMode mode = PhotoBoothMode.two,
    PhotoBoothDuration duration = PhotoBoothDuration.thirty,
  }) => PhotoBoothSession(
    sessionId: List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join(),
    accountId: accountId,
    childId: childId,
    mode: mode,
    duration: duration,
    createdAt: DateTime.now(),
  );

  final String sessionId;
  final String accountId;
  final String childId;
  final PhotoBoothMode mode;
  final PhotoBoothDuration duration;
  final DateTime createdAt;
  final List<LocalPhoto> shots;
  final List<int?> selectedIndices;
  List<LocalPhoto> get selectedPhotos => List.unmodifiable(
    selectedIndices.whereType<int>().map((index) => shots[index]),
  );
  bool get complete => selectedIndices.every((index) => index != null);

  PhotoBoothSession _copy({
    List<LocalPhoto>? shots,
    PhotoBoothMode? mode,
    PhotoBoothDuration? duration,
    List<int?>? selectedIndices,
  }) => PhotoBoothSession(
    sessionId: sessionId,
    accountId: accountId,
    childId: childId,
    mode: mode ?? this.mode,
    duration: duration ?? this.duration,
    createdAt: createdAt,
    shots: shots ?? this.shots,
    selectedIndices: selectedIndices ?? this.selectedIndices,
  );

  PhotoBoothSession withShots(List<LocalPhoto> shots) => _copy(
    shots: shots,
    selectedIndices: selectedIndices
        .map((index) => index != null && index < shots.length ? index : null)
        .toList(),
  );

  PhotoBoothSession withDuration(PhotoBoothDuration duration) =>
      _copy(duration: duration);

  PhotoBoothSession withMode(PhotoBoothMode mode) => _copy(
    mode: mode,
    selectedIndices: List.generate(
      mode.count,
      (index) => index < selectedIndices.length ? selectedIndices[index] : null,
    ),
  );

  PhotoBoothSession withSelection(List<int?> indices) =>
      _copy(selectedIndices: indices);

  String toJson() => jsonEncode({
    'version': 2,
    'sessionId': sessionId,
    'accountId': accountId,
    'childId': childId,
    'mode': mode.name,
    'durationSeconds': duration.seconds,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'shots': shots.map((shot) => shot.toJson()).toList(),
    'selectedIndices': selectedIndices,
  });
}

class PhotoBoothCapture {
  const PhotoBoothCapture({required this.path, required this.frontCamera});
  final String path;
  final bool frontCamera;
}

class PhotoBoothException implements Exception {
  const PhotoBoothException(this.message, {this.canOpenSettings = false});
  final String message;
  final bool canOpenSettings;
}
