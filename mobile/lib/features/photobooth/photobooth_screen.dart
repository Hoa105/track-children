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
  final _completionStatus = ValueNotifier<PhotoBoothCompletionStatus>((
    completed: false,
    busy: false,
  ));
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            backgroundColor: HomeColors.surface,
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: HomeColors.ink,
              ),
            ),
            content: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: HomeColors.reminderCta,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  foregroundColor: HomeColors.ink,
                ),
                child: const Text('Ở lại'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: HomeColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
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
            'Thoát chụp ảnh?',
            'Ảnh chưa lưu sẽ bị bỏ. Ảnh nền hiện tại không đổi.',
            'Thoát',
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
    _completionStatus.dispose();
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
          backgroundColor: HomeColors.background,
          appBar: AppBar(
            backgroundColor: HomeColors.background,
            foregroundColor: HomeColors.ink,
            elevation: 0,
            title: Text(
              idle
                  ? 'Photobooth của bé'
                  : review
                  ? 'Chọn ảnh'
                  : edit
                  ? 'Trang trí ảnh'
                  : 'Chụp Photobooth',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: HomeColors.ink,
              ),
            ),
            leading: IconButton(
              tooltip: edit || (_controller.hasShots && !review)
                  ? 'Quay lại chọn ảnh'
                  : 'Thoát chụp ảnh',
              onPressed: _leaving ? null : _back,
              color: HomeColors.ink,
              icon: const Icon(Icons.close_rounded),
            ),
            actions: [
              if (edit && widget.editorBuilder == null)
                ValueListenableBuilder<PhotoBoothCompletionStatus>(
                  valueListenable: _completionStatus,
                  builder: (_, status, _) => PhotoBoothContinueEditingAction(
                    status: status,
                    onPressed: () => _editorKey.currentState?.continueEditing(),
                  ),
                ),
              if (!idle && !review && !edit)
                IconButton(
                  tooltip: 'Đổi camera',
                  onPressed: _controller.canSwitch && !_leaving
                      ? _controller.switchLens
                      : null,
                  color: HomeColors.primary,
                  icon: const Icon(Icons.cameraswitch_outlined),
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: AbsorbPointer(
              absorbing: _leaving,
              child: _leaving
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: HomeColors.primary,
                      ),
                    )
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
      onCompletionChanged: (status) => _completionStatus.value = status,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: HomeColors.reminderBackground.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: HomeColors.iconBackground),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 20,
                      color: HomeColors.primary,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Chọn thời lượng, cùng bé đổi dáng nhé!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: HomeColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final duration in PhotoBoothDuration.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: _controller.session.duration == duration
                        ? HomeColors.reminderBackground.withValues(alpha: 0.6)
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: _controller.session.duration == duration
                            ? HomeColors.primary
                            : const Color(0xFFE2EBE0),
                        width: _controller.session.duration == duration ? 2 : 1,
                      ),
                    ),
                    elevation: _controller.session.duration == duration ? 1 : 0,
                    shadowColor: const Color(0x1429451E),
                    clipBehavior: Clip.antiAlias,
                    child: RadioListTile<PhotoBoothDuration>(
                      key: ValueKey('photobooth-duration-${duration.seconds}'),
                      value: duration,
                      activeColor: HomeColors.primary,
                      title: Text(
                        '${duration.seconds} giây',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: HomeColors.ink,
                        ),
                      ),
                      subtitle: Text(
                        'Khoảng ${duration.estimatedPhotos} ảnh',
                        style: const TextStyle(
                          color: HomeColors.reminderCta,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_controller.hasShots)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: HomeColors.iconBackground.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Đã giữ ${_controller.session.shots.length} ảnh. Ảnh mới sẽ được thêm vào bộ ảnh này.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: HomeColors.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _controller.initialize,
                  style: FilledButton.styleFrom(
                    backgroundColor: HomeColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 1,
                  ),
                  child: const Text(
                    'Bắt đầu chụp',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _controller.hasShots
                      ? _controller.returnToReview
                      : _close,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HomeColors.ink,
                    side: const BorderSide(color: Color(0xFFD4E0D1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    backgroundColor: Colors.white,
                  ),
                  child: Text(
                    _controller.hasShots ? 'Quay lại chọn ảnh' : 'Quay lại',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
          spacing: 12,
          runSpacing: 6,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: HomeColors.reminderBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HomeColors.iconBackground),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: HomeColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Còn ${_controller.remainingSeconds ~/ 60}:${(_controller.remainingSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: HomeColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: HomeColors.iconBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: HomeColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.photo_library_outlined,
                    size: 18,
                    color: HomeColors.ink,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Đã chụp ${_controller.session.shots.length} ảnh',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: HomeColors.ink,
                    ),
                  ),
                ],
              ),
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
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            key: const ValueKey('photobooth-shutter'),
            onPressed: _controller.finishing
                ? null
                : _controller.capturing
                ? _controller.stop
                : _controller.canStart
                ? _controller.start
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: HomeColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 1,
            ),
            icon: const HomeUiIcon(HomeUiIconName.camera, color: Colors.white),
            label: Text(
              _controller.finishing
                  ? 'Đang kết thúc…'
                  : _controller.capturing
                  ? 'Dừng chụp'
                  : _controller.interrupted
                  ? 'Tiếp tục chụp'
                  : 'Chụp liên tiếp',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
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
        style: TextButton.styleFrom(
          foregroundColor: HomeColors.ink,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
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
