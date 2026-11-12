import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/photobooth/photobooth_catalog.dart';
import 'package:track_children/features/photobooth/photobooth_edit.dart';
import 'package:track_children/features/photobooth/photobooth_session.dart';

PhotoBoothSession editorSession({int count = 4}) {
  final session = PhotoBoothSession.create(
    accountId: 'account',
    childId: 'child',
    mode: count == 4 ? PhotoBoothMode.four : PhotoBoothMode.two,
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

  test('catalog has ten measured frames and only transparent PNG stickers', () {
    expect(catalog.frames, hasLength(10));
    expect(catalog.stickers, hasLength(77));
    expect(catalog.stickers.where((s) => s.group == 'birthday'), hasLength(11));
    expect(
      catalog.stickers.where((s) => s.group == 'halloween'),
      hasLength(20),
    );
    expect(catalog.stickers.any((s) => s.key == 'animals/bunny'), isFalse);
    for (final frame in catalog.frames) {
      final copies = frame.size.width == 600 ? 1 : 2;
      expect(frame.slots, hasLength(4 * copies));
      for (var photo = 0; photo < 4; photo++) {
        expect(frame.slots.where((s) => s.photo == photo), hasLength(copies));
      }
    }
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
}
