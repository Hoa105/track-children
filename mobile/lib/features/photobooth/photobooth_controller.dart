import 'dart:async';

import 'package:flutter/foundation.dart';

import 'photobooth_camera.dart';
import 'photobooth_files.dart';
import 'photobooth_session.dart';

class PhotoBoothController extends ChangeNotifier {
  PhotoBoothController({
    required PhotoBoothSession session,
    required this.camera,
    required this.files,
    this.countdownInterval = const Duration(seconds: 1),
    this.shotInterval = const Duration(seconds: 3),
    this.flashDuration = const Duration(milliseconds: 140),
    this.second = const Duration(seconds: 1),
  }) : _session = session,
       remainingSeconds = session.duration.seconds;

  final PhotoBoothCamera camera;
  final PhotoBoothShotStore files;
  final Duration countdownInterval;
  final Duration shotInterval;
  final Duration flashDuration;

  /// One session second; injectable so tests exercise real timer boundaries.
  final Duration second;
  PhotoBoothSession _session;
  PhotoBoothSession get session => _session;
  CapturePhase phase = CapturePhase.idle;
  String? error;
  bool canOpenSettings = false;
  bool requestedFront = true;
  bool flashing = false;
  bool interrupted = false;
  int countdown = 0;
  int remainingSeconds;
  int _generation = 0;
  bool _disposed = false;
  bool _closed = false;
  bool _running = false;
  bool _stopRequested = false;
  bool handingOff = false;
  Timer? _timer;
  Timer? _deadline;
  Timer? _ticker;
  Timer? _flashTimer;
  Completer<void>? _waiter;
  Future<void>? _runFuture;
  Future<void>? _handoffFuture;
  Future<void>? _closeFuture;

  bool get capturing => _running;
  bool get finishing => _running && _stopRequested;
  bool get canStart =>
      !_running && !_closed && phase == CapturePhase.ready && camera.ready;
  bool get canSwitch => canStart && camera.canSwitch;
  bool get hasShots => session.shots.isNotEmpty;
  bool _valid(int generation) =>
      !_disposed && !_closed && generation == _generation;

  void _emit() {
    if (!_disposed && !_closed) notifyListeners();
  }

  void _wake() {
    _timer?.cancel();
    final waiter = _waiter;
    _waiter = null;
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }

  void _stopTimers() {
    _wake();
    _deadline?.cancel();
    _ticker?.cancel();
    _flashTimer?.cancel();
    flashing = false;
    countdown = 0;
  }

  Future<void> _wait(Duration duration) {
    final waiter = Completer<void>();
    _waiter = waiter;
    _timer = Timer(duration, () {
      if (identical(_waiter, waiter)) _waiter = null;
      if (!waiter.isCompleted) waiter.complete();
    });
    return waiter.future;
  }

  void chooseDuration(PhotoBoothDuration duration) {
    if (phase != CapturePhase.idle) return;
    _session = session.withDuration(duration);
    remainingSeconds = duration.seconds;
    _emit();
  }

  void chooseMode(PhotoBoothMode mode) {
    if (phase != CapturePhase.reviewing || handingOff) return;
    _session = session.withMode(mode);
    error = null;
    _emit();
  }

  /// A photo can occupy only one slot. Selecting it elsewhere swaps the slots.
  void selectPhoto(int slot, int photo) {
    if (phase != CapturePhase.reviewing ||
        handingOff ||
        slot < 0 ||
        slot >= session.mode.count ||
        photo < 0 ||
        photo >= session.shots.length) {
      return;
    }
    final selection = [...session.selectedIndices];
    final previousSlot = selection.indexOf(photo);
    if (previousSlot >= 0) selection[previousSlot] = selection[slot];
    selection[slot] = photo;
    _session = session.withSelection(selection);
    error = null;
    _emit();
  }

  Future<void> initialize() async {
    if (_closed || _disposed || phase == CapturePhase.initializing) return;
    // A paused native capture may still be returning. Never overlap runs.
    if (_running) await _runFuture;
    if (_closed || _disposed) return;
    final generation = ++_generation;
    _stopTimers();
    phase = CapturePhase.initializing;
    error = null;
    canOpenSettings = false;
    _emit();
    try {
      await camera.initialize(front: requestedFront);
      if (!_valid(generation)) return;
      requestedFront = camera.front;
      phase = CapturePhase.ready;
    } catch (failure) {
      if (!_valid(generation)) return;
      _setError(failure, 'Chưa mở được camera. Bạn hãy thử lại.');
    }
    _emit();
  }

  Future<void> switchLens() async {
    if (!canSwitch) return;
    requestedFront = !requestedFront;
    await initialize();
  }

  Future<void> start() {
    if (!canStart) return Future.value();
    _running = true;
    _stopRequested = false;
    interrupted = false;
    if (remainingSeconds <= 0) remainingSeconds = session.duration.seconds;
    final generation = ++_generation;
    return _runFuture = _captureSequence(generation);
  }

  void _startDeadline() {
    // This deadline also runs while native capture/file saving are pending.
    _deadline = Timer(second * remainingSeconds, () {
      remainingSeconds = 0;
      _requestStop();
    });
    final initialSeconds = remainingSeconds;
    _ticker = Timer.periodic(second, (timer) {
      remainingSeconds = (initialSeconds - timer.tick).clamp(0, initialSeconds);
      _emit();
    });
  }

