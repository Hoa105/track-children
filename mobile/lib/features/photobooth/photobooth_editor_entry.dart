import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

import '../home/background/background_draft.dart';
import 'photobooth_catalog.dart';
import 'photobooth_edit.dart';
import 'photobooth_export.dart';
import 'photobooth_renderer.dart';
import 'photobooth_session.dart';
import 'photobooth_text.dart';
import 'photobooth_text_composer.dart';

typedef PhotoBoothEditorBuilder = Widget Function(
  BuildContext context,
  PhotoBoothSession session,
  VoidCallback onBack,
);

enum _CompletionAction { save, home }

typedef PhotoBoothCompletionStatus = ({bool completed, bool busy});

class PhotoBoothContinueEditingAction extends StatelessWidget {
  const PhotoBoothContinueEditingAction({
    required this.status,
    required this.onPressed,
    super.key,
  });
  final PhotoBoothCompletionStatus status;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => !status.completed
      ? const SizedBox.shrink()
      : IconButton(
          key: const ValueKey('photobooth-continue-editing'),
          tooltip: 'Tiếp tục chỉnh sửa',
          onPressed: status.busy ? null : onPressed,
          icon: const Icon(Icons.edit_rounded),
        );
}

class PhotoBoothEditorEntry extends StatefulWidget {
  const PhotoBoothEditorEntry({
    required this.session,
    required this.onBack,
    this.controller,
    this.catalog,
    this.onUseHome,
    this.onChooseFour,
    this.onCompletionChanged,
    this.exporter = const PhotoBoothExporter(),
    this.gallery = const PhotoBoothGallery(),
    super.key,
  });
  final PhotoBoothSession session;
  final VoidCallback onBack;
  final VoidCallback? onChooseFour;
  final ValueChanged<PhotoBoothCompletionStatus>? onCompletionChanged;
  final PhotoBoothEditorController? controller;
  final PhotoBoothCatalog? catalog;
  final Future<bool> Function(String path)? onUseHome;
  final PhotoBoothExporter exporter;
  final PhotoBoothGallery gallery;

  @override
  State<PhotoBoothEditorEntry> createState() => PhotoBoothEditorEntryState();
}

class PhotoBoothEditorEntryState extends State<PhotoBoothEditorEntry> {
  late final PhotoBoothEditorController editor;
  PhotoBoothImages _images = PhotoBoothImages();
  PhotoBoothCatalog? _catalog;
  bool _loading = true, _busy = false, _completed = false, _settings = false;
  String? _error, _notice, _output, _outputFingerprint;
  _CompletionAction? _completionAction;
  int _tab = 0, _generation = 0;
  String _group = 'animals';
  String? _frameCategory;
  String? _frameShape;
  final _previewFraction = ValueNotifier(.60);
  final _photoPaints = ValueNotifier(0);
  final _stickerPaints = ValueNotifier(0);
  final _textPaints = ValueNotifier(0);
  final _selectionPaints = ValueNotifier(0);
  final _textTools = ValueNotifier(0);
  final _quickTools = ValueNotifier(0);
  late PhotoBoothEdit _observedDraft;
  late bool _observedCanUndo;
  bool _gestureUndoActive = false;
  PhotoBoothFrame? _resolvedFrame;
  String? _resolvedFrameKey;
  List<int>? _resolvedHomePhotos;
  int _homeSlot = 0;
  int? _sticker, _photo, _text;
  PhotoBoothText? _gestureText;
  PhotoBoothSticker? _gestureSticker;
  PhotoBoothPhotoTransform? _gesturePhoto;
  PhotoBoothSlot? _gestureSlot;
  Offset _gestureOrigin = Offset.zero;
  final _pointerStarts = <int, Offset>{};
  int? _tapPointer;
  Offset _tapStart = Offset.zero;
  (ScaleUpdateDetails, Size)? _pendingGesture;
  int? _gestureFrame;
  PhotoBoothText? _captionToEdit;
  int? _textBeforeAdding;
  Offset? _doubleTapPoint;
  ModalRoute<dynamic>? _dialog;

  PhotoBoothFrame get _frame {
    if (_resolvedFrame == null ||
        _resolvedFrameKey != editor.draft.frameKey ||
        !identical(_resolvedHomePhotos, editor.draft.homePhotos)) {
      _resolvedFrameKey = editor.draft.frameKey;
      _resolvedHomePhotos = editor.draft.homePhotos;
      _resolvedFrame = editor.resolveFrame(_catalog!);
    }
    return _resolvedFrame!;
  }

  PhotoBoothPainter get _painter => PhotoBoothPainter(
    frame: _frame,
    draft: editor.draft,
    catalog: _catalog!,
    images: _images,
  );

