import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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

  for (final layout in ['two', 'four-grid', 'four-highlights']) {
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
          mode: layout == 'two' ? PhotoBoothMode.two : PhotoBoothMode.four,
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
