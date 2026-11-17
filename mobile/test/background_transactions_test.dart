import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:track_children/features/home/background/background_config.dart';
import 'package:track_children/features/home/background/background_draft.dart';
import 'package:track_children/features/home/background/background_files.dart';
import 'package:track_children/features/home/background/home_background_repository.dart';

class _FailingRepository extends HomeBackgroundRepository {
  _FailingRepository(BackgroundFiles files) : super(files: files);
  bool fail = false;
  Future<void> Function()? afterSave;
  @override
  Future<void> save({
    required String accountId,
    required BackgroundConfig config,
  }) async {
    await super.save(accountId: accountId, config: config);
    await afterSave?.call();
    if (fail) throw StateError('simulated metadata failure after cache update');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackgroundFiles files;
  late _FailingRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Directory('build/background_transactions').create(recursive: true);
    final root = await Directory('build/background_transactions')
        .createTemp('run_');
    files = BackgroundFiles(rootPath: root.path);
    repository = _FailingRepository(files);
  });

  Future<BackgroundDraft> draft(String child) async {
    final path = await files.stagePath();
    await File(path).writeAsString('fixture final pixels');
    return BackgroundDraft(
      childId: child,
      source: BackgroundSource.gallery,
      croppedPath: path,
    );
  }

  Future<int> publishedCount() async =>
      (await (await files.root())
              .list(recursive: true)
              .where(
                (entry) =>
                    entry is File &&
                    entry.path.contains(
                      '${Platform.pathSeparator}accounts${Platform.pathSeparator}',
                    ),
              )
              .toList())
          .length;

  test('commit uses relative metadata; reload resolves within current app documents', () async {
    final selection = await draft('one');
    final applied = await repository.apply(
      accountId: 'parent',
      draft: selection,
      isCurrentProfile: () => true,
    );
    expect(await File(applied.finalLocalPath!).exists(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString('home_background_v1:parent:one')!) as Map;
    expect(stored['finalLocalPath'], startsWith('@home/accounts/'));
    expect(stored['finalLocalPath'], isNot(contains(files.rootPath!)));
    final reloaded = await HomeBackgroundRepository(files: files)
        .load(accountId: 'parent', childId: 'one');
    expect(reloaded.toJson(), applied.toJson());
    final newRoot = await Directory('build/background_transactions')
        .createTemp('relocated_');
    final relocated = BackgroundFiles(rootPath: newRoot.path);
    final relocatedPath = await relocated.resolveStoredPath(
      stored['finalLocalPath'] as String,
    );
    await File(relocatedPath).parent.create(recursive: true);
    await File(applied.finalLocalPath!).copy(relocatedPath);
    final restored = await HomeBackgroundRepository(files: relocated)
        .load(accountId: 'parent', childId: 'one');
    expect(restored.finalLocalPath, relocatedPath);
    expect(await File(restored.finalLocalPath!).exists(), isTrue);
  });

  test('failed config write restores old metadata and old image, removes new final file', () async {
    final old = await repository.apply(
      accountId: 'parent',
      draft: await draft('one'),
      isCurrentProfile: () => true,
    );
    repository.fail = true;
    await expectLater(
      repository.apply(
        accountId: 'parent',
        draft: await draft('one'),
        isCurrentProfile: () => true,
      ),
      throwsStateError,
    );
    expect(
      (await repository.load(accountId: 'parent', childId: 'one')).toJson(),
      old.toJson(),
    );
    expect(await File(old.finalLocalPath!).exists(), isTrue);
    expect(await publishedCount(), 1);
    repository.fail = false;
    final replacement = await repository.apply(
      accountId: 'parent',
      draft: await draft('one'),
      isCurrentProfile: () => true,
    );
    expect(await File(old.finalLocalPath!).exists(), isFalse);
    expect(await File(replacement.finalLocalPath!).exists(), isTrue);
    expect(await publishedCount(), 1);
  });

  test('profile changes before metadata commit discard the new file and retain old config', () async {
    final old = await repository.apply(
      accountId: 'parent',
      draft: await draft('one'),
      isCurrentProfile: () => true,
    );
    var checks = 0;
    await expectLater(
      repository.apply(
        accountId: 'parent',
        draft: await draft('one'),
        isCurrentProfile: () => ++checks == 1,
      ),
      throwsA(isA<BackgroundFlowCancelled>()),
    );
    expect(
      (await repository.load(accountId: 'parent', childId: 'one')).toJson(),
      old.toJson(),
    );
    expect(await publishedCount(), 1);
  });

  test('reset removes only this child managed file; another account/child is retained', () async {
    final one = await repository.apply(
      accountId: 'parent',
      draft: await draft('one'),
      isCurrentProfile: () => true,
    );
    final two = await repository.apply(
      accountId: 'parent',
      draft: await draft('two'),
      isCurrentProfile: () => true,
    );
    final other = await repository.apply(
      accountId: 'other',
      draft: await draft('one'),
      isCurrentProfile: () => true,
    );
    await repository.apply(
      accountId: 'parent',
      draft: const BackgroundDraft(
        childId: 'one',
        source: BackgroundSource.defaultImage,
      ),
      isCurrentProfile: () => true,
    );
    expect(await File(one.finalLocalPath!).exists(), isFalse);
    expect(await File(two.finalLocalPath!).exists(), isTrue);
    expect(await File(other.finalLocalPath!).exists(), isTrue);
    expect(
      (await repository.load(accountId: 'parent', childId: 'one')).source,
      BackgroundSource.defaultImage,
    );
  });

  test('startup cleans interrupted files but preserves current/recovered files and original sources', () async {
    final source = File(
      '${(await files.root()).parent.path}/unmanaged-source.jpg',
    );
    await source.writeAsString('library source');
    final kept = await repository.apply(
      accountId: 'parent',
      draft: await draft('one'),
      isCurrentProfile: () => true,
    );
    final orphan = await files.publish(
      (await draft('one')).croppedPath!,
      'parent',
      'one',
    );
    final pending = await files.stagePath();
    await File(pending).writeAsString('interrupted');
    final recovery = await files.keepInput(source.path);
    await repository.cleanupOrphans(keepPending: {recovery});
    expect(await File(kept.finalLocalPath!).exists(), isTrue);
    expect(await File(orphan).exists(), isFalse);
    expect(await File(pending).exists(), isFalse);
    expect(await File(recovery).exists(), isTrue);
    await files.removePending(source.path);
    await files.removeFinal(source.path, 'parent', 'one');
    expect(await source.exists(), isTrue);
    await expectLater(
      files.resolveStoredPath('@home/accounts/../../outside.jpg'),
      throwsFormatException,
    );
  });

  test(
    'concurrent applies serialize and keep only the final referenced image',
    () async {
      final one = await draft('one');
      final two = await draft('one');
      final results = await Future.wait([
        repository.apply(
          accountId: 'parent',
          draft: one,
          isCurrentProfile: () => true,
        ),
        repository.apply(
          accountId: 'parent',
          draft: two,
          isCurrentProfile: () => true,
        ),
      ]);
      expect(
        (await repository.load(
          accountId: 'parent',
          childId: 'one',
        )).finalLocalPath,
        results.last.finalLocalPath,
      );
      expect(await publishedCount(), 1);
    },
  );
  for (final source in [
    BackgroundSource.gallery,
    BackgroundSource.defaultImage,
  ]) {
    test(
      'profile changes while writing ${source.value} metadata roll back before deleting the old file',
      () async {
        final old = await repository.apply(
          accountId: 'parent',
          draft: await draft('one'),
          isCurrentProfile: () => true,
        );
        var current = true;
        repository.afterSave = () async {
          current = false;
        };
        final selection = source == BackgroundSource.defaultImage
            ? const BackgroundDraft(
                childId: 'one',
                source: BackgroundSource.defaultImage,
              )
            : await draft('one');
        await expectLater(
          repository.apply(
            accountId: 'parent',
            draft: selection,
            isCurrentProfile: () => current,
          ),
          throwsA(isA<BackgroundFlowCancelled>()),
        );
        final restored = await repository.load(
          accountId: 'parent',
          childId: 'one',
        );
        expect(restored.toJson(), old.toJson());
        expect(await File(old.finalLocalPath!).exists(), isTrue);
        expect(await publishedCount(), 1);
      },
    );
  }

  test('managed paths cannot load another profile and corrupt ownership cannot trigger cleanup', () async {
    final one = await repository.apply(
      accountId: 'parent',
      draft: await draft('one'),
      isCurrentProfile: () => true,
    );
    final other = await repository.apply(
      accountId: 'other',
      draft: await draft('two'),
      isCurrentProfile: () => true,
    );
    final prefs = await SharedPreferences.getInstance();
    final foreign = await files.toStoredPath(other.finalLocalPath!);
    await prefs.setString(
      'home_background_v1:parent:one',
      jsonEncode(
        BackgroundConfig(
          childId: 'one',
          source: BackgroundSource.gallery,
          finalLocalPath: foreign,
        ).toJson(),
      ),
    );
    await expectLater(
      repository.load(accountId: 'parent', childId: 'one'),
      throwsFormatException,
    );
    await expectLater(
      files.resolveStoredPath(
        other.finalLocalPath!,
        accountId: 'parent',
        childId: 'one',
      ),
      throwsFormatException,
    );
    await repository.cleanupOrphans();
    expect(await File(one.finalLocalPath!).exists(), isTrue);
    expect(await File(other.finalLocalPath!).exists(), isTrue);
    await repository.apply(
      accountId: 'parent',
      draft: const BackgroundDraft(
        childId: 'one',
        source: BackgroundSource.defaultImage,
      ),
      isCurrentProfile: () => true,
    );
    expect(await File(other.finalLocalPath!).exists(), isTrue);
  });
}
