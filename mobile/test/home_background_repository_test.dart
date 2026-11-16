import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/home/background/background_config.dart';
import 'package:track_children/features/home/background/background_files.dart';
import 'package:track_children/features/home/background/background_frame_spec.dart';
import 'package:track_children/features/home/background/home_background_repository.dart';

void main() {
  const files = BackgroundFiles(rootPath: 'build/background_repository_tests');
  const repository = HomeBackgroundRepository(files: files);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('fresh profile uses default without writing preferences', () async {
    final result = await repository.load(accountId: 'parent', childId: 'child');
    expect(result.source, BackgroundSource.defaultImage);
    expect(result.childId, 'child');
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  for (final source in BackgroundSource.values) {
    test('${source.value} metadata survives repository recreation', () async {
      final config = BackgroundConfig(
        childId: 'child',
        source: source,
        selectedDefaultKey: 'neutral',
        finalLocalPath: source == BackgroundSource.defaultImage
            ? null
            : '/local/final.jpg',
        updatedAt: DateTime.utc(2026, 11, 11),
      );
      await repository.save(accountId: 'parent', config: config);
      final restored = await const HomeBackgroundRepository(files: files)
          .load(accountId: 'parent', childId: 'child');
      expect(restored.toJson(), config.toJson());
    });
  }

  test('account and child scopes cannot share a custom background', () async {
    await repository.save(
      accountId: 'parent-a',
      config: const BackgroundConfig(
        childId: 'child-a',
        source: BackgroundSource.photobooth,
        finalLocalPath: '/private/a.jpg',
      ),
    );
    expect(
      (await repository.load(
        accountId: 'parent-a',
        childId: 'child-b',
      )).finalLocalPath,
      isNull,
    );
    expect(
      (await repository.load(
        accountId: 'parent-b',
        childId: 'child-a',
      )).finalLocalPath,
      isNull,
    );
    expect(
      (await repository.load(
        accountId: 'parent-a',
        childId: 'child-a',
      )).finalLocalPath,
      '/private/a.jpg',
    );
  });

  test(
    'invalid writes do not replace a previously confirmed background',
    () async {
      const previous = BackgroundConfig(
        childId: 'child',
        selectedDefaultKey: 'neutral',
      );
      await repository.save(accountId: 'parent', config: previous);
      await expectLater(
        repository.save(
          accountId: 'parent',
          config: const BackgroundConfig(
            childId: 'child',
            source: BackgroundSource.gallery,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        (await repository.load(accountId: 'parent', childId: 'child')).toJson(),
        previous.toJson(),
      );
    },
  );

  test('corrupt metadata and mismatched child are reported without being overwritten', () async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'home_background_v1:parent:child';
    await prefs.setString(key, '{broken');
    await expectLater(
      repository.load(accountId: 'parent', childId: 'child'),
      throwsFormatException,
    );
    expect(prefs.getString(key), '{broken');
    await prefs.setString(
      key,
      jsonEncode(const BackgroundConfig(childId: 'another').toJson()),
    );
    await expectLater(
      repository.load(accountId: 'parent', childId: 'child'),
      throwsFormatException,
    );
  });

  test('export dimensions and preview share one aspect ratio', () {
    expect(
      BackgroundFrameSpec.targetWidthPx / BackgroundFrameSpec.targetHeightPx,
      homeBgAspectRatio,
    );
  });
}
