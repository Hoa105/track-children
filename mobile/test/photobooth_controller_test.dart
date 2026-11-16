import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/photobooth/photobooth_controller.dart';
import 'package:track_children/features/photobooth/photobooth_session.dart';

import 'helpers/photobooth_fakes.dart';

Future<void> until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 600; i++) {
    if (done()) return;
    await tester.pump(const Duration(milliseconds: 25));
  }
  fail('State transition timed out');
}

Future<void> captureRound(
  WidgetTester tester,
  PhotoBoothController controller,
) async {
  await controller.initialize();
  final run = controller.start();
  await until(tester, () => !controller.capturing);
  await run;
}

void selectTwo(PhotoBoothController controller) {
  controller.selectPhoto(0, 1);
  controller.selectPhoto(1, 0);
}

void main() {
  for (final duration in PhotoBoothDuration.values) {
    testWidgets(
      '${duration.seconds}s: one countdown, timed pool independent of layout, no double jobs',
      (tester) async {
        final camera = FakeBoothCamera();
        final controller = testBooth(
          camera: camera,
          duration: duration,
          countdown: const Duration(milliseconds: 100),
        );
        final counts = <int>[];
        controller.addListener(() {
          if (controller.countdown > 0 &&
              (counts.isEmpty || counts.last != controller.countdown)) {
            counts.add(controller.countdown);
          }
        });
        await controller.start();
        expect(camera.captures, 0);
        await controller.initialize();
        final run = controller.start();
        await controller.start();
        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.remainingSeconds, duration.seconds);
        expect(camera.captures, 0);
        await until(tester, () => !controller.capturing);
        await run;
        expect(controller.phase, CapturePhase.reviewing);
        expect(counts, [3, 2, 1]);
        expect(camera.captures, duration.estimatedPhotos);
        expect(controller.remainingSeconds, 0);
        expect(
          controller.session.shots.map((s) => s.path),
          List.generate(duration.estimatedPhotos, (i) => 'shot-${i + 1}.jpg'),
        );
        expect(controller.session.complete, isFalse);
        expect(camera.ready, isFalse);
        await controller.shutdown();
        controller.dispose();
      },
    );
  }

  testWidgets(
    'stop during initial countdown takes no photo and keeps camera ready',
    (tester) async {
      final camera = FakeBoothCamera();
      final controller = testBooth(
        camera: camera,
        countdown: const Duration(seconds: 1),
      );
      await controller.initialize();
      final run = controller.start();
      await controller.stop();
      await run;
      await tester.pump(const Duration(seconds: 20));
      expect(camera.captures, 0);
      expect(controller.phase, CapturePhase.ready);
      expect(controller.remainingSeconds, 15);
      await controller.shutdown();
      controller.dispose();
    },
  );

  for (final duringSave in [false, true]) {
    testWidgets(
      'graceful stop during ${duringSave ? 'save' : 'native capture'} retains in-flight shot',
      (tester) async {
        final camera = FakeBoothCamera();
        final files = FakeBoothFiles();
        final captureGate = Completer<PhotoBoothCapture>();
        final saveGate = Completer<LocalPhoto>();
        if (duringSave) {
          files.saveGate = saveGate;
        } else {
          camera.captureGate = captureGate;
        }
        final controller = testBooth(camera: camera, files: files);
        await controller.initialize();
        final run = controller.start();
        await until(
          tester,
          () => duringSave ? files.saved == 1 : camera.captures == 1,
        );
        final stopped = controller.stop();
        expect(controller.finishing, isTrue);
        if (duringSave) {
          saveGate.complete(
            LocalPhoto(
              path: 'pending.jpg',
              width: 240,
              height: 320,
              capturedAt: DateTime.now(),
              frontCamera: true,
            ),
          );
        } else {
          captureGate.complete(
            const PhotoBoothCapture(path: 'pending.jpg', frontCamera: true),
          );
        }
        await tester.pump();
        await Future.wait([run, stopped]);
        expect(controller.session.shots, hasLength(1));
        expect(controller.phase, CapturePhase.reviewing);
        expect(files.removed, isEmpty);
        await tester.pump(const Duration(seconds: 10));
        expect(camera.captures, 1);
        await controller.shutdown();
        controller.dispose();
      },
    );
  }

  testWidgets('deadline during slow capture waits for only that photo', (
    tester,
  ) async {
    final gate = Completer<PhotoBoothCapture>();
    final camera = FakeBoothCamera()..captureGate = gate;
    final controller = testBooth(camera: camera);
    await controller.initialize();
    final run = controller.start();
    await until(tester, () => camera.captures == 1);
    await tester.pump(const Duration(seconds: 2));
    expect(controller.remainingSeconds, 0);
    expect(controller.finishing, isTrue);
    gate.complete(const PhotoBoothCapture(path: 'slow.jpg', frontCamera: true));
    await tester.pump();
    await run;
    expect(camera.captures, 1);
    expect(controller.session.shots, hasLength(1));
    expect(controller.phase, CapturePhase.reviewing);
    await controller.shutdown();
    controller.dispose();
  });

  testWidgets('stop between shots cancels future shutters', (tester) async {
    final camera = FakeBoothCamera();
    final controller = testBooth(camera: camera);
    await controller.initialize();
    final run = controller.start();
    await until(
      tester,
      () => controller.phase == CapturePhase.breakBetweenShots,
    );
    await controller.stop();
    await run;
    await tester.pump(const Duration(seconds: 20));
    expect(camera.captures, 1);
    expect(controller.phase, CapturePhase.reviewing);
    await controller.shutdown();
    controller.dispose();
  });

  testWidgets('add more preserves pool, identity, layout and chosen order', (
    tester,
  ) async {
    final files = FakeBoothFiles();
    final controller = testBooth(files: files);
    await captureRound(tester, controller);
    selectTwo(controller);
    final original = controller.session;
    controller.addMore();
    expect(controller.phase, CapturePhase.idle);
    controller.chooseDuration(PhotoBoothDuration.thirty);
    await captureRound(tester, controller);
    expect(controller.session.shots, hasLength(15));
    expect(controller.session.sessionId, original.sessionId);
    expect(controller.session.selectedIndices, [1, 0]);
    expect(controller.session.selectedPhotos, original.selectedPhotos);
    expect(files.removed, isEmpty);
    expect(files.cleared, 0);
    await controller.shutdown();
    controller.dispose();
  });

  testWidgets(
    'slots swap without duplicates; layout changes never delete originals',
    (tester) async {
      final controller = testBooth();
      await captureRound(tester, controller);
      selectTwo(controller);
      expect(controller.session.selectedIndices, [1, 0]);
      controller.selectPhoto(0, 0);
      expect(controller.session.selectedIndices, [0, 1]);
      controller.chooseMode(PhotoBoothMode.four);
      expect(controller.session.selectedIndices, [0, 1, null, null]);
      expect(controller.session.complete, isFalse);
      controller.selectPhoto(2, 4);
      controller.selectPhoto(3, 3);
      expect(controller.session.complete, isTrue);
      expect(controller.session.selectedPhotos.map((p) => p.path), [
        'shot-1.jpg',
        'shot-2.jpg',
        'shot-5.jpg',
        'shot-4.jpg',
      ]);
      controller.chooseMode(PhotoBoothMode.two);
      expect(controller.session.selectedIndices, [0, 1]);
      expect(controller.session.shots, hasLength(5));
      await controller.shutdown();
      controller.dispose();
    },
  );

  for (final failure in ['capture', 'save']) {
    testWidgets(
      'failed $failure in extra round keeps pool and selected photos',
      (tester) async {
        final camera = FakeBoothCamera();
        final files = FakeBoothFiles();
        final controller = testBooth(camera: camera, files: files);
        await captureRound(tester, controller);
        selectTwo(controller);
        final before = controller.session;
        controller.addMore();
        if (failure == 'capture') {
          camera.captureFailure = const PhotoBoothException(
            'Chưa chụp được ảnh.',
          );
        } else {
          files.saveFailure = StateError('disk full');
        }
        await captureRound(tester, controller);
        expect(controller.phase, CapturePhase.error);
        expect(controller.session.shots, before.shots);
        expect(controller.session.selectedPhotos, before.selectedPhotos);
        expect(files.removed, isEmpty);
        expect(controller.error, isNot(contains('disk full')));
        await controller.returnToReview();
        expect(controller.phase, CapturePhase.reviewing);
        await controller.shutdown();
        controller.dispose();
      },
    );
  }

  testWidgets(
    'permission recovery and lens switch remain available only while ready',
    (tester) async {
      final camera = FakeBoothCamera()
        ..openFailure = const PhotoBoothException(
          'Chưa có quyền Camera.',
          canOpenSettings: true,
        );
      final controller = testBooth(camera: camera);
      await controller.initialize();
      expect(controller.canOpenSettings, isTrue);
      await controller.openSettings();
      expect(camera.settingsOpened, 1);
      camera.openFailure = null;
      await controller.initialize();
      expect(camera.front, isTrue);
      await controller.switchLens();
      expect(camera.front, isFalse);
      final run = controller.start();
      await controller.switchLens();
      expect(camera.front, isFalse);
      await controller.stop();
      await run;
      camera.openFailure = StateError('device unplugged');
      await controller.initialize();
      expect(controller.phase, CapturePhase.error);
      expect(controller.error, isNot(contains('device unplugged')));
      await controller.shutdown();
      controller.dispose();
    },
  );

  testWidgets('background cancels countdown; resume never auto shoots', (
    tester,
  ) async {
    final camera = FakeBoothCamera();
    final controller = testBooth(
      camera: camera,
      countdown: const Duration(seconds: 1),
    );
    await controller.initialize();
    final run = controller.start();
    expect(controller.countdown, 3);
    await controller.pause();
    await run;
    await controller.resume();
    await tester.pump(const Duration(seconds: 10));
    expect(camera.captures, 0);
    expect(controller.canStart, isTrue);
    expect(controller.interrupted, isTrue);
    await controller.shutdown();
    controller.dispose();
  });

  testWidgets(
    'pause preserves remaining time and existing pool on explicit resume',
    (tester) async {
      final camera = FakeBoothCamera();
      final controller = testBooth(camera: camera);
      await controller.initialize();
      final run = controller.start();
      await until(tester, () => controller.remainingSeconds <= 10);
      final remaining = controller.remainingSeconds;
      final shots = controller.session.shots.length;
      await controller.pause();
      await run;
      await tester.pump(const Duration(seconds: 5));
      expect(controller.remainingSeconds, remaining);
      await controller.resume();
      expect(camera.captures, shots);
      final resumed = controller.start();
      await until(tester, () => !controller.capturing);
      await resumed;
      expect(controller.phase, CapturePhase.reviewing);
      expect(controller.session.shots.length, greaterThan(shots));
      await controller.shutdown();
      controller.dispose();
    },
  );

  testWidgets('late native result is discarded after lifecycle interruption', (
    tester,
  ) async {
    final gate = Completer<PhotoBoothCapture>();
    final camera = FakeBoothCamera()..captureGate = gate;
    final files = FakeBoothFiles();
    final controller = testBooth(camera: camera, files: files);
    await controller.initialize();
    final run = controller.start();
    await until(tester, () => camera.captures == 1);
    await controller.pause();
    gate.complete(const PhotoBoothCapture(path: 'late.jpg', frontCamera: true));
    await tester.pump();
    await run;
    expect(controller.session.shots, isEmpty);
    expect(files.saved, 0);
    expect(camera.discarded, ['late.jpg']);
    await controller.shutdown();
    controller.dispose();
  });

  testWidgets(
    'shutdown waits for a late save and removes only its pending file',
    (tester) async {
      final gate = Completer<LocalPhoto>();
      final files = FakeBoothFiles()..saveGate = gate;
      final controller = testBooth(files: files);
      await controller.initialize();
      final run = controller.start();
      await until(tester, () => files.saved == 1);
      final closed = controller.shutdown();
      gate.complete(
        LocalPhoto(
          path: 'late-saved.jpg',
          width: 240,
          height: 320,
          capturedAt: DateTime.now(),
          frontCamera: true,
        ),
      );
      await tester.pump();
      await Future.wait([run, closed]);
      expect(controller.session.shots, isEmpty);
      expect(files.removed, ['late-saved.jpg']);
      expect(files.cleared, 1);
      controller.dispose();
    },
  );

  testWidgets(
    'handoff requires full selection and preserves all originals plus slot order',
    (tester) async {
      final files = FakeBoothFiles();
      final controller = testBooth(files: files);
      await captureRound(tester, controller);
      await controller.edit();
      expect(files.handoffs, isEmpty);
      selectTwo(controller);
      await Future.wait([controller.edit(), controller.edit()]);
      expect(controller.phase, CapturePhase.editing);
      expect(files.handoffs, hasLength(1));
      final data =
          jsonDecode(files.handoffs.single.toJson()) as Map<String, dynamic>;
      expect(data['version'], 2);
      expect(data['accountId'], 'account-test');
      expect(data['childId'], 'child-test');
      expect(data['durationSeconds'], 15);
      expect(data['selectedIndices'], [1, 0]);
      expect(data['shots'], hasLength(5));
      expect(files.handoffs.single.selectedPhotos.map((p) => p.path), [
        'shot-2.jpg',
        'shot-1.jpg',
      ]);
      controller.backFromEditor();
      expect(controller.session.shots, hasLength(5));
      expect(controller.session.selectedIndices, [1, 0]);
      await controller.shutdown();
      controller.dispose();
    },
  );

  testWidgets('handoff failure can retry without losing pool or selection', (
    tester,
  ) async {
    final files = FakeBoothFiles()..handoffFailure = StateError('disk full');
    final controller = testBooth(files: files);
    await captureRound(tester, controller);
    selectTwo(controller);
    await controller.edit();
    expect(controller.phase, CapturePhase.reviewing);
    expect(controller.session.complete, isTrue);
    files.handoffFailure = null;
    await controller.edit();
    expect(controller.phase, CapturePhase.editing);
    await controller.shutdown();
    controller.dispose();
  });

  testWidgets('shutdown waits for manifest before cleaning session', (
    tester,
  ) async {
    final gate = Completer<void>();
    final files = FakeBoothFiles()..handoffGate = gate;
    final controller = testBooth(files: files);
    await captureRound(tester, controller);
    selectTwo(controller);
    final edit = controller.edit();
    final close = controller.shutdown();
    await tester.pump();
    expect(files.cleared, 0);
    gate.complete();
    await tester.pump();
    await Future.wait([edit, close]);
    expect(files.cleared, 1);
    expect(controller.phase, isNot(CapturePhase.editing));
    controller.dispose();
  });
}
