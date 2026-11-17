import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'photobooth_catalog.dart';
import 'photobooth_session.dart';
import 'photobooth_text.dart';

class PhotoBoothPhotoTransform {
  const PhotoBoothPhotoTransform({this.x = .5, this.y = .5, this.zoom = 1});
  final double x;
  final double y;
  final double zoom;

  Rect sourceRect(Size source, Size slot) {
    final width =
        math.min(source.width, source.height * slot.aspectRatio) / zoom;
    final height = math.min(source.height, width / slot.aspectRatio);
    return Rect.fromLTWH(
      (x * source.width - width / 2).clamp(0, source.width - width),
      (y * source.height - height / 2).clamp(0, source.height - height),
      width,
      height,
    );
  }

  PhotoBoothPhotoTransform gesture(
    Size source,
    Size slot,
    Offset delta,
    double scale,
  ) {
    final rect = sourceRect(source, slot);
    final moved = PhotoBoothPhotoTransform(
      x: x - delta.dx * rect.width / source.width,
      y: y - delta.dy * rect.height / source.height,
      zoom: (zoom * scale).clamp(1, 5),
    );
    final bounded = moved.sourceRect(source, slot);
    return PhotoBoothPhotoTransform(
      x: bounded.center.dx / source.width,
      y: bounded.center.dy / source.height,
      zoom: moved.zoom,
    );
  }

  Map<String, Object> toJson() => {'x': x, 'y': y, 'zoom': zoom};
}

class PhotoBoothSticker {
  const PhotoBoothSticker({
    required this.id,
    required this.assetKey,
    this.x = .5,
    this.y = .5,
    this.width = .18,
    this.rotation = 0,
  });
  final int id;
  final String assetKey;
  final double x, y, width, rotation;

  Size extent(Size canvas, Size asset) =>
      Size(width * canvas.width, width * canvas.width / asset.aspectRatio);

  PhotoBoothSticker move(
    Size canvas,
    Size asset, {
    double? x,
    double? y,
    double? width,
    double? rotation,
  }) {
    final angle = rotation ?? this.rotation;
    final w = (width ?? this.width).clamp(
      .025,
      math.min(.65, canvas.height / canvas.width * asset.aspectRatio * .65),
    );
    final h = w * canvas.width / asset.aspectRatio;
    final dx = (angle.cosAbs * w + angle.sinAbs * h / canvas.width) / 2;
    final dy =
        (angle.sinAbs * w * canvas.width / canvas.height +
            angle.cosAbs * h / canvas.height) /
        2;
    return PhotoBoothSticker(
      id: id,
      assetKey: assetKey,
      x: (x ?? this.x).clamp(math.min(dx, .5), math.max(1 - dx, .5)),
      y: (y ?? this.y).clamp(math.min(dy, .5), math.max(1 - dy, .5)),
      width: w.toDouble(),
      rotation: angle,
    );
  }

  bool hit(Offset point, Size canvas, Size asset) {
    final local = point - Offset(x * canvas.width, y * canvas.height);
    final dx = local.dx * math.cos(rotation) + local.dy * math.sin(rotation);
    final dy = -local.dx * math.sin(rotation) + local.dy * math.cos(rotation);
    final size = extent(canvas, asset);
    return dx.abs() <= size.width / 2 && dy.abs() <= size.height / 2;
  }

  Map<String, Object> toJson() => {
    'id': id,
    'asset': assetKey,
    'x': x,
    'y': y,
    'width': width,
    'rotation': rotation,
  };
}

extension on double {
  double get cosAbs => math.cos(this).abs();
  double get sinAbs => math.sin(this).abs();
}