  @override
  void initState() {
    super.initState();
    editor = widget.controller ?? PhotoBoothEditorController(widget.session);
    _observedDraft = editor.draft;
    _observedCanUndo = editor.canUndo;
    editor.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onCompletionChanged?.call((completed: _completed, busy: _busy));
      }
    });
    unawaited(_load());
  }

  void _changed() {
    if (_observedCanUndo != editor.canUndo) {
      _observedCanUndo = editor.canUndo;
      _quickTools.value++;
    }
    final previous = _observedDraft;
    final current = _observedDraft = editor.draft;
    final frameChanged =
        previous.frameKey != current.frameKey ||
        !identical(previous.homePhotos, current.homePhotos);
    final structureChanged =
        frameChanged ||
        previous.stickers.length != current.stickers.length ||
        previous.texts.length != current.texts.length;
    if (structureChanged && _catalog != null && !_images.disposed) {
      _images.retainAssets({
        if (_frame.asset != null) _frame.asset!,
        for (final sticker in editor.draft.stickers)
          _catalog!.sticker(sticker.assetKey).asset,
      });
    }
    if (frameChanged || !identical(previous.photos, current.photos)) {
      _photoPaints.value++;
    }
    if (frameChanged || !identical(previous.stickers, current.stickers)) {
      _stickerPaints.value++;
    }
    if (frameChanged || !identical(previous.texts, current.texts)) {
      _textPaints.value++;
    }
    final beforeText = previous.texts
        .where((text) => text.id == _text)
        .firstOrNull;
    final afterText = current.texts
        .where((text) => text.id == _text)
        .firstOrNull;
    if (beforeText?.fontSize != afterText?.fontSize ||
        beforeText?.color != afterText?.color ||
        beforeText?.backgroundColor != afterText?.backgroundColor) {
      _textTools.value++;
    }
    if (_photo != null &&
        (previous.photos[_photo]?.zoom ?? 1) !=
            (current.photos[_photo]?.zoom ?? 1)) {
      _quickTools.value++;
    }
    _selectionPaints.value++;
    // Pointer movement only invalidates paint layers and the small tool strip.
    if (mounted && structureChanged) {
      setState(() {
        if (_photo != null &&
            !_frame.slots.any((slot) => slot.photo == _photo)) {
          _photo = null;
        }
      });
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _images.dispose();
    final images = _images = PhotoBoothImages();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = widget.catalog ?? await PhotoBoothCatalog.load();
      await images.loadPhotos(widget.session);
      final frame = editor.resolveFrame(catalog);
      if (frame.asset != null) await images.loadAsset(frame.asset!);
      for (final sticker in editor.draft.stickers) {
        await images.loadAsset(catalog.sticker(sticker.assetKey).asset);
      }
      if (!mounted || generation != _generation) return;
      // Fit retained stickers to the new canvas when the photo count changed.
      editor.setFrame(frame, catalog, recordHistory: false);
      setState(() {
        _catalog = catalog;
        _resolvedFrame = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error =
            'Chưa mở được bộ ảnh. Bạn hãy thử lại hoặc quay lại chọn ảnh khác.';
      });
    }
  }

  Future<void> _assetAction(Future<void> Function() action) async {
    if (_busy) return;
    _endGesture();
    editor.endUndoGroup();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Chưa tải được mẫu trang trí. Bạn hãy thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _undo() => _assetAction(() async {
    final previous = editor.undoDraft;
    if (previous == null) return;
    final frame = previous.frameKey.startsWith('home-')
        ? PhotoBoothFrame.home(
            previous.homePhotos?.length ?? widget.session.mode.count,
            photoIndices: previous.homePhotos,
          )
        : _catalog!.frame(previous.frameKey, widget.session.mode.count);
    if (frame.asset != null) await _images.loadAsset(frame.asset!);
    for (final sticker in previous.stickers) {
      await _images.loadAsset(_catalog!.sticker(sticker.assetKey).asset);
    }
    if (!mounted) return;
    final changedFrame = editor.draft.frameKey != previous.frameKey;
    editor.undo();
    setState(() {
      if (!editor.draft.texts.any((text) => text.id == _text)) _text = null;
      if (!editor.draft.stickers.any((sticker) => sticker.id == _sticker)) {
        _sticker = null;
      }
      if (!_frame.slots.any((slot) => slot.photo == _photo)) _photo = null;
      if (changedFrame) {
        _frameCategory = frame.theme;
        _frameShape = null;
      }
    });
  });

  Future<void> _frameSelected(PhotoBoothFrame frame) {
    if (editor.draft.frameKey == frame.key) return Future.value();
    return _assetAction(() async {
      if (frame.asset != null) await _images.loadAsset(frame.asset!);
      if (!mounted) return;
      if (frame.theme == 'home' && widget.session.mode == PhotoBoothMode.four) {
        editor.prepareHome(_catalog!);
      } else {
        editor.setFrame(frame, _catalog!);
      }
      _sticker = null;
      _photo = null;
      _text = null;
    });
  }

  Future<void> _restoreStrip() => _assetAction(() async {
    final draft = editor.stripDraft;
    if (draft == null) return;
    final frame = _catalog!.frame(draft.frameKey, widget.session.mode.count);
    if (frame.asset != null) await _images.loadAsset(frame.asset!);
    for (final sticker in draft.stickers) {
      await _images.loadAsset(_catalog!.sticker(sticker.assetKey).asset);
    }
    if (mounted) editor.restoreStrip();
  });

  Future<void> _addSticker(PhotoBoothStickerAsset asset) =>
      _assetAction(() async {
        if (editor.draft.stickers.length >= 8) {
          setState(() => _notice = 'Bạn có thể thêm tối đa 8 sticker.');
          return;
        }
        await _images.loadAsset(asset.asset);
        if (!mounted) return;
        if (editor.addSticker(asset, _frame)) {
          _sticker = editor.draft.stickers.last.id;
          _photo = null;
          _text = null;
        }
      });

  PhotoBoothText? get _selectedText =>
      editor.draft.texts.where((text) => text.id == _text).firstOrNull;

  void _changeTextInput(PhotoBoothTextInput input) {
    final selected = _selectedText;
    if (_busy || selected == null) return;
    editor.changeText(
      selected
          .copy(
            color: input.color,
            backgroundColor: input.backgroundColor,
            fontSize: input.fontSize,
          )
          .move(_frame.size, layouts: _images.textLayouts),
    );
  }

  void _beginTextEdit([PhotoBoothText? text, Offset? point]) {
    if (_busy || _captionToEdit != null) return;
    _endGesture();
    if (text == null && editor.draft.texts.length >= 8) {
      setState(() => _notice = 'Bạn có thể thêm tối đa 8 đoạn chữ.');
      return;
    }
    final previousSelection = _text;
    setState(() {
      _textBeforeAdding = text == null ? previousSelection : null;
      _tab = 2;
      _text = text?.id;
      _sticker = _photo = null;
      _notice = null;
      _captionToEdit =
          text ??
          PhotoBoothText(
            id: -1,
            text: '',
            x: point == null ? .5 : point.dx / _frame.size.width,
            y: point == null ? .5 : point.dy / _frame.size.height,
          );
    });
  }

  void _cancelTextEdit() => setState(() {
    _captionToEdit = null;
    _text = _textBeforeAdding ?? _text;
    _textBeforeAdding = null;
  });

  void _confirmTextEdit(PhotoBoothText text) {
    if (_captionToEdit == null || _busy) return;
    editor.beginUndoGroup();
    try {
      var id = text.id;
      if (id < 0) {
        final added = editor.addText(
          text.text,
          _frame,
          color: text.color,
          backgroundColor: text.backgroundColor,
          fontSize: text.fontSize,
        );
        if (added == null) return;
        id = added.id;
        editor.changeText(
          added.move(
            _frame.size,
            x: text.x,
            y: text.y,
            layouts: _images.textLayouts,
          ),
        );
      } else {
        editor.changeText(text);
      }
      setState(() {
        _captionToEdit = null;
        _textBeforeAdding = null;
        _text = id;
        _sticker = _photo = null;
      });
    } finally {
      editor.endUndoGroup();
    }
  }

  void _selectTab(int tab) {
    _endGesture();
    setState(() => _tab = tab);
    if (tab == 2 && editor.draft.texts.isEmpty) _beginTextEdit();
  }

  void _tapCanvas(Offset point, {bool editContent = false}) {
    _endGesture();
    final text = editor.draft.texts.reversed
        .where(
          (text) => text.hit(point, _frame.size, layouts: _images.textLayouts),
        )
        .firstOrNull;
    if (text != null) {
      if (editContent) {
        _beginTextEdit(text);
      } else {
        _setSelection(null, null, text: text.id);
      }
    } else if (_tab == 2) {
      _clearSelection();
      if (editContent) _beginTextEdit(null, point);
    } else {
      _select(point);
    }
  }

  Widget _captionEditor() => PhotoBoothCaptionEditor(
    initial: _captionToEdit!,
    layouts: _images.textLayouts,
    canvasSize: _frame.size,
    onConfirm: _confirmTextEdit,
    onCancel: _cancelTextEdit,
    previewBuilder: (pending) {
      final draft = editor.draft.copy(
        texts: [
          for (final text in editor.draft.texts)
            if (text.id == pending.id) pending else text,
          if (pending.id < 0) pending,
        ],
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          for (final layer in [
            PhotoBoothPaintLayer.photos,
            PhotoBoothPaintLayer.frame,
            PhotoBoothPaintLayer.stickers,
            PhotoBoothPaintLayer.texts,
          ])
            RepaintBoundary(
              child: CustomPaint(
                key: ValueKey('photobooth-text-edit-${layer.name}'),
                painter: PhotoBoothPainter(
                  frame: _frame,
                  draft: draft,
                  catalog: _catalog!,
                  images: _images,
                  layer: layer,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
        ],
      );
    },
  );

  Future<bool> requestLeave() async {
    _endGesture();
    if (_captionToEdit != null) {
      _cancelTextEdit();
      return false;
    }
    if (_busy) return false;
    if (!editor.dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            _dialog = ModalRoute.of(context);
            return AlertDialog(
              title: const Text('Quay lại chọn ảnh?'),
              content: const Text('Ảnh đang sửa vẫn được giữ.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Sửa tiếp'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Quay lại'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _leave({bool four = false}) async {
    if (await requestLeave() && mounted) {
      if (four && widget.onChooseFour != null) {
        widget.onChooseFour!();
      } else {
        widget.onBack();
      }
    }
  }

  void _select(Offset point) {
    for (final text in editor.draft.texts.reversed) {
      if (text.hit(point, _frame.size, layouts: _images.textLayouts)) {
        _setSelection(null, null, text: text.id);
        return;
      }
    }
    for (final sticker in editor.draft.stickers.reversed) {
      if (sticker.hit(
        point,
        _frame.size,
        _catalog!.sticker(sticker.assetKey).size,
      )) {
        _setSelection(sticker.id, null);
        return;
      }
    }
    _setSelection(
      null,
      _frame.slots
          .where((slot) => slot.rect.contains(point))
          .firstOrNull
          ?.photo,
    );
  }

  void _startGesture(ScaleStartDetails details, Size preview) {
    _endGesture();
    editor.beginUndoGroup();
    _gestureUndoActive = true;
    _tapPointer = null;
    final point = Offset(
      details.localFocalPoint.dx * _frame.size.width / preview.width,
      details.localFocalPoint.dy * _frame.size.height / preview.height,
    );
    // Scale recognition waits for touch slop. Hit-test where the user first
    // touched, so a small caption is not lost by the time dragging starts.
    final initial = _pointerStarts.isEmpty
        ? point
        : _pointerStarts.values.fold(Offset.zero, (sum, point) => sum + point) /
              _pointerStarts.length.toDouble();
    _select(initial);
    _gestureOrigin = _pointerStarts.length == 1 ? initial : point;
    _gestureText = editor.draft.texts
        .where((text) => text.id == _text)
        .firstOrNull;
    _gestureSticker = editor.draft.stickers
        .where((s) => s.id == _sticker)
        .firstOrNull;
    _gestureSlot = _frame.slots
        .where((slot) => slot.photo == _photo && slot.rect.contains(initial))
        .firstOrNull;
    _gesturePhoto = _photo == null
        ? null
        : editor.draft.photos[_photo] ?? const PhotoBoothPhotoTransform();
  }

  void _updateGesture(ScaleUpdateDetails details, Size preview) {
    if (!_gestureUndoActive) return;
    _pendingGesture = (details, preview);
    _gestureFrame ??= SchedulerBinding.instance.scheduleFrameCallback((_) {
      _gestureFrame = null;
      _flushGesture();
    });
  }

  void _endGesture() {
    _flushGesture();
    if (_gestureUndoActive) {
      _gestureUndoActive = false;
      editor.endUndoGroup();
    }
    _gestureText = null;
    _gestureSticker = null;
    _gesturePhoto = null;
    _gestureSlot = null;
  }

  void _flushGesture() {
    final callback = _gestureFrame;
    if (callback != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(callback);
    }
    _gestureFrame = null;
    final pending = _pendingGesture;
    _pendingGesture = null;
    if (pending != null && mounted && !_busy) {
      _applyGesture(pending.$1, pending.$2);
    }
  }

  void _applyGesture(ScaleUpdateDetails details, Size preview) {
    final point = Offset(
      details.localFocalPoint.dx * _frame.size.width / preview.width,
      details.localFocalPoint.dy * _frame.size.height / preview.height,
    );
    final delta = point - _gestureOrigin;
    if (_gestureText != null) {
      final text = _gestureText!;
      editor.changeText(
        text.move(
          _frame.size,
          x: text.x + delta.dx / _frame.size.width,
          y: text.y + delta.dy / _frame.size.height,
          fontSize: text.fontSize * details.scale,
          rotation: text.rotation + details.rotation,
          layouts: _images.textLayouts,
        ),
      );
    } else if (_gestureSticker != null) {
      final sticker = _gestureSticker!;
      editor.changeSticker(
        sticker.move(
          _frame.size,
          _catalog!.sticker(sticker.assetKey).size,
          x: sticker.x + delta.dx / _frame.size.width,
          y: sticker.y + delta.dy / _frame.size.height,
          width: sticker.width * details.scale,
          rotation: sticker.rotation + details.rotation,
        ),
      );
    } else if (_gestureSlot != null && _gesturePhoto != null) {
      final slot = _gestureSlot!;
      final photo = _images.photos[slot.photo];
      editor.setPhoto(
        slot.photo,
        _gesturePhoto!.gesture(
          Size(photo.width.toDouble(), photo.height.toDouble()),
          slot.rect.size,
          Offset(delta.dx / slot.rect.width, delta.dy / slot.rect.height),
          details.scale,
        ),
      );
    }
  }

  void _setCompletionState(VoidCallback update) {
    setState(update);
    widget.onCompletionChanged?.call((completed: _completed, busy: _busy));
  }

  void continueEditing() {
    if (!_completed || _busy) return;
    _setCompletionState(() {
      _completed = false;
      _error = _notice = null;
      _settings = false;
    });
  }

  Future<void> _finish() async {
    _endGesture();
    if (_busy || _catalog == null) return;
    _setCompletionState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    final fingerprint = editor.draft.fingerprint;
    try {
      final output = _outputFingerprint == fingerprint && _output != null
          ? _output!
          : await widget.exporter.export(widget.session, _painter);
      if (!mounted) return;
      _output = output;
      _outputFingerprint = fingerprint;
      editor.markSaved();
      _setCompletionState(() {
        _completed = true;
        _sticker = null;
        _photo = null;
        _text = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Chưa xuất được ảnh. Bộ ảnh và chỉnh sửa vẫn được giữ, bạn hãy thử lại.',
        );
      }
    } finally {
      if (mounted) _setCompletionState(() => _busy = false);
    }
  }

  Future<void> _saveGallery() async {
    if (_output == null || _busy) return;
    _setCompletionState(() {
      _busy = true;
      _error = null;
      _notice = null;
      _settings = false;
      _completionAction = _CompletionAction.save;
    });
    try {
      await widget.gallery.save(_output!);
      if (mounted) {
        setState(() => _notice = 'Đã lưu ảnh vào thư viện!');
      }
    } on PhotoBoothException catch (failure) {
      if (mounted) {
        setState(() {
          _error = failure.message;
          _settings = failure.canOpenSettings;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa lưu được ảnh. Bạn hãy thử lại.');
      }
    } finally {
      if (mounted) {
        _setCompletionState(() {
          _busy = false;
          _completionAction = null;
        });
      }
    }
  }

  Future<void> _useHome() async {
    _endGesture();
    final apply = widget.onUseHome;
    if (_busy || _catalog == null || apply == null) return;
    // Hand off the completed artwork, including the selected frame. Home fits
    // this bitmap to its canvas without rebuilding the photo/sticker layout.
    if (_output == null || _outputFingerprint != editor.draft.fingerprint) {
      await _finish();
    }
    if (!mounted ||
        _output == null ||
        _outputFingerprint != editor.draft.fingerprint) {
      return;
    }
    _setCompletionState(() {
      _busy = true;
      _error = null;
      _notice = null;
      _settings = false;
      _completionAction = _CompletionAction.home;
    });
    try {
      await apply(_output!);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is BackgroundImageException ? error.message : 'Chưa áp dụng được ảnh nền. Ảnh cũ và bộ ảnh vẫn được giữ, bạn hãy thử lại.',
        );
      }
    } finally {
      if (mounted) {
        _setCompletionState(() {
          _busy = false;
          _completionAction = null;
        });
      }
    }
  }

  void _largePreview() {
    _endGesture();
    showDialog<void>(
      context: context,
      builder: (context) {
        _dialog = ModalRoute.of(context);
        return Dialog.fullscreen(
          child: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Đóng ảnh lớn',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _frame.size.aspectRatio,
                        child: CustomPaint(painter: _painter),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    ++_generation;
    final callback = _gestureFrame;
    if (callback != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(callback);
    }
    _pendingGesture = null;
    final dialog = _dialog;
    if (dialog != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (dialog.isActive) dialog.navigator?.removeRoute(dialog);
      });
    }
    editor.removeListener(_changed);
    if (_gestureUndoActive) editor.endUndoGroup();
    _previewFraction.dispose();
    _photoPaints.dispose();
    _stickerPaints.dispose();
    _textPaints.dispose();
    _selectionPaints.dispose();
    _textTools.dispose();
    _quickTools.dispose();
    if (widget.controller == null) editor.dispose();
    _images.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_catalog == null ||
        _images.photos.length != widget.session.mode.count) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error ?? 'Chưa mở được bộ ảnh.',
                textAlign: TextAlign.center,
              ),
              FilledButton(onPressed: _load, child: const Text('Thử lại')),
              TextButton(
                onPressed: () => _leave(),
                child: const Text('Quay lại chọn ảnh'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        if (_error != null || _notice != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: _statusMessage(),
          ),
        if (_settings) _settingsButton(),
        Expanded(child: _completed ? _completion() : _workspace()),
      ],
    );
  }

  Widget _statusMessage() {
    final colors = Theme.of(context).colorScheme;
    final failed = _error != null;
    final ink = failed ? colors.onErrorContainer : colors.onPrimaryContainer;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('photobooth-status-message'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: failed ? colors.errorContainer : colors.primaryContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: (failed ? colors.error : colors.primary).withValues(
              alpha: .3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              failed ? Icons.error_rounded : Icons.check_circle_rounded,
              size: 28,
              color: ink,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _error ?? _notice!,
                style: TextStyle(
                  color: ink,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsButton() => TextButton(
    onPressed: _busy
        ? null
        : () async {
            try {
              await permissions.openAppSettings();
            } catch (_) {
              /* Keep message visible. */
            }
          },
    child: const Text('Mở Cài đặt'),
  );

  Widget _completionButtonContent(
    String label,
    IconData icon,
    _CompletionAction action,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      if (_completionAction == action)
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
            semanticsLabel: action == _CompletionAction.save
                ? 'Đang lưu ảnh'
                : 'Đang mở ảnh nền',
          ),
        )
      else
        Icon(icon, size: 20),
      const SizedBox(width: 6),
      Flexible(child: Text(label, textAlign: TextAlign.center)),
    ],
  );

  Widget _completion() => LayoutBuilder(
    builder: (context, constraints) {
      final textStyle = Theme.of(context).textTheme.labelLarge!
          .copyWith(fontSize: 14, height: 1.2, fontWeight: FontWeight.w700);
      final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      );
      return Column(
        children: [
          Expanded(child: _preview()),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * .65),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: SingleChildScrollView(
                key: const ValueKey('photobooth-completion-actions'),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        key: const ValueKey('photobooth-primary-actions'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: _busy ? null : _saveGallery,
                              style: FilledButton.styleFrom(
                                shape: shape,
                                textStyle: textStyle,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                              child: _completionButtonContent(
                                'Lưu về máy',
                                Icons.save_alt_rounded,
                                _CompletionAction.save,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _busy || widget.onUseHome == null
                                  ? null
                                  : _useHome,
                              style: OutlinedButton.styleFrom(
                                shape: shape,
                                textStyle: textStyle,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                              child: _completionButtonContent(
                                'Dùng làm nền Home',
                                Icons.wallpaper_rounded,
                                _CompletionAction.home,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _workspace() => _captionToEdit != null
      ? _captionEditor()
      : LayoutBuilder(
          builder: (context, constraints) {
            final usable = math.max(0.0, constraints.maxHeight - 68);
            final minimum = math.min(144.0, usable * .4);
            void resize(double delta) {
              if (usable > 0) {
                _previewFraction.value =
                    (_previewFraction.value + delta / usable).clamp(0.0, 1.0);
              }
            }

            final preview = _preview();
            final toolbar = _editorToolbar();
            final library = RepaintBoundary(
              child: Material(
                key: const ValueKey('photobooth-library-panel'),
                color: Theme.of(context).colorScheme.surface,
                child: switch (_tab) {
                  0 => _framesPanel(),
                  1 => _stickersPanel(),
                  _ => _textsPanel(),
                },
              ),
            );
            return ValueListenableBuilder<double>(
              valueListenable: _previewFraction,
              builder: (context, fraction, _) {
                final previewHeight = (usable * fraction).clamp(
                  minimum,
                  usable - minimum,
                );
                return Column(
                  children: [
                    SizedBox(
                      key: const ValueKey('photobooth-preview-area'),
                      height: previewHeight,
                      child: preview,
                    ),
                    Semantics(
                      label: 'Điều chỉnh kích thước vùng ảnh',
                      onIncrease: () => resize(usable * .05),
                      onDecrease: () => resize(-usable * .05),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeUpDown,
                        child: GestureDetector(
                          key: const ValueKey('photobooth-preview-resize'),
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: _busy
                              ? null
                              : (details) => resize(details.delta.dy),
                          child: SizedBox(
                            height: 20,
                            child: Center(
                              child: Container(
                                width: 36,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    toolbar,
                    Expanded(child: library),
                  ],
                );
              },
            );
          },
        );

  Widget _editorToolbar() => SizedBox(
    key: const ValueKey('photobooth-editor-toolbar'),
    height: 48,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Quay lại chọn ảnh',
            onPressed: _busy ? null : () => _leave(),
            icon: const Icon(Icons.arrow_back_rounded),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 48),
            padding: const EdgeInsets.all(10),
          ),
          for (var tab = 0; tab < 3; tab++)
            Expanded(
              flex: tab == 1
                  ? 13
                  : tab == 0
                  ? 11
                  : 8,
              child: Semantics(
                selected: _tab == tab,
                child: TextButton(
                  onPressed: _busy ? null : () => _selectTab(tab),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    foregroundColor: _tab == tab
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 12,
                      fontWeight: _tab == tab
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                  child: Text(const ['Khung', 'Sticker', 'Chữ'][tab]),
                ),
              ),
            ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: _busy ? null : _finish,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              textStyle: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            child: _busy
                ? const SizedBox(
                    width: 58,
                    height: 18,
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : const Text('Hoàn tất'),
          ),
        ],
      ),
    ),
  );

  void _setSelection(int? sticker, int? photo, {int? text}) {
    if (_sticker == sticker &&
        _photo == photo &&
        _text == text &&
        (text == null || _tab == 2)) {
      return;
    }
    _flushGesture();
    setState(() {
      _sticker = sticker;
      _photo = photo;
      _text = text;
      if (text != null) _tab = 2;
    });
  }

  void _clearSelection() => _setSelection(null, null);

  Widget _preview() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: _frame.size.aspectRatio,
            child: LayoutBuilder(
              builder: (context, preview) {
                final size = preview.biggest;
                final canDoubleTap =
                    !_busy &&
                    !_completed &&
                    (_tab == 2 || editor.draft.texts.isNotEmpty);
                return Listener(
                  onPointerDown: (event) {
                    if (_pointerStarts.isEmpty) {
                      _tapPointer = event.pointer;
                      _tapStart = event.localPosition;
                    } else {
                      _tapPointer = null;
                    }
                    _pointerStarts[event.pointer] = Offset(
                      event.localPosition.dx * _frame.size.width / size.width,
                      event.localPosition.dy * _frame.size.height / size.height,
                    );
                  },
                  onPointerMove: (event) {
                    if (_tapPointer == event.pointer &&
                        (event.localPosition - _tapStart).distance >
                            kTouchSlop) {
                      _tapPointer = null;
                    }
                  },
                  onPointerUp: (event) {
                    final tap =
                        _tapPointer == event.pointer &&
                        _pointerStarts.length == 1;
                    _pointerStarts.remove(event.pointer);
                    _tapPointer = null;
                    if (tap &&
                        !_busy &&
                        !_completed &&
                        _captionToEdit == null) {
                      _tapCanvas(
                        Offset(
                          event.localPosition.dx *
                              _frame.size.width /
                              size.width,
                          event.localPosition.dy *
                              _frame.size.height /
                              size.height,
                        ),
                      );
                    }
                  },
                  onPointerCancel: (event) {
                    _tapPointer = null;
                    _pointerStarts.remove(event.pointer);
                  },
                  child: GestureDetector(
                    key: const ValueKey('photobooth-editor-canvas'),
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onDoubleTapDown: !canDoubleTap
                        ? null
                        : (details) {
                            _doubleTapPoint = Offset(
                              details.localPosition.dx *
                                  _frame.size.width /
                                  size.width,
                              details.localPosition.dy *
                                  _frame.size.height /
                                  size.height,
                            );
                          },
                    onDoubleTap: !canDoubleTap
                        ? null
                        : () {
                            final point = _doubleTapPoint;
                            if (point != null) {
                              _tapCanvas(point, editContent: true);
                            }
                            _doubleTapPoint = null;
                          },
                    onDoubleTapCancel: !canDoubleTap
                        ? null
                        : () => _doubleTapPoint = null,
                    onScaleStart: _busy || _completed
                        ? null
                        : (details) => _startGesture(details, size),
                    onScaleUpdate: _busy || _completed
                        ? null
                        : (details) => _updateGesture(details, size),
                    onScaleEnd: _busy || _completed
                        ? null
                        : (_) => _endGesture(),
                    child: Semantics(
                      label: 'Ảnh đang trang trí',
                      onTap: _busy || _completed
                          ? null
                          : () => _tapCanvas(_frame.size.center(Offset.zero)),
                      child: _canvasLayers(),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            tooltip: 'Xem ảnh lớn',
            onPressed: _busy ? null : _largePreview,
            icon: const Icon(Icons.fullscreen_rounded),
          ),
        ),
        if (!_completed)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              key: const ValueKey('photobooth-selection-toolbar'),
              color: Theme.of(context).colorScheme.surface
                  .withValues(alpha: .94),
              elevation: 1,
              borderRadius: BorderRadius.circular(12),
              child: IconButtonTheme(
                data: IconButtonThemeData(
                  style: IconButton.styleFrom(
                    minimumSize: const Size(40, 48),
                    maximumSize: const Size(44, 48),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                child: ListenableBuilder(
                  listenable: _quickTools,
                  builder: (_, _) => _selectionControls(),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _canvasLayers() => Stack(
    fit: StackFit.expand,
    children: [
      for (final layer in [
        PhotoBoothPaintLayer.photos,
        PhotoBoothPaintLayer.frame,
        PhotoBoothPaintLayer.stickers,
        PhotoBoothPaintLayer.texts,
      ])
        RepaintBoundary(
          key: ValueKey('photobooth-preview-${layer.name}'),
          child: CustomPaint(
            isComplex: layer == PhotoBoothPaintLayer.photos,
            painter: PhotoBoothPainter(
              frame: _frame,
              draft: editor.draft,
              catalog: _catalog!,
              images: _images,
              liveEditor: editor,
              layer: layer,
              filterQuality: FilterQuality.medium,
              repaint: layer == PhotoBoothPaintLayer.photos
                  ? _photoPaints
                  : layer == PhotoBoothPaintLayer.stickers
                  ? _stickerPaints
                  : layer == PhotoBoothPaintLayer.texts
                  ? _textPaints
                  : null,
            ),
          ),
        ),
      if (!_completed)
        RepaintBoundary(
          child: CustomPaint(
            painter: _SelectionPainter(
              _frame,
              editor.draft,
              _catalog!,
              _sticker,
              _photo,
              textId: _text,
              layouts: _images.textLayouts,
              liveEditor: editor,
              repaint: _selectionPaints,
            ),
          ),
        ),
    ],
  );

  Widget _selectionControls() {
    final undo = IconButton(
      key: const ValueKey('photobooth-quick-undo'),
      tooltip: 'Hoàn tác',
      onPressed: _busy || !editor.canUndo ? null : _undo,
      icon: const Icon(Icons.undo_rounded),
    );
    final text = _selectedText;
    if (text != null) {
      return SizedBox(
        key: const ValueKey('photobooth-text-quick-toolbar'),
        height: 48,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            undo,
            IconButton(
              key: const ValueKey('photobooth-quick-add-text'),
              tooltip: 'Thêm chữ',
              onPressed: _busy || editor.draft.texts.length >= 8
                  ? null
                  : () => _beginTextEdit(),
              icon: const Icon(Icons.add_rounded),
            ),
            IconButton(
              tooltip: 'Sửa chữ',
              onPressed: _busy
                  ? null
                  : () {
                      _endGesture();
                      final current = _selectedText;
                      if (current != null) _beginTextEdit(current);
                    },
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Xoay chữ',
              onPressed: _busy
                  ? null
                  : () {
                      _endGesture();
                      final current = _selectedText;
                      if (current == null) return;
                      editor.changeText(
                        current.move(
                          _frame.size,
                          rotation: current.rotation + math.pi / 12,
                          layouts: _images.textLayouts,
                        ),
                      );
                    },
              icon: const Icon(Icons.rotate_right_rounded),
            ),
            IconButton(
              tooltip: 'Đưa chữ lên trên',
              onPressed: _busy ? null : () => editor.raiseText(text.id),
              icon: const Icon(Icons.flip_to_front_rounded),
            ),
            IconButton(
              tooltip: 'Xóa chữ',
              onPressed: _busy
                  ? null
                  : () {
                      editor.removeText(text.id);
                      _clearSelection();
                    },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
            IconButton(
              tooltip: 'Ẩn công cụ',
              onPressed: _busy ? null : _clearSelection,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      );
    }
    final sticker = editor.draft.stickers
        .where((s) => s.id == _sticker)
        .firstOrNull;
    if (sticker != null) {
      void adjust({double scale = 1, double angle = 0}) {
        _endGesture();
        final current = editor.draft.stickers
            .where((value) => value.id == sticker.id)
            .firstOrNull;
        if (current == null) return;
        editor.changeSticker(
          current.move(
            _frame.size,
            _catalog!.sticker(sticker.assetKey).size,
            width: current.width * scale,
            rotation: current.rotation + angle,
          ),
        );
      }

      return SizedBox(
        height: 48,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            undo,
            IconButton(
              tooltip: 'Thu nhỏ sticker',
              onPressed: _busy ? null : () => adjust(scale: .9),
              icon: const Icon(Icons.remove_rounded),
            ),
            IconButton(
              tooltip: 'Phóng to sticker',
              onPressed: _busy ? null : () => adjust(scale: 1.1),
              icon: const Icon(Icons.add_rounded),
            ),
            IconButton(
              tooltip: 'Xoay sticker',
              onPressed: _busy ? null : () => adjust(angle: math.pi / 12),
              icon: const Icon(Icons.rotate_right_rounded),
            ),
            IconButton(
              tooltip: 'Đưa sticker lên trên',
              onPressed: _busy ? null : () => editor.raiseSticker(sticker.id),
              icon: const Icon(Icons.flip_to_front_rounded),
            ),
            IconButton(
              tooltip: 'Xóa sticker',
              onPressed: _busy
                  ? null
                  : () {
                      editor.removeSticker(sticker.id);
                      setState(() => _sticker = null);
                    },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
            IconButton(
              tooltip: 'Ẩn công cụ',
              onPressed: _busy ? null : _clearSelection,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      );
    }
    if (_photo != null) {
      final photo =
          editor.draft.photos[_photo] ?? const PhotoBoothPhotoTransform();
      return SizedBox(
        height: 48,
        child: Row(
          children: [
            undo,
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text('Ảnh ${_photo! + 1}'),
            ),
            Expanded(
              child: Slider(
                value: photo.zoom,
                min: 1,
                max: 5,
                label: '${photo.zoom.toStringAsFixed(1)}×',
                onChangeStart: _busy ? null : (_) => editor.beginUndoGroup(),
                onChangeEnd: _busy ? null : (_) => editor.endUndoGroup(),
                onChanged: _busy
                    ? null
                    : (zoom) {
                        final index = _photo;
                        if (index == null) return;
                        final current =
                            editor.draft.photos[index] ??
                            const PhotoBoothPhotoTransform();
                        editor.setPhoto(
                          index,
                          PhotoBoothPhotoTransform(
                            x: current.x,
                            y: current.y,
                            zoom: zoom,
                          ),
                        );
                      },
              ),
            ),
            IconButton(
              tooltip: 'Đặt lại ảnh',
              onPressed: _busy
                  ? null
                  : () => editor.setPhoto(
                      _photo!,
                      const PhotoBoothPhotoTransform(),
                    ),
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: 'Ẩn công cụ',
              onPressed: _busy ? null : _clearSelection,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      );
    }
    return SizedBox(height: 48, child: Row(children: [undo]));
  }

  Widget _framesPanel() {
    if (editor.home && widget.session.mode == PhotoBoothMode.four) {
      final selected = editor.homePhotoIndices;
      return ListView(
        key: const ValueKey('photobooth-home-layouts'),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final count in [4, 2])
                ChoiceChip(
                  key: ValueKey('photobooth-home-layout-$count'),
                  label: Text(
                    count == 4 ? '4 ảnh lưới' : '2 ảnh nổi bật',
                    style: const TextStyle(fontSize: 13),
                  ),
                  selected: selected.length == count,
                  onSelected: _busy ? null : (_) => editor.setHomeLayout(count),
                ),
            ],
          ),
          if (selected.length == 2) ...[
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (var slot = 0; slot < 2; slot++)
                  ChoiceChip(
                    label: Text(
                      'Ô ${slot + 1} • Ảnh ${selected[slot] + 1}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: _homeSlot == slot,
                    onSelected: _busy
                        ? null
                        : (_) => setState(() => _homeSlot = slot),
                  ),
              ],
            ),
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.session.selectedPhotos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final slot = selected.indexOf(index);
                  return Semantics(
                    button: true,
                    selected: slot >= 0,
                    label:
                        'Ảnh ${index + 1}${slot < 0 ? '' : ', ô ${slot + 1}'}',
                    child: InkWell(
                      key: ValueKey('photobooth-home-photo-$index'),
                      onTap: _busy
                          ? null
                          : () {
                              editor.chooseHomePhoto(_homeSlot, index);
                              setState(() => _homeSlot = 1 - _homeSlot);
                            },
                      child: SizedBox(
                        width: 58,
                        child: Column(
                          children: [
                            Expanded(
                              child: RawImage(
                                image: _images.photos[index],
                                fit: BoxFit.cover,
                              ),
                            ),
                            Text(
                              'Ảnh ${index + 1}${slot < 0 ? '' : ' • ${slot + 1}'}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          TextButton(
            onPressed: _busy ? null : _restoreStrip,
            child: const Text('Quay lại khung kỷ niệm'),
          ),
        ],
      );
    }
    final frames = [
      PhotoBoothFrame.home(widget.session.mode.count),
      ..._catalog!.frames.where(
        (frame) => frame.photoCount == widget.session.mode.count,
      ),
    ];
    final categories = {
      for (final frame in frames) frame.theme: frame.categoryLabel,
    };
    final activeCategory = categories.containsKey(_frameCategory)
        ? _frameCategory
        : null;
    final categoryFrames = frames
        .where(
          (frame) => activeCategory == null || frame.theme == activeCategory,
        )
        .toList();
    final shapes = categoryFrames.map((frame) => frame.shapeKey).toSet();
    final activeShape = shapes.contains(_frameShape) ? _frameShape : null;
    final visible = categoryFrames
        .where((frame) => activeShape == null || frame.shapeKey == activeShape)
        .toList();
    return Column(
      children: [
        if (categories.length > 1 || shapes.length > 1)
          SizedBox(
            height: 44,
            child: Row(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final category in <MapEntry<String?, String>>[
                        const MapEntry(null, 'Tất cả'),
                        ...categories.entries,
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            key: ValueKey(
                              'photobooth-frame-category-${category.key ?? 'all'}',
                            ),
                            label: Text(
                              category.value,
                              style: const TextStyle(fontSize: 13),
                            ),
                            selected: activeCategory == category.key,
                            onSelected: _busy
                                ? null
                                : (_) => setState(() {
                                    _frameCategory = category.key;
                                    _frameShape = null;
                                  }),
                          ),
                        ),
                    ],
                  ),
                ),
                if (shapes.length > 1)
                  PopupMenuButton<String>(
                    key: const ValueKey('photobooth-frame-shape-filter'),
                    tooltip: 'Lọc bố cục khung',
                    enabled: !_busy,
                    initialValue: activeShape ?? 'all',
                    icon: Icon(
                      Icons.filter_list_rounded,
                      color: activeShape == null
                          ? null
                          : Theme.of(context).colorScheme.primary,
                    ),
                    onSelected: (value) => setState(
                      () => _frameShape = value == 'all' ? null : value,
                    ),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'all',
                        child: Text('Tất cả bố cục'),
                      ),
                      for (final shape in const {
                        'strip': 'Dải ảnh',
                        'portrait': 'Khung dọc',
                        'landscape': 'Khung ngang',
                        'square': 'Khung vuông',
                      }.entries)
                        if (shapes.contains(shape.key))
                          PopupMenuItem(
                            value: shape.key,
                            child: Text(shape.value),
                          ),
                    ],
                  ),
              ],
            ),
          ),
        Expanded(
          child: GridView.builder(
            key: const ValueKey('photobooth-frame-grid'),
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 124,
              mainAxisExtent: 126,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: visible.length,
            itemBuilder: (context, index) => _frameCard(visible[index]),
          ),
        ),
        if (editor.home && editor.stripDraft != null)
          TextButton(
            onPressed: _busy ? null : _restoreStrip,
            child: const Text(
              'Quay lại khung kỷ niệm',
              style: TextStyle(fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _frameCard(PhotoBoothFrame frame) {
    final selected = editor.draft.frameKey == frame.key;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: '${frame.label}, ${frame.formatLabel}',
      child: Tooltip(
        message: '${frame.label} • ${frame.formatLabel}',
        child: Material(
          color: selected
              ? colors.primaryContainer.withValues(alpha: .5)
              : colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('photobooth-frame-${frame.key}'),
            onTap: _busy ? null : () => _frameSelected(frame),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(
                          child: AspectRatio(
                            aspectRatio: frame.size.aspectRatio,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CustomPaint(
                                  painter: _NeutralFrameThumbnail(frame),
                                ),
                                if (frame.asset != null)
                                  Image.asset(
                                    frame.asset!,
                                    fit: BoxFit.contain,
                                    cacheWidth: 160,
                                    errorBuilder: (_, _, _) =>
                                        const Icon(Icons.broken_image_outlined),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (selected)
                          Align(
                            alignment: Alignment.topRight,
                            child: Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: colors.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    frame.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    frame.formatLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _textsPanel() => ListenableBuilder(
    listenable: _textTools,
    builder: (_, _) => PhotoBoothTextComposer(
      value: _selectedText,
      enabled: !_busy,
      onChanged: _changeTextInput,
      onChangeStart: editor.beginUndoGroup,
      onChangeEnd: editor.endUndoGroup,
    ),
  );

  Widget _stickersPanel() => Column(
    children: [
      SizedBox(
        height: 44,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          scrollDirection: Axis.horizontal,
          children: [
            for (final group in PhotoBoothCatalog.groups.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(group.value),
                  selected: _group == group.key,
                  onSelected: _busy
                      ? null
                      : (_) => setState(() => _group = group.key),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: Builder(
          builder: (context) {
            final assets = _catalog!.stickers
                .where((s) => s.group == _group)
                .toList();
            return GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 72,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: assets.length,
              itemBuilder: (_, index) => IconButton(
                key: ValueKey('photobooth-sticker-${assets[index].key}'),
                tooltip: 'Thêm sticker ${index + 1}',
                onPressed: _busy ? null : () => _addSticker(assets[index]),
                icon: Image.asset(
                  assets[index].asset,
                  cacheWidth: 96,
                  fit: BoxFit.contain,
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _NeutralFrameThumbnail extends CustomPainter {
  const _NeutralFrameThumbnail(this.frame);
  final PhotoBoothFrame frame;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / frame.size.width,
      size.height / frame.size.height,
    );
    canvas.save();
    canvas.translate(
      (size.width - frame.size.width * scale) / 2,
      (size.height - frame.size.height * scale) / 2,
    );
    canvas.scale(scale);
    canvas.drawRect(Offset.zero & frame.size, Paint()..color = Colors.white);
    for (final slot in frame.slots) {
      canvas.drawRect(slot.rect, Paint()..color = const Color(0xFFDCECE3));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NeutralFrameThumbnail oldDelegate) =>
      oldDelegate.frame.key != frame.key;
}

class _SelectionPainter extends CustomPainter {
  const _SelectionPainter(
    this.frame,
    this.draft,
    this.catalog,
    this.stickerId,
    this.photo, {
    this.textId,
    this.layouts,
    this.liveEditor,
    super.repaint,
  });
  final PhotoBoothFrame frame;
  final PhotoBoothEdit draft;
  final PhotoBoothCatalog catalog;
  final int? stickerId, photo;
  final int? textId;
  final PhotoBoothTextLayoutCache? layouts;
  final PhotoBoothEditorController? liveEditor;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(
      size.width / frame.size.width,
      size.height / frame.size.height,
    );
    canvas.clipRect(Offset.zero & frame.size);
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF1D7057)
      ..strokeWidth = 2 * frame.size.width / size.width;
    for (final slot in frame.slots.where((slot) => slot.photo == photo)) {
      canvas.drawRect(slot.rect.deflate(pen.strokeWidth / 2), pen);
    }
    final sticker = (liveEditor?.draft ?? draft).stickers
        .where((s) => s.id == stickerId)
        .firstOrNull;
    if (sticker != null) {
      canvas.save();
      final extent = sticker.extent(
        frame.size,
        catalog.sticker(sticker.assetKey).size,
      );
      canvas.translate(
        sticker.x * frame.size.width,
        sticker.y * frame.size.height,
      );
      canvas.rotate(sticker.rotation);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: extent.width,
          height: extent.height,
        ),
        pen,
      );
      canvas.restore();
    }
    final text = (liveEditor?.draft ?? draft).texts
        .where((text) => text.id == textId)
        .firstOrNull;
    if (text != null) {
      final layout =
          layouts?.obtain(text, frame.size) ?? text.layout(frame.size);
      canvas.save();
      canvas.translate(text.x * frame.size.width, text.y * frame.size.height);
      canvas.rotate(text.rotation);
      try {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: layout.size.width,
            height: layout.size.height,
          ),
          pen,
        );
      } finally {
        canvas.restore();
        if (layouts == null) layout.dispose();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SelectionPainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.stickerId != stickerId ||
      oldDelegate.photo != photo ||
      oldDelegate.textId != textId ||
      oldDelegate.layouts != layouts ||
      oldDelegate.draft != draft;
}
