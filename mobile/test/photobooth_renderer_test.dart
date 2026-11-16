import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:track_children/features/photobooth/photobooth_catalog.dart';
import 'package:track_children/features/photobooth/photobooth_edit.dart';
import 'package:track_children/features/photobooth/photobooth_export.dart';
import 'package:track_children/features/photobooth/photobooth_files.dart';
import 'package:track_children/features/photobooth/photobooth_renderer.dart';
import 'package:track_children/features/photobooth/photobooth_text.dart';

import 'photobooth_editor_model_test.dart' show editorSession;

Future<ui.Image> solid(Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(color, BlendMode.src);
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(80, 120);
  } finally {
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PhotoBoothCatalog catalog;
  const colors = [Colors.red, Colors.green, Colors.blue, Colors.yellow];
  setUpAll(() async {
    catalog = await PhotoBoothCatalog.load();
    await (FontLoader('Nunito')
          ..addFont(rootBundle.load('assets/fonts/nunito/Nunito-Variable.ttf')))
        .load();
  });

  for (final theme in [
    'classic',
    'film',
    'birthday',
    'christmas',
    'halloween',
  ]) {
    for (final width in [600, 1200]) {
      test(
        '$theme $width: actual alpha geometry, correctly repeated photos and no bleed',
        () async {
          final frame = catalog.frame('$theme-$width', 4);
          final original = img.decodePng(
            await File(frame.asset!).readAsBytes(),
          )!;
          final images = PhotoBoothImages();
          for (final color in colors) {
            images.photos.add(await solid(color));
          }
          await images.loadAsset(frame.asset!);
          final painter = PhotoBoothPainter(
            frame: frame,
            draft: PhotoBoothEdit(frameKey: frame.key),
            catalog: catalog,
            images: images,
          );
          final output = await painter.render();
          try {
            expect((output.width, output.height), (width, 1800));
            final bytes = (await output.toByteData())!.buffer.asUint8List();
            for (final slot in frame.slots) {
              for (final point in [
                slot.rect.topLeft + const Offset(3, 3),
                slot.rect.center,
                slot.rect.bottomRight - const Offset(3, 3),
              ]) {
                final x = point.dx.toInt(), y = point.dy.toInt();
                expect(original.getPixel(x, y).a, 0);
                final offset = (y * width + x) * 4;
                final color = colors[slot.photo];
                expect(bytes.sublist(offset, offset + 4), [
                  color.r * 255,
                  color.g * 255,
                  color.b * 255,
                  255,
                ]);
              }
            }
            // White foundation keeps transparent sprockets white, never photo pixels.
            for (var y = 0; y < 1800; y += 23) {
              for (var x = 0; x < width; x += 23) {
                final point = Offset(x.toDouble(), y.toDouble());
                if (frame.slots.any((slot) => slot.rect.contains(point))) {
                  continue;
                }
                final pixel = original.getPixel(x, y);
                if (pixel.a == 0 &&
                    x > 2 &&
                    y > 2 &&
                    x + 3 < width &&
                    y + 3 < 1800 &&
                    original.getPixel(x - 2, y).a == 0 &&
                    original.getPixel(x + 2, y).a == 0 &&
                    original.getPixel(x, y - 2).a == 0 &&
                    original.getPixel(x, y + 2).a == 0) {
                  final offset = (y * width + x) * 4;
                  expect(bytes.sublist(offset, offset + 4), [
                    255,
                    255,
                    255,
                    255,
                  ]);
                }
              }
            }
          } finally {
            output.dispose();
            images.dispose();
          }
        },
      );
    }
  }

  test(
    'separate preview layers compose to the same pixels as the export painter',
    () async {
      final images = PhotoBoothImages();
      for (final color in colors) {
        images.photos.add(await solid(color));
      }
      final frame = catalog.frame('film-1200', 4);
      await images.loadAsset(frame.asset!);
      final sticker = catalog.stickers.first;
      images.assets[sticker.asset] = await solid(Colors.purple);
      final draft = PhotoBoothEdit(
        frameKey: frame.key,
        texts: const [
          PhotoBoothText(
            id: 0,
            text: 'Bé yêu\n2026',
            color: 0xFFE96392,
            backgroundColor: 0xFF317EC1,
            rotation: .2,
          ),
        ],
        photos: {1: const PhotoBoothPhotoTransform(x: .4, y: .6, zoom: 2)},
        stickers: [
          PhotoBoothSticker(
            id: 0,
            assetKey: sticker.key,
            x: .7,
            y: .4,
            rotation: .5,
          ),
        ],
      );
      final original = await PhotoBoothPainter(
        frame: frame,
        draft: draft,
        catalog: catalog,
        images: images,
      ).render();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      for (final layer in [
        PhotoBoothPaintLayer.photos,
        PhotoBoothPaintLayer.frame,
        PhotoBoothPaintLayer.stickers,
        PhotoBoothPaintLayer.texts,
      ]) {
        PhotoBoothPainter(
          frame: frame,
          draft: draft,
          catalog: catalog,
          images: images,
          layer: layer,
        ).paint(canvas, frame.size);
      }
      final picture = recorder.endRecording();
      final composed = await picture.toImage(1200, 1800);
      picture.dispose();
      try {
        expect(
          (await composed.toByteData())!.buffer.asUint8List(),
          (await original.toByteData())!.buffer.asUint8List(),
        );
      } finally {
        composed.dispose();
        original.dispose();
        images.dispose();
      }
    },
  );

  test('recently used assets are reused while inactive decoded memory stays bounded', () async {
    final images = PhotoBoothImages();
    final a = catalog.frame('classic-600', 4).asset!;
    final b = catalog.frame('film-1200', 4).asset!;
    final active = catalog.frame('birthday-600', 4).asset!;
    await images.loadAsset(a);
    await images.loadAsset(b);
    final cached = images.assets[b];
    await images.loadAsset(active);
    images.retainAssets({active});
    final inactiveBytes = images.assets.entries
        .where((e) => e.key != active)
        .fold<int>(0, (sum, e) => sum + e.value.width * e.value.height * 4);
    expect(inactiveBytes, lessThanOrEqualTo(images.spareCacheBytes));
    expect(images.assets[active], isNotNull);
    await images.loadAsset(b);
    expect(images.assets[b], same(cached));
    images.dispose();
  });

  test(
    'normalized rotated sticker and preview geometry match full export',
    () async {
      final asset = catalog.stickers.first;
      final images = PhotoBoothImages();
      for (final color in colors) {
        images.photos.add(await solid(color));
      }
      images.assets[asset.asset] = await solid(Colors.purple);
      final frame = PhotoBoothFrame.home(4);
      final draft = PhotoBoothEdit(
        frameKey: frame.key,
        stickers: [
          PhotoBoothSticker(
            id: 1,
            assetKey: asset.key,
            x: .5,
            y: .5,
            width: .25,
            rotation: .5,
          ),
        ],
      );
      final painter = PhotoBoothPainter(
        frame: frame,
        draft: draft,
        catalog: catalog,
        images: images,
      );
      final full = await painter.render();
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), frame.size / 2);
      final picture = recorder.endRecording();
      final preview = await picture.toImage(720, 480);
      picture.dispose();
      try {
        final big = (await full.toByteData())!.buffer.asUint8List();
        final small = (await preview.toByteData())!.buffer.asUint8List();
        for (var y = 30; y < 450; y += 47) {
          for (var x = 30; x < 690; x += 47) {
            final a = (y * 720 + x) * 4, b = (y * 2 * 1440 + x * 2) * 4;
            for (var c = 0; c < 4; c++) {
              expect(small[a + c], closeTo(big[b + c], 4));
            }
          }
        }
      } finally {
        preview.dispose();
        full.dispose();
        images.dispose();
      }
    },
  );

  test(
    'huge sticker is decoded with a bound and export survives session cleanup',
    () async {
      final images = PhotoBoothImages();
      await images.loadAsset(catalog.sticker('animals/penguin').asset);
      final penguin = images.assets.values.single;
      expect(penguin.width, 1024);
      expect(penguin.height, 1024);
      for (final color in colors.take(2)) {
        images.photos.add(await solid(color));
      }
      final root = await Directory('build').createTemp('photobooth_exports_');
      final session = editorSession(count: 2);
      final store = PhotoBoothOutputStore(rootPath: '${root.path}/exports');
      final painter = PhotoBoothPainter(
        frame: PhotoBoothFrame.home(2),
        draft: PhotoBoothEdit(frameKey: 'home-2'),
        catalog: catalog,
        images: images,
      );
      final path = await PhotoBoothExporter(files: store)
          .export(session, painter);
      await PhotoBoothFiles(rootPath: '${root.path}/sessions').clear(session);
      final png = img.decodePng(await File(path).readAsBytes())!;
      expect((png.width, png.height), (1440, 960));
      expect(File(path).existsSync(), isTrue);
      expect(
        (await Directory(
          await store.directory(session),
        ).list().toList()).length,
        1,
      );
      images.dispose();
    },
  );

  for (final collection in const {
    'birthday': 14,
    'christmas': 42,
    'halloween': 20,
    'belonkhon': 6,
  }.entries) {
    test(
      '${collection.key} templates paint the correct originals in every repeated aperture',
      () async {
        final frames = catalog.frames.where(
          (frame) =>
              frame.theme == collection.key &&
              (frame.asset!.contains('/PNG/') || frame.theme == 'belonkhon'),
        );
        expect(frames, hasLength(collection.value));
        for (final frame in frames) {
          final source = img.decodePng(await File(frame.asset!).readAsBytes())!;
          final images = PhotoBoothImages();
          for (final color in colors) {
            images.photos.add(await solid(color));
          }
          await images.loadAsset(frame.asset!);
          final scale = 450 / frame.size.longestSide;
          final width = (frame.size.width * scale).round();
          final height = (frame.size.height * scale).round();
          final recorder = ui.PictureRecorder();
          PhotoBoothPainter(
            frame: frame,
            draft: PhotoBoothEdit(frameKey: frame.key),
            catalog: catalog,
            images: images,
          ).paint(Canvas(recorder), Size(width.toDouble(), height.toDouble()));
          final picture = recorder.endRecording();
          final rendered = await picture.toImage(width, height);
          picture.dispose();
          try {
            final pixels = (await rendered.toByteData())!.buffer.asUint8List();
            for (final slot in frame.slots) {
              Offset? sample;
              for (final fraction in const [
                Offset(.5, .5),
                Offset(.25, .25),
                Offset(.75, .25),
                Offset(.25, .75),
                Offset(.75, .75),
              ]) {
                final x =
                    ((slot.rect.left + fraction.dx * slot.rect.width) *
                            width /
                            frame.size.width)
                        .floor();
                final y =
                    ((slot.rect.top + fraction.dy * slot.rect.height) *
                            height /
                            frame.size.height)
                        .floor();
                final sx = ((x + .5) * frame.size.width / width).floor();
                final sy = ((y + .5) * frame.size.height / height).floor();
                if ([
                  const Offset(0, 0),
                  const Offset(-6, 0),
                  const Offset(6, 0),
                  const Offset(0, -6),
                  const Offset(0, 6),
                ].every(
                  (p) =>
                      source.getPixel(sx + p.dx.toInt(), sy + p.dy.toInt()).a ==
                      0,
                )) {
                  sample = Offset(x.toDouble(), y.toDouble());
                  break;
                }
              }
              expect(
                sample,
                isNotNull,
                reason:
                    '${frame.key} slot ${slot.photo} needs a clear aperture',
              );
              final offset =
                  (sample!.dy.toInt() * width + sample.dx.toInt()) * 4;
              final expected = colors[slot.photo];
              expect(
                pixels[offset],
                closeTo(expected.r * 255, 3),
                reason: frame.key,
              );
              expect(
                pixels[offset + 1],
                closeTo(expected.g * 255, 3),
                reason: frame.key,
              );
              expect(
                pixels[offset + 2],
                closeTo(expected.b * 255, 3),
                reason: frame.key,
              );
              expect(pixels[offset + 3], 255);
            }
          } finally {
            rendered.dispose();
            images.dispose();
          }
        }
      },
    );
  }
}