class PhotoBoothEdit {
  PhotoBoothEdit({
    required this.frameKey,
    Map<int, PhotoBoothPhotoTransform> photos = const {},
    List<PhotoBoothSticker> stickers = const [],
    List<PhotoBoothText> texts = const [],
    List<int>? homePhotos,
  }) : photos = Map.unmodifiable(photos),
       stickers = List.unmodifiable(stickers),
       texts = List.unmodifiable(texts),
       homePhotos = homePhotos == null ? null : List.unmodifiable(homePhotos);
  final String frameKey;
  final Map<int, PhotoBoothPhotoTransform> photos;
  final List<PhotoBoothSticker> stickers;
  final List<PhotoBoothText> texts;
  final List<int>? homePhotos;
  PhotoBoothEdit._(
    this.frameKey,
    this.photos,
    this.stickers,
    this.texts,
    this.homePhotos,
  );
  PhotoBoothEdit copy({
    String? frameKey,
    Map<int, PhotoBoothPhotoTransform>? photos,
    List<PhotoBoothSticker>? stickers,
    List<PhotoBoothText>? texts,
    List<int>? homePhotos,
    bool clearHomePhotos = false,
  }) => PhotoBoothEdit._(
    frameKey ?? this.frameKey,
    photos == null ? this.photos : Map.unmodifiable(photos),
    stickers == null ? this.stickers : List.unmodifiable(stickers),
    texts == null ? this.texts : List.unmodifiable(texts),
    clearHomePhotos
        ? null
        : homePhotos == null
        ? this.homePhotos
        : List.unmodifiable(homePhotos),
  );
  String get fingerprint => jsonEncode({
    'frame': frameKey,
    'homePhotos': homePhotos,
    'photos': photos.map((key, value) => MapEntry('$key', value.toJson())),
    'stickers': stickers.map((s) => s.toJson()).toList(),
    'texts': texts.map((text) => text.toJson()).toList(),
  });
}

class _UndoState {
  const _UndoState(this.draft, this.stripDraft, this.highlightPhotos);
  final PhotoBoothEdit draft;
  final PhotoBoothEdit? stripDraft;
  final List<int>? highlightPhotos;
}

/// Draft survives returning to the photo pool; originals are never modified.
class PhotoBoothEditorController extends ChangeNotifier {
  PhotoBoothEditorController(this.session)
    : draft = PhotoBoothEdit(
        frameKey: session.mode == PhotoBoothMode.four
            ? 'classic-600'
            : 'home-${session.mode.count}',
      ) {
    _saved = draft.fingerprint;
  }
  PhotoBoothSession session;
  PhotoBoothEdit draft;
  PhotoBoothEdit? _stripDraft;
  List<int>? _highlightPhotos;
  PhotoBoothEdit? get stripDraft => _stripDraft;
  String _saved = '';
  int _nextId = 0;
  int _nextTextId = 0;
  static const maxUndoSteps = 50;
  final _undoHistory = <_UndoState>[];
  _UndoState? _groupStart;
  int _groupDepth = 0;
  bool _groupRecorded = false;
  bool get canUndo => _undoHistory.isNotEmpty;
  PhotoBoothEdit? get undoDraft => _undoHistory.lastOrNull?.draft;

  _UndoState get _snapshot => _UndoState(draft, _stripDraft, _highlightPhotos);

  void _remember() {
    if (_groupDepth > 0) {
      if (_groupRecorded) return;
      _groupRecorded = true;
      _undoHistory.add(_groupStart!);
    } else {
      _undoHistory.add(_snapshot);
      if (_undoHistory.length > maxUndoSteps) _undoHistory.removeAt(0);
    }
  }

  /// Many live updates from one gesture/slider form one undo step.
  void beginUndoGroup() {
    if (_groupDepth++ == 0) {
      _groupStart = _snapshot;
      _groupRecorded = false;
    }
  }

  void endUndoGroup() {
    if (_groupDepth == 0 || --_groupDepth > 0) return;
    final start = _groupStart;
    _groupStart = null;
    if (_groupRecorded &&
        draft.fingerprint == start!.draft.fingerprint &&
        identical(_stripDraft, start.stripDraft) &&
        listEquals(_highlightPhotos, start.highlightPhotos)) {
      _undoHistory.removeLast();
      _groupRecorded = false;
      notifyListeners();
    }
    _groupRecorded = false;
    if (_undoHistory.length > maxUndoSteps) _undoHistory.removeAt(0);
  }

  bool undo() {
    while (_groupDepth > 0) {
      endUndoGroup();
    }
    if (!canUndo) return false;
    final previous = _undoHistory.removeLast();
    draft = previous.draft;
    _stripDraft = previous.stripDraft;
    _highlightPhotos = previous.highlightPhotos;
    notifyListeners();
    return true;
  }

