import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/home/background/background_config.dart';
import 'package:track_children/features/home/background/background_crop_state.dart';
import 'package:track_children/features/home/background/background_draft.dart';
import 'package:track_children/features/home/background/background_files.dart';
import 'package:track_children/features/home/background/background_image_service.dart';
import 'package:track_children/features/home/background/home_background_repository.dart';
import 'package:track_children/features/photobooth/photobooth_catalog.dart';
import 'package:track_children/features/photobooth/photobooth_edit.dart';
import 'package:track_children/features/photobooth/photobooth_export.dart';
import 'package:track_children/features/photobooth/photobooth_files.dart';
import 'package:track_children/features/photobooth/photobooth_renderer.dart';
import 'package:track_children/features/photobooth/photobooth_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const colors = [Colors.red, Colors.green, Colors.blue, Colors.yellow];
  late Directory root;
  late PhotoBoothCatalog catalog;
  setUpAll(() async {
    await (FontLoader('Nunito')
          ..addFont(rootBundle.load('assets/fonts/nunito/Nunito-Variable.ttf')))
        .load();
    await Directory('build/prompt05_integration').create(recursive: true);
    root = await Directory('build/prompt05_integration').createTemp('run_');
    catalog = await PhotoBoothCatalog.load();
    for (var i = 0; i < colors.length; i++) {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(colors[i], BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(640, 960);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('${root.path}/source-$i.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
        picture.dispose();
      }
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final specimen in const [
    ('film-600', 4),
    ('belonkhon-organic-1photo', 1),
    ('belonkhon-scrapbook-2photo', 2),
    ('classic-1200', 4),
    ('birthday-kids-5x5-01', 1),
    ('birthday-kids-6x4-03', 3),
  ]) {
    test(
      '${specimen.$1}: frame, text and sticker survive fitting, Apply and reload',
      () async {
        final (key, count) = specimen;
        final frame = catalog.frame(key, count);
        expect(frame.key, key);
        final scope = '${root.path}/preserve-$key';
        final session =
            PhotoBoothSession.create(
                  accountId: 'parent',
                  childId: 'child',
                  mode: PhotoBoothMode.values.firstWhere(
                    (mode) => mode.count == count,
                  ),
                )
                .withShots(
                  List.generate(
                    count,
                    (i) => LocalPhoto(
                      path: '${root.path}/source-$i.png',
                      width: 640,
                      height: 960,
                      capturedAt: DateTime(2026),
                      frontCamera: true,
                    ),
                  ),
                )
                .withSelection(List.generate(count, (i) => i));
        final editor = PhotoBoothEditorController(session);
        editor.setFrame(frame, catalog);
        editor.addText(
          'Bé yêu',
          frame,
          color: 0xFFFF00FF,
          backgroundColor: 0xFF00FFFF,
        );
        final sticker = catalog.stickers.first;
        editor.addSticker(sticker, frame);
        editor.changeSticker(
          editor.draft.stickers.single.move(
            frame.size,
            sticker.size,
            x: .5,
            y: .75,
          ),
        );
        final fingerprint = editor.draft.fingerprint;
        final images = PhotoBoothImages();
        await images.loadPhotos(session);
        await images.loadAsset(frame.asset!);
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(const Color(0xFF20FF80), BlendMode.src);
        final picture = recorder.endRecording();
        images.assets[sticker.asset] = await picture.toImage(32, 32);
        picture.dispose();
        final memento =
            await PhotoBoothExporter(
              files: PhotoBoothOutputStore(rootPath: '$scope/outputs'),
            ).export(
              session,
              PhotoBoothPainter(
                frame: frame,
                draft: editor.draft,
                catalog: catalog,
                images: images,
              ),
            );
        final files = BackgroundFiles(rootPath: '$scope/backgrounds');
        final service = BackgroundImageService(files: files);
        final input = await files.keepInput(memento);
        final fitted = await service.preparePhotobooth(input);
        final jpegPath = await service.export(
          fitted,
          const Rect.fromLTWH(0, 0, 1, 1),
        );
        final repository = HomeBackgroundRepository(files: files);
        await repository.apply(
          accountId: session.accountId,
          draft: BackgroundDraft(
            childId: session.childId,
            source: BackgroundSource.photobooth,
            croppedPath: jpegPath,
          ),
          isCurrentProfile: () => true,
        );
        final restored = await repository.load(
          accountId: session.accountId,
          childId: session.childId,
        );
        final original = img.decodePng(await File(memento).readAsBytes())!;
        final overlay = img.decodePng(await File(frame.asset!).readAsBytes())!;
        final output = img.decodeJpg(
          await File(restored.finalLocalPath!).readAsBytes(),
        )!;
        final destination = applyBoxFit(
          BoxFit.contain,
          frame.size,
          const Size(1440, 960),
        ).destination;
        final rect = Alignment.center.inscribe(
          destination,
          const Rect.fromLTWH(0, 0, 1440, 960),
        );
        var frameLandmarks = 0;
        var matchingLandmarks = 0;
        for (var y = 2; y < 40; y++) {
          for (var x = 2; x < 30; x++) {
            final sx = (original.width * x / 30).floor();
            final sy = (original.height * y / 40).floor();
            if (overlay.getPixel(sx, sy).a < 250) continue;
            final center = original.getPixel(sx, sy);
            final neighbor = original.getPixel(sx + 2, sy + 2);
            if ((center.r - neighbor.r).abs() +
                    (center.g - neighbor.g).abs() +
                    (center.b - neighbor.b).abs() >
                8) {
              continue;
            }
            final pixel = output.getPixel(
              (rect.left + rect.width * x / 30).floor(),
              (rect.top + rect.height * y / 40).floor(),
            );
            frameLandmarks++;
            if ((pixel.r - center.r).abs() < 25 &&
                (pixel.g - center.g).abs() < 25 &&
                (pixel.b - center.b).abs() < 25) {
              matchingLandmarks++;
            }
          }
        }
        expect(frameLandmarks, greaterThan(12));
        expect(
          matchingLandmarks / frameLandmarks,
          greaterThan(.93),
          reason:
              'The selected frame must survive as part of the finished artwork',
        );
        var textPixels = 0;
        var stickerPixels = 0;
        for (final pixel in output) {
          if (pixel.r > 200 && pixel.b > 200 && pixel.g < 90) textPixels++;
          if (pixel.r < 60 && pixel.g > 210 && pixel.b > 85 && pixel.b < 160) {
            stickerPixels++;
          }
        }
        expect(textPixels, greaterThan(10));
        expect(stickerPixels, greaterThan(10));
        expect(editor.draft.fingerprint, fingerprint);
        expect(editor.draft.frameKey, key);
        expect(await File(memento).exists(), isTrue);
        await files.removePending(input);
        if (fitted != input) await files.removePending(fitted);
        await files.removePending(jpegPath);
        expect(
          await Directory('$scope/backgrounds/pending').list().toList(),
          isEmpty,
        );
        images.dispose();
        editor.dispose();
      },
    );
  }

  for (final layout in [
    'one',
    'two',
    'three',
    'four-grid',
    'four-highlights',
  ]) {
    test(
      '$layout: originals -> memento -> Home collage -> crop -> Apply -> reload',
      () async {
        final scope = '${root.path}/$layout';
        final captures = PhotoBoothFiles(rootPath: '$scope/sessions');
        final outputs = PhotoBoothExporter(
          files: PhotoBoothOutputStore(rootPath: '$scope/exports'),
        );
        var session = PhotoBoothSession.create(
          accountId: 'parent',
          childId: 'child',
          mode: switch (layout) {
            'one' => PhotoBoothMode.one,
            'two' => PhotoBoothMode.two,
            'three' => PhotoBoothMode.three,
            _ => PhotoBoothMode.four,
          },
        );
        final shots = <LocalPhoto>[];
        for (var i = 0; i < session.mode.count; i++) {
          shots.add(
            await captures.save(
              session,
              PhotoBoothCapture(
                path: '${root.path}/source-$i.png',
                frontCamera: true,
              ),
            ),
          );
        }
        session = session
            .withShots(shots)
            .withSelection(List.generate(session.mode.count, (i) => i));
        final editor = PhotoBoothEditorController(session);
        final images = PhotoBoothImages();
        await images.loadPhotos(session);
        PhotoBoothPainter painter() => PhotoBoothPainter(
          frame: editor.resolveFrame(catalog),
          draft: editor.draft,
          catalog: catalog,
          images: images,
        );
        final stripFrame = editor.resolveFrame(catalog);
        final caption = editor.addText(
          'Bé yêu 2026',
          stripFrame,
          color: 0xFFFF00FF,
          backgroundColor: 0xFF00FFFF,
          fontSize: .08,
        )!;
        editor.changeText(caption.move(stripFrame.size, y: .9));
        if (stripFrame.asset != null) await images.loadAsset(stripFrame.asset!);
        final stripFingerprint = editor.draft.fingerprint;
        final memento = await outputs.export(session, painter());
        editor.prepareHome(catalog);
        if (layout == 'four-highlights') {
          editor.setHomeLayout(2);
          editor.chooseHomePhoto(0, 3);
          editor.chooseHomePhoto(1, 2);
        }
        final frame = editor.resolveFrame(catalog);
        expect(
          frame.slots.map((s) => s.photo).toList(),
          layout == 'four-highlights'
              ? [3, 2]
              : List.generate(session.mode.count, (i) => i),
        );
        final collage = await outputs.export(session, painter());
        final files = BackgroundFiles(rootPath: '$scope/backgrounds');
        final processing = BackgroundImageService(files: files);
        final input = await files.keepInput(collage);
        final decoded = await processing.decode(input);
        processing.validateSize(decoded);
        final crop = BackgroundCropState(sourceSize: decoded.naturalSize);
        final cropped = await processing.export(input, crop.normalizedRect);
        final applied = await HomeBackgroundRepository(files: files).apply(
          accountId: session.accountId,
          draft: BackgroundDraft(
            childId: session.childId,
            source: BackgroundSource.photobooth,
            croppedPath: cropped,
          ),
          isCurrentProfile: () => true,
        );
        final restored = await HomeBackgroundRepository(files: files)
            .load(accountId: session.accountId, childId: session.childId);
        expect(restored.toJson(), applied.toJson());
        final jpeg = img.decodeJpg(
          await File(restored.finalLocalPath!).readAsBytes(),
        )!;
        expect((jpeg.width, jpeg.height), (1440, 960));
        var captionPixels = 0;
        var captionBackgroundPixels = 0;
        for (var y = 0; y < jpeg.height; y++) {
          for (var x = 0; x < jpeg.width; x++) {
            final pixel = jpeg.getPixel(x, y);
            if (pixel.r > 180 && pixel.b > 180 && pixel.g < 100) {
              captionPixels++;
            }
            if (pixel.g > 180 && pixel.b > 180 && pixel.r < 100) {
              captionBackgroundPixels++;
            }
          }
        }
        expect(
          captionPixels,
          greaterThan(30),
          reason:
              'Typed text survives PNG export, Home crop and JPEG persistence',
        );
        expect(
          captionBackgroundPixels,
          greaterThan(30),
          reason: 'Text background survives PNG export, crop, JPEG and reload',
        );
        for (final slot in frame.slots) {
          final pixel = jpeg.getPixel(
            slot.rect.center.dx.toInt(),
            slot.rect.center.dy.toInt(),
          );
          final expected = colors[slot.photo];
          expect(pixel.r, closeTo(expected.r * 255, 12));
          expect(pixel.g, closeTo(expected.g * 255, 12));
          expect(pixel.b, closeTo(expected.b * 255, 12));
        }
        await files.removePending(input);
        await files.removePending(cropped);
        await captures.clear(session);
        expect(await File(memento).exists(), isTrue);
        expect(await File(collage).exists(), isTrue);
        expect(await File(restored.finalLocalPath!).exists(), isTrue);
        expect(await File('${root.path}/source-0.png').exists(), isTrue);
        expect(
          await Directory('$scope/backgrounds/pending').list().toList(),
          isEmpty,
        );
        editor.restoreStrip();
        expect(editor.draft.fingerprint, stripFingerprint);
        crop.dispose();
        decoded.dispose();
        images.dispose();
        editor.dispose();
      },
    );
  }
}
