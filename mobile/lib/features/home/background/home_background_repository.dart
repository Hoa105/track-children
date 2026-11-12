import 'dart:convert';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'background_config.dart';
import 'background_draft.dart';
import 'background_files.dart';

class HomeBackgroundRepository {
  const HomeBackgroundRepository({this.files = const BackgroundFiles()});
  final BackgroundFiles files;
  static final _commits = <String, Future<void>>{};

  String _key(String accountId, String childId) =>
      'home_background_v1:${Uri.encodeComponent(accountId)}:${Uri.encodeComponent(childId)}';

  Future<BackgroundConfig> load({
    required String accountId,
    required String childId,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(accountId, childId));
    if (raw == null) return BackgroundConfig(childId: childId);
    final config = BackgroundConfig.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    if (config.childId != childId) {
      throw const FormatException('Background belongs to another child');
    }
    final path = config.finalLocalPath;
    if (path == null) {
      return config;
    }
    return BackgroundConfig(
      childId: config.childId,
      source: config.source,
      selectedDefaultKey: config.selectedDefaultKey,
      finalLocalPath: await files.resolveStoredPath(
        path,
        accountId: accountId,
        childId: childId,
      ),
      updatedAt: config.updatedAt,
    );
  }

  Future<void> save({
    required String accountId,
    required BackgroundConfig config,
  }) async {
    if (accountId.isEmpty || config.childId.isEmpty) {
      throw ArgumentError('An account and child are required');
    }
    if (config.source != BackgroundSource.defaultImage &&
        (config.finalLocalPath == null ||
            config.finalLocalPath!.trim().isEmpty)) {
      throw ArgumentError('Custom backgrounds require a final local file');
    }
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(
      _key(accountId, config.childId),
      jsonEncode(config.toJson()),
    )) {
      throw StateError('Không lưu được ảnh nền. Vui lòng thử lại.');
    }
  }

  /// The only production Apply operation: publish a complete image, commit
  /// metadata, then remove the old managed image. Failure retains the old config.
  Future<BackgroundConfig> apply({
    required String accountId,
    required BackgroundDraft draft,
    required bool Function() isCurrentProfile,
  }) async {
    if (accountId.isEmpty || draft.childId.isEmpty) {
      throw ArgumentError('Missing profile');
    }
    final scope = _key(accountId, draft.childId);
    final previous = _commits[scope];
    final done = Completer<void>();
    _commits[scope] = done.future;
    String? published;
    var committed = false;
    var metadataAttempted = false;
    SharedPreferences? preferences;
    Object? oldValue;
    try {
      if (previous != null) await previous;
      if (!isCurrentProfile()) throw const BackgroundFlowCancelled();
      preferences = await SharedPreferences.getInstance();
      oldValue = preferences.get(scope);
      BackgroundConfig? old;
      try {
        old = await load(accountId: accountId, childId: draft.childId);
      } on FormatException {
        /* Explicit Apply may replace corrupt metadata. */
      } on TypeError {
        /* Explicit Apply may replace corrupt metadata. */
      }
      if (draft.source != BackgroundSource.defaultImage) {
        final path = draft.croppedPath;
        if (path == null) throw ArgumentError('A cropped image is required');
        published = await files.publish(path, accountId, draft.childId);
      }
      if (!isCurrentProfile()) throw const BackgroundFlowCancelled();
      final now = DateTime.now().toUtc();
      final stored = BackgroundConfig(
        childId: draft.childId,
        source: draft.source,
        finalLocalPath: published == null
            ? null
            : await files.toStoredPath(published),
        updatedAt: now,
      );
      if (!isCurrentProfile()) throw const BackgroundFlowCancelled();
      metadataAttempted = true;
      await save(accountId: accountId, config: stored);
      if (!isCurrentProfile()) throw const BackgroundFlowCancelled();
      committed = true;
      try {
        await files.removeFinal(old?.finalLocalPath, accountId, draft.childId);
      } catch (_) {
        /* Startup cleanup retries; a committed Apply stays successful. */
      }
      return BackgroundConfig(
        childId: draft.childId,
        source: draft.source,
        finalLocalPath: published,
        updatedAt: now,
      );
    } finally {
      if (!committed && metadataAttempted && preferences != null) {
        // SharedPreferences may update its cache before reporting a disk error.
        // Restore the previous value as well as preserving the previous file.
        try {
          switch (oldValue) {
            case String value:
              await preferences.setString(scope, value);
            case bool value:
              await preferences.setBool(scope, value);
            case int value:
              await preferences.setInt(scope, value);
            case double value:
              await preferences.setDouble(scope, value);
            case List<String> value:
              await preferences.setStringList(scope, value);
            default:
              await preferences.remove(scope);
          }
        } catch (_) {
          /* Keep the old image; retry orphan cleanup at startup. */
        }
      }
      if (!committed && published != null) {
        try {
          await files.removeFinal(published, accountId, draft.childId);
        } catch (_) {
          /* Startup cleanup retries. */
        }
      }
      done.complete();
      if (identical(_commits[scope], done.future)) _commits.remove(scope);
    }
  }

  Future<void> cleanupOrphans({Set<String> keepPending = const {}}) async {
    final preferences = await SharedPreferences.getInstance();
    final referenced = <String>{};
    var valid = true;
    for (final key in preferences.getKeys().where(
      (key) => key.startsWith('home_background_v1:'),
    )) {
      try {
        final config = BackgroundConfig.fromJson(
          jsonDecode(preferences.getString(key)!) as Map<String, dynamic>,
        );
        final path = config.finalLocalPath;
        if (path != null) {
          final owner = key.substring('home_background_v1:'.length).split(':');
          if (owner.length != 2 ||
              Uri.decodeComponent(owner[1]) != config.childId) {
            throw const FormatException('Invalid background owner');
          }
          referenced.add(
            await files.resolveStoredPath(
              path,
              accountId: Uri.decodeComponent(owner[0]),
              childId: config.childId,
            ),
          );
        }
      } catch (_) {
        valid = false;
      }
    }
    await files.cleanup(
      referenced: referenced,
      keepPending: keepPending,
      cleanFinal: valid,
    );
  }
}