  bool get home => draft.frameKey.startsWith('home-');
  List<int> get homePhotoIndices =>
      draft.homePhotos ?? List.generate(session.mode.count, (i) => i);
  PhotoBoothFrame resolveFrame(PhotoBoothCatalog catalog) => home
      ? PhotoBoothFrame.home(
          homePhotoIndices.length,
          photoIndices: homePhotoIndices,
        )
      : catalog.frame(draft.frameKey, session.mode.count);
  bool get dirty => draft.fingerprint != _saved;
  void markSaved() {
    _saved = draft.fingerprint;
    notifyListeners();
  }

  void updateSession(PhotoBoothSession value) {
    if (identical(session, value)) return;
    final oldPhotos = session.selectedPhotos;
    final newPhotos = value.selectedPhotos;
    final changed = <int>{};
    for (var i = 0; i < newPhotos.length; i++) {
      if (i >= oldPhotos.length || newPhotos[i].path != oldPhotos[i].path) {
        changed.add(i);
      }
    }
    final sameMode = session.mode == value.mode;
    if (!sameMode || changed.isNotEmpty) {
      _undoHistory.clear();
      _groupStart = null;
      _groupDepth = 0;
      _groupRecorded = false;
    }
    session = value;
    if (!sameMode) {
      draft = draft.copy(
        frameKey: value.mode == PhotoBoothMode.four
            ? 'classic-600'
            : 'home-${value.mode.count}',
        photos: {},
        clearHomePhotos: true,
      );
      _stripDraft = null;
      _highlightPhotos = null;
    } else if (changed.isNotEmpty) {
      draft = draft.copy(
        photos: {...draft.photos}
          ..removeWhere((key, _) => changed.contains(key)),
      );
      if (_stripDraft != null) {
        _stripDraft = _stripDraft!.copy(
          photos: {..._stripDraft!.photos}
            ..removeWhere((key, _) => changed.contains(key)),
        );
      }
    }
  }

  void setFrame(
    PhotoBoothFrame frame,
    PhotoBoothCatalog catalog, {
    bool recordHistory = true,
  }) {
    final next = draft.copy(
      frameKey: frame.key,
      clearHomePhotos: !frame.key.startsWith('home-'),
      stickers: [
        for (final sticker in draft.stickers)
          sticker.move(frame.size, catalog.sticker(sticker.assetKey).size),
      ],
      texts: [for (final text in draft.texts) text.move(frame.size)],
    );
    if (next.fingerprint == draft.fingerprint) return;
    if (recordHistory) _remember();
    draft = next;
    notifyListeners();
  }

  void setPhoto(int index, PhotoBoothPhotoTransform photo) {
    final previous = draft.photos[index] ?? const PhotoBoothPhotoTransform();
    if (previous.x == photo.x &&
        previous.y == photo.y &&
        previous.zoom == photo.zoom) {
      return;
    }
    _remember();
    final photos = {...draft.photos};
    if (photo.x == .5 && photo.y == .5 && photo.zoom == 1) {
      photos.remove(index);
    } else {
      photos[index] = photo;
    }
    draft = draft.copy(photos: photos);
    notifyListeners();
  }

  bool addSticker(PhotoBoothStickerAsset asset, PhotoBoothFrame frame) {
    if (draft.stickers.length >= 8) return false;
    _remember();
    final sticker = PhotoBoothSticker(id: _nextId++, assetKey: asset.key).move(
      frame.size,
      asset.size,
      width: math.min(
        .18,
        frame.size.height / frame.size.width * asset.size.aspectRatio * .25,
      ),
    );
    draft = draft.copy(stickers: [...draft.stickers, sticker]);
    notifyListeners();
    return true;
  }

  void changeSticker(PhotoBoothSticker sticker) {
    final previous = draft.stickers
        .where((value) => value.id == sticker.id)
        .firstOrNull;
    if (previous == null ||
        (previous.x == sticker.x &&
            previous.y == sticker.y &&
            previous.width == sticker.width &&
            previous.rotation == sticker.rotation)) {
      return;
    }
    _remember();
    draft = draft.copy(
      stickers: [
        for (final value in draft.stickers)
          if (value.id == sticker.id) sticker else value,
      ],
    );
    notifyListeners();
  }

  void removeSticker(int id) {
    if (!draft.stickers.any((sticker) => sticker.id == id)) return;
    _remember();
    draft = draft.copy(
      stickers: draft.stickers.where((s) => s.id != id).toList(),
    );
    notifyListeners();
  }

