import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/home/background/default_background_resolver.dart';

void main() {
  const resolver = DefaultBackgroundResolver();
  const expectedFiles = {
    'father': 'father-with-baby.jpg',
    'mother': 'mother-with-baby.jpg',
    'grandfather': 'grandfather-with-baby.jpg',
    'grandmother': 'grandma-with-baby.jpg',
  };
  for (final entry in expectedFiles.entries) {
    test('${entry.key} selects its caregiver image', () {
      expect(resolver.resolve(role: entry.key)?.fileName, entry.value);
    });
  }

  test('guardian aliases use the supplied neutral image', () {
    for (final role in ['guardian', 'other_guardian']) {
      expect(
        resolver.resolve(role: role)?.fileName,
        'boy-girl-are-playing.jpg',
      );
    }
  });

  test('missing or unknown role uses neutral', () {
    for (final role in [null, '', 'other', 'unknown']) {
      expect(resolver.resolve(role: role)?.key, 'neutral');
    }
  });

  test('missing role-specific asset falls back to neutral', () {
    final partial = DefaultBackgroundResolver(
      manifest: [defaultBackgroundManifest.last],
    );
    expect(partial.resolve(role: 'grandfather')?.key, 'neutral');
  });

  test('last-resort asset and empty manifest are safe', () {
    final partial = DefaultBackgroundResolver(
      manifest: [defaultBackgroundManifest.first],
    );
    expect(partial.resolve()?.key, 'father');
    expect(const DefaultBackgroundResolver(manifest: []).resolve(), isNull);
  });

  test('manifest covers exactly the real JPEG assets, with unique keys', () {
    final actual = Directory('assets/images/scenery/backgrounds/default')
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .toSet();
    expect(
      defaultBackgroundManifest.map((asset) => asset.fileName).toSet(),
      actual,
    );
    expect(
      defaultBackgroundManifest.map((asset) => asset.key).toSet().length,
      actual.length,
    );
    for (final asset in defaultBackgroundManifest) {
      expect(File(asset.assetPath).readAsBytesSync().take(3), [
        0xff,
        0xd8,
        0xff,
      ]);
    }
  });
}
