import 'dart:async';

import 'package:flutter/material.dart';
import 'package:track_children/features/photobooth/photobooth_camera.dart';
import 'package:track_children/features/photobooth/photobooth_controller.dart';
import 'package:track_children/features/photobooth/photobooth_files.dart';
import 'package:track_children/features/photobooth/photobooth_session.dart';

class FakeBoothCamera implements PhotoBoothCamera {
  @override
  bool ready = false;
  @override
  bool front = true;
  @override
  bool canSwitch = true;
  @override
  double aspectRatio = 3 / 4;
  int captures = 0;
  int opens = 0;
  int closes = 0;
  int settingsOpened = 0;
  Object? openFailure;
  Object? captureFailure;
  Completer<PhotoBoothCapture>? captureGate;
  final discarded = <String>[];

  @override
  Future<void> initialize({required bool front}) async {
    opens++;
    if (openFailure != null) throw openFailure!;
    this.front = front;
    ready = true;
  }

  @override
  Future<PhotoBoothCapture> capture() async {
    if (!ready) throw StateError('Capture before initialization');
    captures++;
    if (captureFailure != null) throw captureFailure!;
    if (captureGate != null) return captureGate!.future;
    return PhotoBoothCapture(path: 'capture-$captures.jpg', frontCamera: front);
  }

  @override
  Future<void> suspend() async {
    ready = false;
    closes++;
  }

  @override
  Future<void> discard(PhotoBoothCapture capture) async {
    discarded.add(capture.path);
  }

  @override
  Future<void> openSettings() async {
    settingsOpened++;
  }

  @override
  Widget preview() => const ColoredBox(
    color: Color(0xFF6F9A89),
    child: Center(
      child: Icon(Icons.face_outlined, color: Colors.white, size: 80),
    ),
  );
}

class FakeBoothFiles implements PhotoBoothShotStore {
  int saved = 0;
  int cleared = 0;
  final removed = <String>[];
  final handoffs = <PhotoBoothSession>[];
  Object? saveFailure;
  Object? handoffFailure;
  Completer<void>? handoffGate;
  Completer<LocalPhoto>? saveGate;
  String? fixtureDirectory;

  @override
  Future<LocalPhoto> save(
    PhotoBoothSession session,
    PhotoBoothCapture capture,
  ) async {
    if (saveFailure != null) throw saveFailure!;
    saved++;
    if (saveGate != null) return saveGate!.future;
    return LocalPhoto(
      path: fixtureDirectory == null
          ? 'shot-$saved.jpg'
          : '$fixtureDirectory/photo_${(saved - 1) % 4}.jpg',
      width: 240,
      height: 320,
      capturedAt: DateTime(2026, 11, 11),
      frontCamera: capture.frontCamera,
    );
  }

  @override
  Future<void> remove(PhotoBoothSession session, LocalPhoto photo) async {
    removed.add(photo.path);
  }

  @override
  Future<void> clear(PhotoBoothSession session) async {
    cleared++;
  }

  @override
  Future<void> handoff(PhotoBoothSession session) async {
    await handoffGate?.future;
    if (handoffFailure != null) throw handoffFailure!;
    handoffs.add(session);
  }
}

PhotoBoothController testBooth({
  PhotoBoothMode mode = PhotoBoothMode.two,
  PhotoBoothDuration duration = PhotoBoothDuration.fifteen,
  FakeBoothCamera? camera,
  FakeBoothFiles? files,
  Duration countdown = Duration.zero,
  Duration second = const Duration(milliseconds: 100),
  Duration? shotInterval,
}) => PhotoBoothController(
  session: PhotoBoothSession.create(
    accountId: 'account-test',
    childId: 'child-test',
    mode: mode,
    duration: duration,
  ),
  camera: camera ?? FakeBoothCamera(),
  files: files ?? FakeBoothFiles(),
  countdownInterval: countdown,
  second: second,
  shotInterval: shotInterval ?? second * 3,
  flashDuration: Duration.zero,
);
