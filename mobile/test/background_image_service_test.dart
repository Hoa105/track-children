import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:track_children/features/home/background/background_draft.dart';
import 'package:track_children/features/home/background/background_crop_state.dart';
import 'package:track_children/features/home/background/background_files.dart';
import 'package:track_children/features/home/background/background_image_service.dart';
import 'package:track_children/features/home/background/crop_background_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late BackgroundImageService service;

  setUp(() async {
    await Directory('build/background_image_tests').create(recursive: true);
    root = await Directory('build/background_image_tests').createTemp('run_');
    service = BackgroundImageService(
      files: BackgroundFiles(rootPath: root.path),
    );
  });

  test(
    'JPEG crop exports exact 1440x960 pixels with preview landmark positions',
    () async {
      final image = img.Image(width: 3000, height: 2000);
      img.fillRect(
        image,
        x1: 0,
        y1: 0,
        x2: 1499,
        y2: 1999,
        color: img.ColorRgb8(240, 20, 20),
      );
      img.fillRect(
        image,
        x1: 1500,
        y1: 0,
        x2: 2999,
        y2: 1999,
        color: img.ColorRgb8(20, 200, 20),
      );
      final path = '${root.path}/source.jpg';
      await File(path).writeAsBytes(img.encodeJpg(image));
      final decoded = await service.decode(path);
      service.validateSize(decoded);
      expect(
        decoded.image.width * decoded.image.height,
        lessThanOrEqualTo(4000000),
      );
      decoded.dispose();
      final result = await service.export(
        path,
        const ui.Rect.fromLTWH(.25, .25, .5, .5),
      );
      final output = img.decodeJpg(await File(result).readAsBytes())!;
      expect((output.width, output.height), (1440, 960));
      final left = output.getPixel(359, 480);
      final right = output.getPixel(1080, 480);
      expect(left.r, greaterThan(220));
      expect(left.g, lessThan(40));
      expect(right.g, greaterThan(180));
      expect(right.r, lessThan(40));
      final previewSource = await service.decode(path);
      const selected = ui.Rect.fromLTWH(.25, .25, .5, .5);
      const workspace = ui.Size(360, 400);
      final geometry = BackgroundCropGeometry(
        viewport: workspace,
        source: previewSource.naturalSize,
        normalizedRect: selected,
      );
      final recorder = ui.PictureRecorder();
      BackgroundCropPainter(
        previewSource.image,
        selected,
        sourceSize: previewSource.naturalSize,
      ).paint(ui.Canvas(recorder), workspace);
      final picture = recorder.endRecording();
      final preview = await picture.toImage(360, 400);
      final pixels = (await preview.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      int redAt(double x, double y) =>
          pixels.getUint8((y.floor() * 360 + x.floor()) * 4);
      int greenAt(double x, double y) =>
          pixels.getUint8((y.floor() * 360 + x.floor()) * 4 + 1);
      expect(
        redAt(geometry.frame.left + geometry.frame.width / 4, 200),
        greaterThan(220),
      );
      expect(
        greenAt(geometry.frame.left + geometry.frame.width * .75, 200),
        greaterThan(180),
      );
      // Image remains visible beyond the frame, underneath the dim mask.
      expect(redAt(5, 200), inInclusiveRange(100, 160));
      preview.dispose();
      picture.dispose();
      previewSource.dispose();

      // A 5x crop exports normally, even below the old detail threshold.
      final crop = BackgroundCropState(sourceSize: const ui.Size(3000, 2000));
      crop.gesture(
        startRect: crop.normalizedRect,
        startZoom: 1,
        startFocal: const ui.Offset(.1, .1),
        focal: const ui.Offset(.1, .1),
        viewport: const ui.Size(1, 1),
        scale: 1000,
      );
      expect(crop.zoom, 5);
      expect(crop.normalizedRect.width * 3000, closeTo(600, 1e-6));
      expect(crop.normalizedRect.height * 2000, closeTo(400, 1e-6));
      final magnifiedPath = await service.export(path, crop.normalizedRect);
      crop.dispose();
      final magnified = img.decodeJpg(await File(magnifiedPath).readAsBytes())!;
      expect((magnified.width, magnified.height), (1440, 960));
      expect(magnified.getPixel(720, 480).r, greaterThan(220));
      expect(await File(path).exists(), isTrue);
    },
  );

  test('transparent PNG is flattened to white, never black', () async {
    final image = img.Image(width: 1440, height: 960, numChannels: 4);
    final path = '${root.path}/alpha.png';
    await File(path).writeAsBytes(img.encodePng(image));
    final result = await service.export(
      path,
      const ui.Rect.fromLTWH(0, 0, 1, 1),
    );
    final pixel = img
        .decodeJpg(await File(result).readAsBytes())!
        .getPixel(720, 480);
    expect(pixel.r, greaterThan(250));
    expect(pixel.g, greaterThan(250));
    expect(pixel.b, greaterThan(250));
    final decoded = await service.decode(path);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..drawColor(const ui.Color(0xfffaf7f0), ui.BlendMode.src);
    BackgroundCropPainter(
      decoded.image,
      const ui.Rect.fromLTWH(0, 0, 1, 1),
    ).paint(canvas, const ui.Size(360, 240));
    final picture = recorder.endRecording();
    final preview = await picture.toImage(360, 240);
    final previewBytes = await preview.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    // Sample inside the fixed frame, away from grid lines and the outer mask.
    final sample = (120 * 360 + 180) * 4;
    expect(previewBytes!.getUint8(sample), 255);
    expect(previewBytes.getUint8(sample + 1), 255);
    expect(previewBytes.getUint8(sample + 2), 255);
    preview.dispose();
    picture.dispose();
    decoded.dispose();
  });

  test('EXIF portrait orientation is applied before crop/preview', () async {
    final image = img.Image(width: 1800, height: 1200);
    img.fillRect(
      image,
      x1: 0,
      y1: 0,
      x2: 899,
      y2: 1199,
      color: img.ColorRgb8(240, 20, 20),
    );
    img.fillRect(
      image,
      x1: 900,
      y1: 0,
      x2: 1799,
      y2: 1199,
      color: img.ColorRgb8(20, 200, 20),
    );
    image.exif.imageIfd.orientation = 6;
    final path = '${root.path}/oriented.jpg';
    await File(path).writeAsBytes(img.encodeJpg(image));
    final decoded = await service.decode(path);
    expect(decoded.image.width, 1200);
    expect(decoded.image.height, 1800);
    expect(decoded.naturalSize, const ui.Size(1200, 1800));
    final pixels = await decoded.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    final offset = (decoded.image.width * 200 + 600) * 4;
    expect(pixels!.getUint8(offset), greaterThan(220));
    decoded.dispose();
    final result = await service.export(
      path,
      const ui.Rect.fromLTWH(0, 5 / 18, 1, 4 / 9),
    );
    final output = img.decodeJpg(await File(result).readAsBytes())!;
    expect((output.width, output.height), (1440, 960));
    expect(output.getPixel(720, 100).r, greaterThan(220));
    expect(output.getPixel(720, 860).g, greaterThan(180));
  });

  test(
    'unreadable, missing and low-resolution images fail with a short message',
    () async {
      final path = '${root.path}/bad.heic';
      await File(path).writeAsString('not an image');
      await expectLater(
        service.decode(path),
        throwsA(isA<BackgroundImageException>()),
      );
      await expectLater(
        service.decode('${root.path}/missing.jpg'),
        throwsA(isA<BackgroundImageException>()),
      );
      final tiny = '${root.path}/tiny.png';
      await File(tiny)
          .writeAsBytes(img.encodePng(img.Image(width: 120, height: 200)));
      final decoded = await service.decode(tiny);
      expect(
        () => service.validateSize(decoded),
        throwsA(isA<BackgroundImageException>()),
      );
      decoded.dispose();
    },
  );
}
