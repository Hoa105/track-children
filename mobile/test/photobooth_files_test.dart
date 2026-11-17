import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:track_children/features/photobooth/photobooth_files.dart';
import 'package:track_children/features/photobooth/photobooth_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PhotoBoothFiles files;
  late String source;

  PhotoBoothSession session(String child) => PhotoBoothSession.create(
    accountId: 'account-one',
    childId: child,
    mode: PhotoBoothMode.two,
  );

  setUp(() async {
    await Directory('build/photobooth_file_tests').create(recursive: true);
    root = await Directory('build/photobooth_file_tests').createTemp('run_');
    files = PhotoBoothFiles(rootPath: p.join(root.path, 'owned'));
    source = p.join(root.path, 'camera.jpg');
    final image = img.Image(width: 1600, height: 1200);
    img.fillRect(
      image,
      x1: 0,
      y1: 0,
      x2: 799,
      y2: 1199,
      color: img.ColorRgb8(240, 20, 20),
    );
    img.fillRect(
      image,
      x1: 800,
      y1: 0,
      x2: 1599,
      y2: 1199,
      color: img.ColorRgb8(20, 200, 20),
    );
    image.exif.imageIfd.orientation = 6;
    await File(source).writeAsBytes(img.encodeJpg(image));
  });

  test(
    'captured JPEG is oriented once, owned, and readable after cache removal',
    () async {
      final active = session('child-a');
      final shot = await files.save(
        active,
        PhotoBoothCapture(path: source, frontCamera: true),
      );
      expect((shot.width, shot.height), (1200, 1600));
      expect(
        p.isWithin(await files.directory(active), p.absolute(shot.path)),
        isTrue,
      );
      final result = img.decodeJpg(await File(shot.path).readAsBytes())!;
      expect((result.width, result.height), (1200, 1600));
      expect(result.getPixel(600, 100).r, greaterThan(220));
      expect(result.getPixel(600, 1500).g, greaterThan(180));
      expect(result.exif.imageIfd.orientation, isNot(6));
      await File(source).delete();
      expect(await File(shot.path).exists(), isTrue);
      expect(
        await Directory(await files.directory(active))
            .list()
            .where((f) => f.path.endsWith('.part'))
            .isEmpty,
        isTrue,
      );
      await files.clear(active);
    },
  );

  test(
    'cleanup cannot remove another child or the original camera source',
    () async {
      final a = session('child-a');
      final b = session('child-b');
      final shotA = await files.save(
        a,
        PhotoBoothCapture(path: source, frontCamera: false),
      );
      final shotB = await files.save(
        b,
        PhotoBoothCapture(path: source, frontCamera: false),
      );
      await files.remove(a, shotB);
      expect(await File(shotB.path).exists(), isTrue);
      await files.clear(a);
      expect(await File(shotA.path).exists(), isFalse);
      expect(await File(shotB.path).exists(), isTrue);
      expect(await File(source).exists(), isTrue);
      await files.clear(b);
    },
  );

  test(
    'editor manifest preserves mode and order without moving originals',
    () async {
      final active = session('child-a');
      final one = await files.save(
        active,
        PhotoBoothCapture(path: source, frontCamera: false),
      );
      final two = await files.save(
        active,
        PhotoBoothCapture(path: source, frontCamera: true),
      );
      await expectLater(
        files.handoff(active.withShots([one])),
        throwsA(isA<PhotoBoothException>()),
      );
      await expectLater(
        files.handoff(active.withShots([one, two])),
        throwsA(isA<PhotoBoothException>()),
      );
      await files.handoff(active.withShots([one, two]).withSelection([1, 0]));
      final manifest = File(
        p.join(await files.directory(active), 'session.json'),
      );
      final json =
          jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
      expect(json['mode'], 'two');
      expect(json['version'], 2);
      expect(json['durationSeconds'], 30);
      expect(json['selectedIndices'], [1, 0]);
      expect((json['shots'] as List).map((s) => s['path']), [
        one.path,
        two.path,
      ]);
      expect(await File(one.path).exists(), isTrue);
      expect(await File(two.path).exists(), isTrue);
      await files.clear(active);
    },
  );

  test('invalid session ID cannot escape the managed folder', () async {
    final bad = PhotoBoothSession(
      sessionId: '../outside',
      accountId: 'account-one',
      childId: 'child',
      mode: PhotoBoothMode.two,
      createdAt: DateTime.now(),
    );
    await expectLater(
      files.directory(bad),
      throwsA(isA<PhotoBoothException>()),
    );
    expect(await File(source).exists(), isTrue);
  });
}
