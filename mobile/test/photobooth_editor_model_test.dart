import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/photobooth/photobooth_catalog.dart';
import 'package:track_children/features/photobooth/photobooth_edit.dart';
import 'package:track_children/features/photobooth/photobooth_session.dart';

PhotoBoothSession editorSession({int count = 4}) {
  final session = PhotoBoothSession.create(
    accountId: 'account',
    childId: 'child',
    mode: PhotoBoothMode.values.firstWhere((mode) => mode.count == count),
  );
  return session
      .withShots(
        List.generate(
          6,
          (index) => LocalPhoto(
            path: 'photo-$index.jpg',
            width: 1200,
            height: 1600,
            capturedAt: DateTime(2026),
            frontCamera: true,
          ),
        ),
      )
      .withSelection(List.generate(count, (index) => index));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PhotoBoothCatalog catalog;
  setUpAll(() async {
    catalog = await PhotoBoothCatalog.load();
  });

  test('frame dimensions use colons without changing asset formats', () {
    expect(catalog.frame('classic-600', 4).formatLabel, '2:6');
    expect(catalog.frame('classic-1200', 4).formatLabel, '4:6');
    final square = catalog.frame('birthday-kids-5x5-01', 1);
    expect(square.formatLabel, '5:5');
    expect(square.format, isNot(contains(':')));
    expect(PhotoBoothFrame.home(2).formatLabel, '3:2');
    for (final frame in catalog.frames) {
      expect(frame.formatLabel, contains(':'));
      expect(frame.formatLabel, isNot(matches(r'[x×]')));
    }
  });

  test('catalog has all measured frames and only transparent PNG stickers', () {
    expect(catalog.frames, hasLength(92));
    expect(catalog.frames.map((frame) => frame.key).toSet(), hasLength(92));
    expect(catalog.frames.first.key, 'classic-600');
    final transparentAssets = <String>{};
    for (final file in Directory(
      'assets/photobooth/stickers',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.png')) continue;
      final handle = file.openSync();
      final header = handle.readSync(26);
      handle.closeSync();
      if (header[25] == 4 || header[25] == 6) {
        transparentAssets.add(file.path.replaceAll('\\', '/'));
      }
    }
    expect(
      catalog.stickers.map((sticker) => sticker.asset).toSet(),
      transparentAssets,
    );
    expect(
      catalog.stickers.map((sticker) => sticker.key).toSet(),
      hasLength(catalog.stickers.length),
    );
    expect(catalog.stickers.any((s) => s.key == 'animals/bunny'), isFalse);
    for (final frame in catalog.frames) {
      expect(frame.photoCount, inInclusiveRange(1, 4));
      expect(
        frame.slots.map((slot) => slot.photo).toSet(),
        List.generate(frame.photoCount, (index) => index).toSet(),
      );
      for (final slot in frame.slots) {
        expect((Offset.zero & frame.size).contains(slot.rect.topLeft), isTrue);
        expect(slot.rect.right, lessThanOrEqualTo(frame.size.width));
        expect(slot.rect.bottom, lessThanOrEqualTo(frame.size.height));
      }
    }
  });

  test('Belonkhon contains six landscape frames and 45 distinct stickers', () {
    final frames = catalog.frames.where((frame) => frame.theme == 'belonkhon');
    expect(frames, hasLength(6));
    for (final count in [1, 2]) {
      expect(frames.where((frame) => frame.photoCount == count), hasLength(3));
    }
    for (final frame in frames) {
      expect(frame.size, const Size(1800, 1200));
      expect(frame.formatLabel, '6:4');
      expect(frame.categoryLabel, 'Bé Lớn Khôn');
      expect(frame.shapeKey, 'landscape');
      if (frame.photoCount == 2) {
        expect(frame.slots[0].photo, 0);
        expect(frame.slots[1].photo, 1);
        expect(
          frame.slots[0].rect.center.dx,
          lessThan(frame.slots[1].rect.center.dx),
        );
      }
    }
    expect(
      catalog.stickers.where((s) => s.group == 'belonkhon'),
      hasLength(45),
    );
    expect(
      catalog.sticker('belonkhon/mascot/milk_bottle').asset,
      isNot(catalog.sticker('belonkhon/care/milk_bottle').asset),
    );
  });

  test('undo restores each edit, including deleted captions and stickers', () {
    final editor = PhotoBoothEditorController(editorSession());
    final states = [editor.draft.fingerprint];
    void change(VoidCallback action) {
      action();
      expect(editor.draft.fingerprint, isNot(states.last));
      states.add(editor.draft.fingerprint);
    }

    final frame = catalog.frame('film-1200', 4);
    change(() => editor.setFrame(frame, catalog));
    change(() => editor.setPhoto(0, const PhotoBoothPhotoTransform(zoom: 2)));
    final asset = catalog.stickers.first;
    change(() => editor.addSticker(asset, frame));
    final first = editor.draft.stickers.single;
    change(() => editor.addSticker(asset, frame));
    change(
      () => editor.changeSticker(
        first.move(frame.size, asset.size, x: .3, rotation: .4),
      ),
    );
    change(() => editor.raiseSticker(first.id));
    change(() => editor.removeSticker(first.id));
    change(() => editor.addText('Bé yêu', frame));
    final text = editor.draft.texts.single;
    change(() => editor.addText('Gia đình', frame));
    change(
      () => editor.changeText(
        text
            .copy(
              text: 'Kỷ niệm',
              color: 0xFFE96392,
              backgroundColor: 0xFF23332E,
              fontSize: .09,
            )
            .move(frame.size, x: .3, rotation: .2),
      ),
    );
    change(() => editor.raiseText(text.id));
    change(() => editor.removeText(text.id));
    for (final state in states.reversed.skip(1)) {
      expect(editor.undo(), isTrue);
      expect(editor.draft.fingerprint, state);
    }
    expect(editor.canUndo, isFalse);
    expect(editor.undo(), isFalse);
    expect(editor.dirty, isFalse);
    editor.dispose();
  });

  test(
    'continuous and nested edits undo once; unchanged actions add no history',
    () {
      final editor = PhotoBoothEditorController(editorSession(count: 2));
      final initial = editor.draft.fingerprint;
      editor.beginUndoGroup();
      for (var i = 1; i <= 100; i++) {
        editor.setPhoto(0, PhotoBoothPhotoTransform(zoom: 1 + i / 100));
      }
      editor.endUndoGroup();
      expect(editor.undo(), isTrue);
      expect(editor.draft.fingerprint, initial);
      expect(editor.canUndo, isFalse);
      editor.beginUndoGroup();
      editor.setPhoto(0, const PhotoBoothPhotoTransform(zoom: 2));
      editor.setPhoto(0, const PhotoBoothPhotoTransform());
      editor.endUndoGroup();
      expect(editor.canUndo, isFalse);
      editor.setFrame(PhotoBoothFrame.home(2), catalog);
      editor.removeText(99);
      editor.removeSticker(99);
      expect(editor.canUndo, isFalse);
      editor.beginUndoGroup();
      editor.beginUndoGroup();
      final text = editor.addText('Bé yêu', PhotoBoothFrame.home(2))!;
      editor.endUndoGroup();
      editor.changeText(text.copy(color: 0xFFE96392));
      editor.endUndoGroup();
      editor.raiseText(text.id);
      expect(editor.undo(), isTrue);
      expect(editor.draft.fingerprint, initial);
      expect(editor.canUndo, isFalse);
      final next = editor.addText('Mới', PhotoBoothFrame.home(2))!;
      expect(next.id, greaterThan(text.id));
      editor.markSaved();
      editor.changeText(next.copy(color: 0xFF23332E));
      expect(editor.dirty, isTrue);
      editor.undo();
      expect(editor.dirty, isFalse);
      editor.dispose();
    },
  );

  test('undo history is bounded and clears when selected originals change', () {
    final editor = PhotoBoothEditorController(editorSession());
    for (var i = 0; i < PhotoBoothEditorController.maxUndoSteps + 10; i++) {
      editor.setPhoto(0, PhotoBoothPhotoTransform(zoom: 2 + i / 100));
    }
    var count = 0;
    while (editor.undo()) {
      count++;
    }
    expect(count, PhotoBoothEditorController.maxUndoSteps);
    expect(editor.draft.photos[0]!.zoom, closeTo(2.09, 1e-9));
    editor.setPhoto(0, const PhotoBoothPhotoTransform(zoom: 3));
    editor.updateSession(editor.session.withSelection([0, 1, 2, 3]));
    expect(editor.canUndo, isTrue);
    editor.updateSession(editor.session.withSelection([1, 0, 2, 3]));
    expect(editor.canUndo, isFalse);
    expect(editor.draft.photos, isEmpty);
    editor.dispose();
  });

  test('undo restores independent Home and strip drafts and highlighted photo order', () {
    final editor = PhotoBoothEditorController(editorSession());
    editor.addText('Bé yêu', catalog.frames.first);
    final strip = editor.draft;
    editor.prepareHome(catalog);
    editor.setHomeLayout(2);
    editor.chooseHomePhoto(0, 2);
    final highlights = editor.draft;
    editor.setHomeLayout(4);
    editor.undo();
    expect(editor.draft, same(highlights));
    editor.restoreStrip();
    editor.undo();
    expect(editor.draft, same(highlights));
    expect(editor.stripDraft, same(strip));
    editor.undo();
    expect(editor.homePhotoIndices, [0, 1]);
    editor.undo();
    expect(editor.homePhotoIndices, [0, 1, 2, 3]);
    editor.undo();
    expect(editor.draft, same(strip));
    expect(editor.stripDraft, isNull);
    editor.dispose();
  });

  test(
    'cover/pan/zoom always stays inside source and preserves slot aspect',
    () {
      for (final source in const [
        Size(1600, 1200),
        Size(1200, 1600),
        Size(200, 4000),
      ]) {
        for (final slot in const [
          Size(504, 382),
          Size(688, 912),
          Size(688, 448),
        ]) {
          var transform = const PhotoBoothPhotoTransform();
          for (final delta in const [
            Offset(5, -5),
            Offset(-10, 10),
            Offset(.2, -.3),
          ]) {
            for (final scale in [.01, 2.0, 100.0]) {
              transform = transform.gesture(source, slot, delta, scale);
              final rect = transform.sourceRect(source, slot);
              expect(rect.left, greaterThanOrEqualTo(-1e-8));
              expect(rect.top, greaterThanOrEqualTo(-1e-8));
              expect(rect.right, lessThanOrEqualTo(source.width + 1e-8));
              expect(rect.bottom, lessThanOrEqualTo(source.height + 1e-8));
              expect(rect.width / rect.height, closeTo(slot.aspectRatio, 1e-8));
              expect(transform.zoom, inInclusiveRange(1, 5));
            }
          }
        }
      }
    },
  );

  test('sticker count, rotation/hit testing, z order and frame changes retain edits', () {
    final controller = PhotoBoothEditorController(editorSession());
    final frame = catalog.frame(controller.draft.frameKey, 4);
    final asset = catalog.stickers.first;
    for (var i = 0; i < 8; i++) {
      expect(controller.addSticker(asset, frame), isTrue);
    }
    expect(controller.addSticker(asset, frame), isFalse);
    final first = controller.draft.stickers.first;
    final rotated = first.move(
      frame.size,
      asset.size,
      x: .2,
      y: .3,
      rotation: math.pi / 3,
      width: .22,
    );
    expect(
      rotated.hit(
        Offset(rotated.x * frame.size.width, rotated.y * frame.size.height),
        frame.size,
        asset.size,
      ),
      isTrue,
    );
    controller.changeSticker(rotated);
    controller.raiseSticker(first.id);
    expect(controller.draft.stickers.last.id, first.id);
    controller.setPhoto(
      1,
      const PhotoBoothPhotoTransform(x: .4, y: .6, zoom: 2),
    );
    controller.setFrame(catalog.frame('birthday-1200', 4), catalog);
    expect(controller.draft.stickers, hasLength(8));
    expect(controller.draft.photos[1]!.zoom, 2);
    controller.removeSticker(first.id);
    expect(controller.draft.stickers, hasLength(7));
    expect(controller.session.shots, hasLength(6));
    controller.dispose();
  });

  test('Home has an independent landscape draft; strip restores unchanged', () {
    final controller = PhotoBoothEditorController(editorSession());
    final frame = catalog.frame(controller.draft.frameKey, 4);
    controller.addSticker(catalog.stickers.first, frame);
    controller.setPhoto(0, const PhotoBoothPhotoTransform(zoom: 3));
    final strip = controller.draft.fingerprint;
    controller.prepareHome(catalog);
    expect(controller.draft.frameKey, 'home-4');
    expect(controller.draft.photos, isEmpty);
    expect(controller.draft.stickers, hasLength(1));
    expect(controller.draft.stickers.first.x, isNot(.5));
    controller.setPhoto(0, const PhotoBoothPhotoTransform(zoom: 1.5));
    controller.restoreStrip();
    expect(controller.draft.fingerprint, strip);
    controller.dispose();
  });

  test('returning from pool retains decorations and resets only changed photo crops', () {
    final session = editorSession();
    final controller = PhotoBoothEditorController(session);
    controller.addSticker(catalog.stickers.first, catalog.frames.first);
    controller.setPhoto(0, const PhotoBoothPhotoTransform(zoom: 2));
    controller.setPhoto(1, const PhotoBoothPhotoTransform(zoom: 3));
    controller.updateSession(session.withSelection([4, 1, 2, 3]));
    expect(controller.draft.photos[0], isNull);
    expect(controller.draft.photos[1]!.zoom, 3);
    expect(controller.draft.stickers, hasLength(1));
    expect(controller.dirty, isTrue);
    controller.markSaved();
    expect(controller.dirty, isFalse);
    controller.dispose();
  });
  test(
    'Home can reorder two highlights without changing the strip session',
    () {
      final controller = PhotoBoothEditorController(editorSession());
      final originalSession = controller.session;
      final originalStrip = controller.draft.fingerprint;
      controller.prepareHome(catalog);
      expect(controller.homePhotoIndices, [0, 1, 2, 3]);
      controller.setHomeLayout(2);
      controller.chooseHomePhoto(0, 3);
      controller.chooseHomePhoto(1, 1);
      expect(controller.homePhotoIndices, [3, 1]);
      expect(controller.resolveFrame(catalog).slots.map((s) => s.photo), [
        3,
        1,
      ]);
      final fingerprint = controller.draft.fingerprint;
      controller.chooseHomePhoto(0, 1);
      expect(controller.homePhotoIndices, [1, 3]);
      expect(controller.draft.fingerprint, isNot(fingerprint));
      controller.setHomeLayout(4);
      controller.setHomeLayout(2);
      expect(controller.homePhotoIndices, [1, 3]);
      expect(controller.session, same(originalSession));
      expect(controller.session.selectedPhotos, hasLength(4));
      controller.restoreStrip();
      expect(controller.draft.fingerprint, originalStrip);
      controller.dispose();
    },
  );

  test(
    'print sheets repeat source photos and never require extra originals',
    () {
      for (final theme in [
        'birthday-kids',
        'christmas-starlight',
        'christmas-sweater',
        'christmas-merry',
        'halloween-kids',
      ]) {
        final mixedThree = catalog.frame('$theme-4x6-02', 3);
        expect(mixedThree.key, '$theme-4x6-02');
        expect(mixedThree.slots.map((s) => s.photo), [0, 1, 0, 1, 2]);
        final mixedFour = catalog.frame('$theme-4x6-03', 4);
        expect(mixedFour.key, '$theme-4x6-03');
        expect(mixedFour.slots.map((s) => s.photo), [0, 1, 2, 0, 1, 2, 3]);
        final landscape = catalog.frame('$theme-6x4-03', 3);
        expect(landscape.key, '$theme-6x4-03');
        expect(landscape.slots.map((s) => s.photo), [0, 1, 2, 0, 1, 2]);
      }
    },
  );

  for (final count in [1, 3]) {
    test(
      '$count photos support a matching frame and independent Home canvas',
      () {
        final editor = PhotoBoothEditorController(editorSession(count: count));
        final initial = editor.resolveFrame(catalog);
        expect(initial.photoCount, count);
        expect(initial.size, const Size(1440, 960));
        if (count == 3) {
          expect(initial.slots.map((slot) => slot.rect.top).toSet(), {24.0});
          for (final slot in initial.slots) {
            expect(
              slot.rect.width,
              closeTo(initial.slots.first.rect.width, 1e-8),
            );
          }
        }
        final frame = catalog.frames.firstWhere(
          (frame) => frame.photoCount == count,
        );
        editor.setFrame(frame, catalog);
        editor.setPhoto(0, const PhotoBoothPhotoTransform(zoom: 2));
        final before = editor.draft.fingerprint;
        editor.prepareHome(catalog);
        expect(editor.resolveFrame(catalog).photoCount, count);
        expect(
          editor.resolveFrame(catalog).slots.map((s) => s.photo),
          List.generate(count, (i) => i),
        );
        editor.restoreStrip();
        expect(editor.draft.fingerprint, before);
        editor.updateSession(editorSession(count: count == 1 ? 3 : 1));
        expect(editor.resolveFrame(catalog).photoCount, count == 1 ? 3 : 1);
        expect(editor.draft.homePhotos, isNull);
        editor.dispose();
      },
    );
  }
}