  void raiseSticker(int id) {
    final selected = draft.stickers.where((s) => s.id == id).firstOrNull;
    if (selected == null || draft.stickers.last.id == id) return;
    _remember();
    draft = draft.copy(
      stickers: [...draft.stickers.where((s) => s.id != id), selected],
    );
    notifyListeners();
  }

  void prepareHome(PhotoBoothCatalog catalog) {
    if (home) return;
    _remember();
    _stripDraft = draft;
    final frame = PhotoBoothFrame.home(session.mode.count);
    draft = PhotoBoothEdit(
      frameKey: frame.key,
      homePhotos: List.generate(session.mode.count, (i) => i),
      texts: [for (final text in _stripDraft!.texts) text.move(frame.size)],
      stickers: [
        for (var i = 0; i < _stripDraft!.stickers.length; i++)
          _stripDraft!.stickers[i].move(
            frame.size,
            catalog.sticker(_stripDraft!.stickers[i].assetKey).size,
            x: i % 2 == 0 ? .1 : .9,
            y: (i ~/ 2 + 1) / 5,
            width: .12,
            rotation: 0,
          ),
      ],
    );
    notifyListeners();
  }

  void restoreStrip() {
    if (_stripDraft == null) return;
    _remember();
    draft = _stripDraft!;
    _stripDraft = null;
    notifyListeners();
  }

  void setHomeLayout(int count) {
    if (!home || (count != 2 && count != 4) || count > session.mode.count) {
      return;
    }
    if (homePhotoIndices.length == count) return;
    _remember();
    draft = draft.copy(
      frameKey: 'home-$count',
      homePhotos: count == 4
          ? List.generate(4, (i) => i)
          : _highlightPhotos ?? homePhotoIndices.take(2).toList(),
    );
    notifyListeners();
  }

  void chooseHomePhoto(int slot, int photo) {
    if (!home ||
        homePhotoIndices.length != 2 ||
        slot < 0 ||
        slot >= 2 ||
        photo < 0 ||
        photo >= session.selectedPhotos.length) {
      return;
    }
    final selection = [...homePhotoIndices];
    if (selection[slot] == photo) return;
    _remember();
    final previousSlot = selection.indexOf(photo);
    if (previousSlot >= 0) selection[previousSlot] = selection[slot];
    selection[slot] = photo;
    _highlightPhotos = List.unmodifiable(selection);
    draft = draft.copy(homePhotos: selection);
    notifyListeners();
  }

  PhotoBoothText? addText(
    String value,
    PhotoBoothFrame frame, {
    int color = 0xFFFFFFFF,
    int backgroundColor = 0,
    double fontSize = .07,
  }) {
    final content = value.trim();
    if (content.isEmpty || draft.texts.length >= 8) return null;
    _remember();
    final text = PhotoBoothText(
      id: _nextTextId++,
      text: content,
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
    ).move(frame.size);
    draft = draft.copy(texts: [...draft.texts, text]);
    notifyListeners();
    return text;
  }

  void changeText(PhotoBoothText text) {
    final previous = draft.texts
        .where((value) => value.id == text.id)
        .firstOrNull;
    if (previous == null ||
        (previous.text == text.text &&
            previous.color == text.color &&
            previous.backgroundColor == text.backgroundColor &&
            previous.fontSize == text.fontSize &&
            previous.x == text.x &&
            previous.y == text.y &&
            previous.rotation == text.rotation)) {
      return;
    }
    _remember();
    draft = draft.copy(
      texts: [
        for (final value in draft.texts)
          if (value.id == text.id) text else value,
      ],
    );
    notifyListeners();
  }

  void raiseText(int id) {
    final index = draft.texts.indexWhere((text) => text.id == id);
    if (index < 0 || index == draft.texts.length - 1) return;
    _remember();
    final selected = draft.texts[index];
    draft = draft.copy(
      texts: [...draft.texts.where((text) => text.id != id), selected],
    );
    notifyListeners();
  }

  void removeText(int id) {
    if (!draft.texts.any((text) => text.id == id)) return;
    _remember();
    draft = draft.copy(
      texts: draft.texts.where((text) => text.id != id).toList(),
    );
    notifyListeners();
  }
}
