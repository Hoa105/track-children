import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

import 'photobooth_catalog.dart';
import 'photobooth_edit.dart';
import 'photobooth_export.dart';
import 'photobooth_renderer.dart';
import 'photobooth_session.dart';

typedef PhotoBoothEditorBuilder = Widget Function(
  BuildContext context,
  PhotoBoothSession session,
  VoidCallback onBack,
);

class PhotoBoothEditorEntry extends StatefulWidget {
  const PhotoBoothEditorEntry({
    required this.session,
    required this.onBack,
    this.controller,
    this.catalog,
    this.onUseHome,
    this.onChooseFour,
    this.exporter = const PhotoBoothExporter(),
    this.gallery = const PhotoBoothGallery(),
    super.key,
  });
  final PhotoBoothSession session;
  final VoidCallback onBack;
  final VoidCallback? onChooseFour;
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
  int _tab = 0, _generation = 0;
  String _group = 'animals';
  String? _frameCategory;
  final _previewFraction = ValueNotifier(.60);
  final _photoPaints = ValueNotifier(0);
  final _stickerPaints = ValueNotifier(0);
  final _selectionPaints = ValueNotifier(0);
  late PhotoBoothEdit _observedDraft;
  PhotoBoothFrame? _resolvedFrame;
  String? _resolvedFrameKey;
  List<int>? _resolvedHomePhotos;
  int _homeSlot = 0;
  int? _sticker, _photo;
  PhotoBoothSticker? _gestureSticker;
  PhotoBoothPhotoTransform? _gesturePhoto;
  PhotoBoothSlot? _gestureSlot;
  Offset _gestureOrigin = Offset.zero;
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
    editor.addListener(_changed);
    unawaited(_load());
  }

  void _changed() {
    final previous = _observedDraft;
    final current = _observedDraft = editor.draft;
    final frameChanged =
        previous.frameKey != current.frameKey ||
        !identical(previous.homePhotos, current.homePhotos);
    final structureChanged =
        frameChanged || previous.stickers.length != current.stickers.length;
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
      editor.setFrame(frame, catalog);
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

  Future<void> _frameSelected(PhotoBoothFrame frame) {
    if (editor.draft.frameKey == frame.key) return Future.value();
    return _assetAction(() async {
      if (frame.asset != null) await _images.loadAsset(frame.asset!);
      if (!mounted) return;
      editor.setFrame(frame, _catalog!);
      _sticker = null;
      _photo = null;
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
        }
      });

  Future<bool> requestLeave() async {
    if (_busy) return false;
    if (!editor.dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            _dialog = ModalRoute.of(context);
            return AlertDialog(
              title: const Text('Chỉnh sửa chưa xuất'),
              content: const Text(
                'Bạn muốn quay lại bộ ảnh? Bản nháp trang trí vẫn được giữ trong phiên này.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Ở lại'),
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
    final point = Offset(
      details.localFocalPoint.dx * _frame.size.width / preview.width,
      details.localFocalPoint.dy * _frame.size.height / preview.height,
    );
    _select(point);
    _gestureOrigin = point;
    _gestureSticker = editor.draft.stickers
        .where((s) => s.id == _sticker)
        .firstOrNull;
    _gestureSlot = _frame.slots
        .where((slot) => slot.photo == _photo && slot.rect.contains(point))
        .firstOrNull;
    _gesturePhoto = _photo == null
        ? null
        : editor.draft.photos[_photo] ?? const PhotoBoothPhotoTransform();
  }

  void _updateGesture(ScaleUpdateDetails details, Size preview) {
    final point = Offset(
      details.localFocalPoint.dx * _frame.size.width / preview.width,
      details.localFocalPoint.dy * _frame.size.height / preview.height,
    );
    final delta = point - _gestureOrigin;
    if (_gestureSticker != null) {
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

  Future<void> _finish() async {
    if (_busy || _catalog == null) return;
    setState(() {
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
      setState(() {
        _completed = true;
        _sticker = null;
        _photo = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Chưa xuất được ảnh. Bộ ảnh và chỉnh sửa vẫn được giữ, bạn hãy thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveGallery() async {
    if (_output == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
      _settings = false;
    });
    try {
      await widget.gallery.save(_output!);
      if (mounted) {
        setState(() => _notice = 'Đã lưu ảnh vào thư viện của thiết bị.');
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
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useHome() async {
    if (_busy || _catalog == null) return;
    if (!editor.home) {
      editor.prepareHome(_catalog!);
      setState(() {
        _completed = false;
        _notice = 'Căn ảnh và sticker trên bố cục ngang, rồi bấm Hoàn tất.';
      });
      return;
    }
    if (_output == null || widget.onUseHome == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.onUseHome!(_output!);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Chưa áp dụng được ảnh nền. Ảnh cũ và bộ ảnh vẫn được giữ, bạn hãy thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _largePreview() {
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
    final dialog = _dialog;
    if (dialog != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (dialog.isActive) dialog.navigator?.removeRoute(dialog);
      });
    }
    editor.removeListener(_changed);
    _previewFraction.dispose();
    _photoPaints.dispose();
    _stickerPaints.dispose();
    _selectionPaints.dispose();
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
                child: const Text('Quay lại bộ ảnh'),
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
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _error ?? _notice!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: _error == null
                      ? null
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ),
        if (_settings)
          TextButton(
            onPressed: () async {
              try {
                await permissions.openAppSettings();
              } catch (_) {
                /* Keep message visible. */
              }
            },
            child: const Text('Mở Cài đặt'),
          ),
        Expanded(
          child: _completed
              ? Column(
                  children: [
                    Expanded(child: _preview()),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton(
                            onPressed: _busy ? null : _saveGallery,
                            child: const Text('Lưu về máy'),
                          ),
                          OutlinedButton(
                            onPressed: _busy || widget.onUseHome == null
                                ? null
                                : _useHome,
                            child: const Text('Dùng làm nền Home'),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() => _completed = false),
                            child: const Text('Tiếp tục chỉnh sửa'),
                          ),
                          TextButton(
                            onPressed: _busy ? null : () => _leave(),
                            child: const Text('Quay lại bộ ảnh'),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : _workspace(),
        ),
      ],
    );
  }

  Widget _workspace() => LayoutBuilder(
    builder: (context, constraints) {
      final usable = math.max(0.0, constraints.maxHeight - 68);
      final minimum = math.min(144.0, usable * .4);
      void resize(double delta) {
        if (usable > 0) {
          _previewFraction.value = (_previewFraction.value + delta / usable)
              .clamp(0.0, 1.0);
        }
      }

      final preview = _preview();
      final toolbar = _editorToolbar();
      final library = RepaintBoundary(
        child: Material(
          key: const ValueKey('photobooth-library-panel'),
          color: Theme.of(context).colorScheme.surface,
          child: _tab == 0 ? _framesPanel() : _stickersPanel(),
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
                            color: Theme.of(context).colorScheme.outlineVariant,
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
            tooltip: 'Quay lại bộ ảnh',
            onPressed: _busy ? null : () => _leave(),
            icon: const Icon(Icons.arrow_back_rounded),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 48),
            padding: const EdgeInsets.all(10),
          ),
          for (var tab = 0; tab < 2; tab++)
            Expanded(
              child: Semantics(
                selected: _tab == tab,
                child: TextButton(
                  onPressed: _busy ? null : () => setState(() => _tab = tab),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: _tab == tab
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 13,
                      fontWeight: _tab == tab
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                  child: Text(tab == 0 ? 'Khung' : 'Sticker'),
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

  void _setSelection(int? sticker, int? photo) {
    if (_sticker == sticker && _photo == photo) return;
    setState(() {
      _sticker = sticker;
      _photo = photo;
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
                return GestureDetector(
                  key: const ValueKey('photobooth-editor-canvas'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: _busy || _completed
                      ? null
                      : (details) => _select(
                          Offset(
                            details.localPosition.dx *
                                _frame.size.width /
                                size.width,
                            details.localPosition.dy *
                                _frame.size.height /
                                size.height,
                          ),
                        ),
                  onScaleStart: _busy || _completed
                      ? null
                      : (details) => _startGesture(details, size),
                  onScaleUpdate: _busy || _completed
                      ? null
                      : (details) => _updateGesture(details, size),
                  child: _canvasLayers(),
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
        if (!_completed && (_sticker != null || _photo != null))
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              color: Theme.of(context).colorScheme.surface
                  .withValues(alpha: .94),
              elevation: 1,
              borderRadius: BorderRadius.circular(12),
              child: ListenableBuilder(
                listenable: editor,
                builder: (_, _) => _selectionControls(),
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
              liveEditor: editor,
              repaint: _selectionPaints,
            ),
          ),
        ),
    ],
  );

  Widget _selectionControls() {
    final sticker = editor.draft.stickers
        .where((s) => s.id == _sticker)
        .firstOrNull;
    if (sticker != null) {
      void adjust({double scale = 1, double angle = 0}) => editor.changeSticker(
        sticker.move(
          _frame.size,
          _catalog!.sticker(sticker.assetKey).size,
          width: sticker.width * scale,
          rotation: sticker.rotation + angle,
        ),
      );
      return SizedBox(
        height: 48,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                onChanged: _busy
                    ? null
                    : (zoom) => editor.setPhoto(
                        _photo!,
                        PhotoBoothPhotoTransform(
                          x: photo.x,
                          y: photo.y,
                          zoom: zoom,
                        ),
                      ),
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
    return const SizedBox.shrink();
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
      if (widget.session.mode == PhotoBoothMode.two) PhotoBoothFrame.home(2),
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
    final visible = frames
        .where(
          (frame) => activeCategory == null || frame.theme == activeCategory,
        )
        .toList();
    return Column(
      children: [
        if (categories.length > 1)
          SizedBox(
            height: 44,
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
                          : (_) =>
                                setState(() => _frameCategory = category.key),
                    ),
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
        if (widget.session.mode == PhotoBoothMode.two &&
            widget.onChooseFour != null)
          TextButton(
            onPressed: _busy ? null : () => _leave(four: true),
            child: const Text(
              'Chọn 4 ảnh cho photostrip',
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
                    maxLines: 1,
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
    this.liveEditor,
    super.repaint,
  });
  final PhotoBoothFrame frame;
  final PhotoBoothEdit draft;
  final PhotoBoothCatalog catalog;
  final int? stickerId, photo;
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
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SelectionPainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.stickerId != stickerId ||
      oldDelegate.photo != photo ||
      oldDelegate.draft != draft;
}
