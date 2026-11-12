import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../home/background/local_background_image.dart';
import '../home/background/background_config.dart';
import '../home/home_ui_icon.dart';
import 'photobooth_camera.dart';
import 'photobooth_controller.dart';
import 'photobooth_editor_entry.dart';
import 'photobooth_edit.dart';
import 'photobooth_files.dart';
import 'photobooth_photo_selection.dart';
import 'photobooth_session.dart';

class PhotoBoothScreen extends StatefulWidget {
  const PhotoBoothScreen({
    required this.accountId,
    required this.childId,
    this.controller,
    this.editorBuilder,
    this.onUseHome,
    super.key,
  });
  final String accountId;
  final String childId;

  /// The screen owns the controller, including disposal of injected test cameras.
  final PhotoBoothController? controller;
  final PhotoBoothEditorBuilder? editorBuilder;
  final Future<BackgroundConfig?> Function(String path)? onUseHome;

  @override
  State<PhotoBoothScreen> createState() => _PhotoBoothScreenState();
}

class _PhotoBoothScreenState extends State<PhotoBoothScreen>
    with WidgetsBindingObserver {
  late PhotoBoothController _controller;
  bool _allowPop = false;
  bool _confirming = false;
  bool _leaving = false;
  int _selectedSlot = 0;
  ModalRoute<dynamic>? _dialogRoute;
  final _editorKey = GlobalKey<PhotoBoothEditorEntryState>();
  PhotoBoothEditorController? _editor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _createController();
  }

  void _createController() {
    _controller =
        widget.controller ??
        PhotoBoothController(
          session: PhotoBoothSession.create(
            accountId: widget.accountId,
            childId: widget.childId,
          ),
          camera: DevicePhotoBoothCamera(),
          files: const PhotoBoothFiles(),
        );
    final files = _controller.files;
    if (files is PhotoBoothFiles) {
      unawaited(files.prune(_controller.session).catchError((Object _) {}));
    }
  }

  @override
  void didUpdateWidget(covariant PhotoBoothScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId ||
        oldWidget.childId != widget.childId) {
      _controller.dispose();
      _editor?.dispose();
      _editor = null;
      _selectedSlot = 0;
      _createController();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.resume());
    } else {
      unawaited(_controller.pause());
    }
  }

  Future<bool> _confirm(String title, String message, String confirm) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) {
          _dialogRoute = ModalRoute.of(context);
          return AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Giữ lại'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(confirm),
              ),
            ],
          );
        },
      ) ??
      false;

  Future<void> _close() async {
    if (_confirming || _leaving) return;
    _confirming = true;
    try {
      await _controller.pause();
      if (!mounted) return;
      if (_controller.hasShots &&
          !await _confirm(
            'Bỏ bộ ảnh này?',
            'Ảnh trong phiên chụp sẽ bị xóa. Ảnh nền hiện tại vẫn được giữ.',
            'Bỏ ảnh và thoát',
          )) {
        return;
      }
      if (!mounted) return;
      setState(() => _leaving = true);
      await _controller.shutdown();
      if (!mounted) return;
      setState(() => _allowPop = true);
      Navigator.pop(context);
    } finally {
      _confirming = false;
    }
  }

  Future<void> _back() async {
    if (_controller.phase == CapturePhase.editing) {
      if (await (_editorKey.currentState?.requestLeave() ??
              Future.value(true)) &&
          mounted) {
        _controller.backFromEditor();
      }
    } else if (_controller.hasShots &&
        _controller.phase != CapturePhase.reviewing) {
      unawaited(_controller.returnToReview());
    } else {
      unawaited(_close());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final dialog = _dialogRoute;
    if (dialog != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (dialog.isActive) dialog.navigator?.removeRoute(dialog);
      });
    }
    _controller.dispose();
    _editor?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final phase = _controller.phase;
      final review = phase == CapturePhase.reviewing;
      final edit = phase == CapturePhase.editing;
      final idle = phase == CapturePhase.idle;
      return PopScope(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              idle
                  ? 'Photobooth của bé'
                  : review
                  ? 'Chọn ảnh'
                  : edit
                  ? 'Trang trí ảnh'
                  : 'Chụp Photobooth',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            leading: IconButton(
              tooltip: 'Đóng Photobooth',
              onPressed: _leaving ? null : _back,
              icon: const Icon(Icons.close_rounded),
            ),
            actions: [
              if (!idle && !review && !edit)
                IconButton(
                  tooltip: 'Đổi camera',
                  onPressed: _controller.canSwitch && !_leaving
                      ? _controller.switchLens
                      : null,
                  icon: const Icon(Icons.cameraswitch_outlined),
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: AbsorbPointer(
              absorbing: _leaving,
              child: _leaving
                  ? const Center(child: CircularProgressIndicator())
                  : idle
                  ? _startScreen()
                  : review
                  ? _reviewScreen()
                  : edit
                  ? _editorScreen()
                  : _captureScreen(),
            ),
          ),
        ),
      );
    },
  );

  Widget _editorScreen() {
    final injected = widget.editorBuilder;
    if (injected != null) {
      return injected(context, _controller.session, _controller.backFromEditor);
    }
    _editor ??= PhotoBoothEditorController(_controller.session);
    _editor!.updateSession(_controller.session);
    return PhotoBoothEditorEntry(
      key: _editorKey,
      session: _controller.session,
      controller: _editor,
      onBack: _controller.backFromEditor,
      onChooseFour: () {
        _controller.backFromEditor();
        _controller.chooseMode(PhotoBoothMode.four);
        _selectedSlot = _controller.session.selectedIndices.indexOf(null);
        if (_selectedSlot < 0) _selectedSlot = 0;
      },
      onUseHome: widget.onUseHome == null
          ? null
          : (path) async {
              final config = await widget.onUseHome!(path);
              if (config == null || !mounted) return false;
              setState(() => _leaving = true);
              await _controller.shutdown();
              if (!mounted) return false;
              setState(() => _allowPop = true);
              Navigator.pop(context, config);
              return true;
            },
    );
  }

  Widget _startScreen() => RadioGroup<PhotoBoothDuration>(
    groupValue: _controller.session.duration,
    onChanged: (duration) {
      if (duration != null) _controller.chooseDuration(duration);
    },
    child: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Chọn thời lượng, cùng bé đổi dáng nhé!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              for (final duration in PhotoBoothDuration.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: RadioListTile<PhotoBoothDuration>(
                      key: ValueKey('photobooth-duration-${duration.seconds}'),
                      value: duration,
                      title: Text(
                        '${duration.seconds} giây',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('Khoảng ${duration.estimatedPhotos} ảnh'),
                    ),
                  ),
                ),
              if (_controller.hasShots)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Đã giữ ${_controller.session.shots.length} ảnh. Ảnh mới sẽ được thêm vào bộ ảnh này.',
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: _controller.initialize,
                child: const Text('Bắt đầu chụp'),
              ),
              TextButton(
                onPressed: _controller.hasShots
                    ? _controller.returnToReview
                    : _close,
                child: Text(
                  _controller.hasShots ? 'Quay lại bộ ảnh' : 'Quay lại',
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _captureScreen() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          children: [
            Text(
              'Còn ${_controller.remainingSeconds ~/ 60}:${(_controller.remainingSeconds % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              'Đã chụp ${_controller.session.shots.length} ảnh',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              key: const ValueKey('photobooth-camera-viewport'),
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFF15231D)),
                if (_controller.camera.ready &&
                    ![
                      CapturePhase.error,
                      CapturePhase.paused,
                      CapturePhase.initializing,
                    ].contains(_controller.phase))
                  LayoutBuilder(
                    builder: (context, constraints) => FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height:
                            constraints.maxWidth /
                            _controller.camera.aspectRatio,
                        child: _controller.camera.preview(),
                      ),
                    ),
                  ),
                if (_controller.phase == CapturePhase.initializing)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                if (_controller.phase == CapturePhase.error ||
                    _controller.phase == CapturePhase.paused)
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _controller.error ?? 'Lượt chụp đã tạm dừng. Bạn hãy mở lại camera để tiếp tục.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _controller.initialize,
                            child: const Text('Thử lại camera'),
                          ),
                          if (_controller.canOpenSettings)
                            TextButton(
                              onPressed: _controller.openSettings,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Mở Cài đặt'),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (_controller.countdown > 0)
                  Center(
                    child: Semantics(
                      liveRegion: true,
                      label: 'Chụp sau ${_controller.countdown} giây',
                      child: ExcludeSemantics(
                        child: Text(
                          '${_controller.countdown}',
                          style: const TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: [
                              Shadow(blurRadius: 12, color: Colors.black54),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_controller.phase == CapturePhase.breakBetweenShots)
                  const Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Đổi dáng nào!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_controller.flashing &&
                    !MediaQuery.disableAnimationsOf(context))
                  IgnorePointer(
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: .28),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      _thumbnails(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('photobooth-shutter'),
            onPressed: _controller.finishing
                ? null
                : _controller.capturing
                ? _controller.stop
                : _controller.canStart
                ? _controller.start
                : null,
            icon: const HomeUiIcon(HomeUiIconName.camera, color: Colors.white),
            label: Text(
              _controller.finishing
                  ? 'Đang kết thúc…'
                  : _controller.capturing
                  ? 'Dừng chụp'
                  : _controller.interrupted
                  ? 'Tiếp tục chụp'
                  : 'Chụp liên tiếp',
            ),
          ),
        ),
      ),
      TextButton(
        onPressed: _controller.finishing
            ? null
            : _controller.hasShots
            ? _controller.returnToReview
            : _close,
        child: Text(_controller.hasShots ? 'Về bộ ảnh' : 'Hủy lượt chụp'),
      ),
    ],
  );

  Widget _thumbnails() => SizedBox(
    height: 72,
    child: _controller.session.shots.isEmpty
        ? const Center(child: Text('Ảnh chụp sẽ xuất hiện tại đây'))
        : ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: _controller.session.shots.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) => Semantics(
              label: 'Ảnh ${index + 1} đã chụp',
              child: SizedBox(
                width: 48,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _photo(_controller.session.shots[index], small: true),
                ),
              ),
            ),
          ),
  );

  Widget _photo(LocalPhoto shot, {bool small = false}) => Image(
    key: ValueKey(shot.path),
    image: ResizeImage.resizeIfNeeded(
      small ? 120 : 600,
      null,
      localBackgroundImage(shot.path)!,
    ),
    fit: small ? BoxFit.cover : BoxFit.contain,
    excludeFromSemantics: true,
    errorBuilder: (_, _, _) =>
        const Center(child: HomeUiIcon(HomeUiIconName.image)),
  );

  Widget _reviewScreen() => PhotoBoothPhotoSelection(
    session: _controller.session,
    selectedSlot: _selectedSlot,
    busy: _controller.handingOff || _controller.capturing,
    error: _controller.error,
    onMode: (mode) {
      _selectedSlot = 0;
      _controller.chooseMode(mode);
    },
    onSlot: (slot) => setState(() => _selectedSlot = slot),
    onPhoto: (index) {
      _controller.selectPhoto(_selectedSlot, index);
      setState(() {
        final empty = _controller.session.selectedIndices.indexOf(null);
        _selectedSlot = empty >= 0
            ? empty
            : (_selectedSlot + 1) % _controller.session.mode.count;
      });
    },
    onAddMore: _controller.addMore,
    onContinue: _controller.edit,
  );
}