  Future<void> _captureSequence(int generation) async {
    try {
      // Preparation happens once per start/resume, outside the timed session.
      for (var count = 3; count > 0; count--) {
        if (!_valid(generation) || _stopRequested) break;
        phase = CapturePhase.countingDown;
        countdown = count;
        _emit();
        await _wait(countdownInterval);
      }
      countdown = 0;
      if (_valid(generation) && !_stopRequested) _startDeadline();
      while (_valid(generation) && !_stopRequested) {
        if (!camera.ready) {
          throw const PhotoBoothException(
            'Camera bị gián đoạn. Bạn hãy thử lại.',
          );
        }
        phase = CapturePhase.capturing;
        error = null;
        _emit();
        PhotoBoothCapture? capture;
        LocalPhoto? saved;
        var accepted = false;
        // IO time counts toward the interval, without overlapping captures.
        final interval = Completer<void>();
        final nextShot = Timer(shotInterval, () => interval.complete());
        try {
          capture = await camera.capture();
          if (!_valid(generation)) return;
          flashing = true;
          _emit();
          _flashTimer = Timer(flashDuration, () {
            flashing = false;
            _emit();
          });
          saved = await files.save(session, capture);
          if (!_valid(generation)) return;
          _session = session.withShots([...session.shots, saved]);
          accepted = true;
          _emit();
        } finally {
          if (!accepted && saved != null) await files.remove(session, saved);
          if (capture != null) await camera.discard(capture);
          if (!accepted || !_valid(generation) || _stopRequested) {
            nextShot.cancel();
            if (!interval.isCompleted) interval.complete();
          }
        }
        if (!_valid(generation) || _stopRequested) break;
        phase = CapturePhase.breakBetweenShots;
        _emit();
        _waiter = interval;
        _timer = nextShot;
        await interval.future;
        if (identical(_waiter, interval)) _waiter = null;
      }
      if (!_valid(generation)) return;
      _stopTimers();
      phase = hasShots ? CapturePhase.reviewing : CapturePhase.ready;
      _emit();
      if (hasShots) await camera.suspend();
    } catch (failure) {
      if (_valid(generation)) {
        _stopTimers();
        _setError(
          failure,
          'Chưa lưu được ảnh vừa chụp. Ảnh trước vẫn được giữ, bạn hãy thử lại.',
        );
      }
    } finally {
      _running = false;
      _emit();
    }
  }

  void _requestStop() {
    _stopRequested = true;
    _stopTimers();
    _emit();
  }

  /// Graceful stop: finish and retain a shutter/save already in flight.
  Future<void> stop() async {
    if (!_running) return;
    _requestStop();
    await _runFuture;
  }

  void _setError(Object failure, String fallback) {
    error = failure is PhotoBoothException ? failure.message : fallback;
    canOpenSettings = failure is PhotoBoothException && failure.canOpenSettings;
    countdown = 0;
    flashing = false;
    phase = CapturePhase.error;
  }

  Future<void> pause() async {
    if (_closed ||
        _disposed ||
        [
          CapturePhase.idle,
          CapturePhase.reviewing,
          CapturePhase.editing,
          CapturePhase.paused,
        ].contains(phase)) {
      return;
    }
    ++_generation;
    _stopTimers();
    interrupted = true;
    phase = CapturePhase.paused;
    _emit();
    try {
      await camera.suspend();
    } catch (_) {
      /* Retry on initialize. */
    }
  }

  Future<void> resume() async {
    if (phase == CapturePhase.paused && !_closed && !_disposed) {
      await initialize();
    }
  }

  /// Another timed round reuses all originals and the current slot selection.
  void addMore() {
    if (phase != CapturePhase.reviewing || _running || handingOff) return;
    remainingSeconds = session.duration.seconds;
    _stopRequested = false;
    interrupted = false;
    error = null;
    phase = CapturePhase.idle;
    _emit();
  }

  Future<void> returnToReview() async {
    if (!hasShots || _closed || _disposed || handingOff) return;
    if (_running) await stop();
    if (_closed || _disposed) return;
    ++_generation;
    _stopTimers();
    phase = CapturePhase.reviewing;
    error = null;
    _emit();
    try {
      await camera.suspend();
    } catch (_) {
      /* Review needs no camera. */
    }
  }

  Future<void> edit() async {
    if (!session.complete ||
        phase != CapturePhase.reviewing ||
        handingOff ||
        _running) {
      return;
    }
    final generation = _generation;
    handingOff = true;
    error = null;
    _emit();
    try {
      _handoffFuture = files.handoff(session);
      await _handoffFuture;
      if (_valid(generation)) phase = CapturePhase.editing;
    } catch (_) {
      if (_valid(generation)) {
        error = 'Chưa mở được bộ ảnh. Ảnh chụp vẫn được giữ, bạn hãy thử lại.';
      }
    } finally {
      handingOff = false;
      _emit();
    }
  }

  void backFromEditor() {
    if (phase != CapturePhase.editing) return;
    phase = CapturePhase.reviewing;
    _emit();
  }

  Future<void> openSettings() async {
    try {
      await camera.openSettings();
    } catch (_) {
      if (!_closed && !_disposed) {
        error =
            'Bạn hãy mở Cài đặt của thiết bị và bật quyền Camera cho ứng dụng.';
        _emit();
      }
    }
  }

  Future<void> shutdown() => _closeFuture ??= _shutdown();
  Future<void> _shutdown() async {
    _closed = true;
    ++_generation;
    _stopTimers();
    try {
      await camera.suspend();
    } catch (_) {
      /* Continue cleanup. */
    }
    try {
      await _runFuture;
    } catch (_) {
      /* Continue cleanup. */
    }
    try {
      await _handoffFuture;
    } catch (_) {
      /* Drafts must be cleaned too. */
    }
    try {
      await files.clear(session);
    } catch (_) {
      /* Pruning retries later. */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(shutdown());
    super.dispose();
  }
}
