import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:track_children/features/home/background/default_background_resolver.dart';

void main() {
  const resolver = DefaultBackgroundResolver();
  const expectedFiles = {
    'father': [
      'father-son-drawing-together-home.jpg',
      'father-daughter-with-toys-home.jpg',
    ],
    'mother': [
      'mother-playing-with-lovely-son-bedroom.jpg',
      'mother-daughter-studying-alphabet.jpg',
    ],
    'grandfather': [
      'happy-boy-grandson-playing-game-tablet-with-old-senior-man-grandfather-home.jpg',
      'grandfather-teach-granddaughter-drawing-doing-homework-home.jpg',
    ],
    'grandmother': [
      'grandson-grandmother-with-homework.jpg',
      'granddaughter-grandmother-with-homework.jpg',
    ],
  };
  for (final role in expectedFiles.keys) {
    for (final (index, gender) in ['male', 'female'].indexed) {
      test('$role + $gender selects the supplied role-specific image', () {
        expect(
          resolver.resolve(role: role, childGender: gender)?.fileName,
          expectedFiles[role]![index],
        );
      });
    }
  }

  test('guardian aliases always use the chosen boy-girl image', () {
    for (final role in ['guardian', 'other_guardian']) {
      for (final gender in ['male', 'female', 'other', null]) {
        expect(
          resolver.resolve(role: role, childGender: gender)?.key,
          'neutral',
        );
      }
    }
  });

  test('missing/unknown roles and genders use neutral consistently', () {
    for (final role in [
      'mother',
      'father',
      'grandmother',
      'grandfather',
      'other',
      null,
    ]) {
      expect(resolver.resolve(role: role)?.key, 'neutral');
      expect(
        resolver.resolve(role: role, childGender: 'other')?.key,
        'neutral',
      );
    }
    expect(resolver.resolve(childGender: 'male')?.key, 'neutral');
  });

  test(
    'missing variant falls back to a generic image of the same child gender',
    () {
      const fallback = DefaultBackgroundAsset(
        key: 'boy',
        fileName: 'boy.jpg',
        childGender: 'male',
      );
      final partial = DefaultBackgroundResolver(
        manifest: [defaultBackgroundManifest.last, fallback],
      );
      expect(
        partial.resolve(role: 'grandfather', childGender: 'male'),
        fallback,
      );
      expect(
        partial.resolve(role: 'grandfather', childGender: 'female')?.key,
        'neutral',
      );
    },
  );

  test('last-resort asset and empty manifest are safe', () {
    final partial = DefaultBackgroundResolver(
      manifest: [defaultBackgroundManifest.first],
    );
    expect(partial.resolve()?.key, 'father-boy');
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
